import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/comment_report.dart';
import '../../domain/exceptions/comments_exceptions.dart';
import '../../domain/repositories/comments_repository_interface.dart';
import '../models/comment_model.dart';
import '../models/comment_report_model.dart';

/// CommentsRemoteDataSource
///
/// Handles all Supabase API calls for the comments feature.
/// Implements CRUD operations, real-time subscriptions, and error mapping.
///
/// Constitutional Principle 5 (SPEC_FIRST): Data layer provides concrete
/// implementation of repository interface using Supabase PostgreSQL backend.
///
/// All methods throw CommentException subclasses on errors (see exception mapping).
class CommentsRemoteDataSource {
  final SupabaseClient _supabase;

  CommentsRemoteDataSource(this._supabase);

  // ==========================================================================
  // 1. QUERY OPERATIONS
  // ==========================================================================

  /// Fetch paginated top-level comments for an event
  ///
  /// Implements cursor-based pagination with configurable sort order.
  /// Returns comments with joined profile data for display.
  Future<PaginatedComments> getCommentsForEvent({
    required String eventId,
    CommentSortOrder sortOrder = CommentSortOrder.recent,
    int limit = 20,
    DateTime? cursorCreatedAt,
  }) async {
    try {
      // Validate limit (max 50 per API spec)
      final validLimit = limit.clamp(1, 50);

      // Build query with profile JOIN
      var query = _supabase
          .from('comments')
          .select('''
            *,
            profiles!user_id (
              full_name,
              avatar_url,
              class,
              role
            )
          ''')
          .eq('event_id', eventId)
          .is_('parent_comment_id', null) // Top-level only
          .is_('deleted_at', null) // Not deleted
          .is_('hidden_at', null); // Not hidden

      // Apply sort order
      if (sortOrder == CommentSortOrder.popular) {
        query = query.order('like_count', ascending: false);
      }
      query = query.order('created_at', ascending: false);

      // Apply cursor pagination (fetch comments older than cursor)
      if (cursorCreatedAt != null) {
        query = query.lt('created_at', cursorCreatedAt.toIso8601String());
      }

      // Apply limit + 1 to detect if more pages exist
      query = query.limit(validLimit + 1);

      final response = await query;

      // Parse response
      final List<dynamic> data = response as List;
      final hasMore = data.length > validLimit;
      final commentsData = hasMore ? data.take(validLimit).toList() : data;

      final comments = commentsData
          .map((json) => _parseCommentWithProfile(json))
          .toList();

      // Determine next cursor (created_at of last comment)
      final nextCursor = comments.isNotEmpty ? comments.last.createdAt : null;

      return PaginatedComments(
        comments: comments,
        hasMore: hasMore,
        nextCursor: nextCursor,
      );
    } on PostgrestException catch (e, stackTrace) {
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to fetch comments: $e', stackTrace);
    }
  }

  /// Fetch all replies for a specific comment
  ///
  /// Returns replies sorted by created_at ASC (oldest first).
  Future<List<CommentModel>> getRepliesForComment({
    required String commentId,
  }) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('''
            *,
            profiles!user_id (
              full_name,
              avatar_url,
              class,
              role
            )
          ''')
          .eq('parent_comment_id', commentId)
          .is_('deleted_at', null)
          .is_('hidden_at', null)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List;
      return data.map((json) => _parseCommentWithProfile(json)).toList();
    } on PostgrestException catch (e, stackTrace) {
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to fetch replies: $e', stackTrace);
    }
  }

  /// Fetch a single comment by ID
  ///
  /// Used for real-time updates or fetching specific comment details.
  Future<CommentModel> getCommentById({
    required String commentId,
  }) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('''
            *,
            profiles!user_id (
              full_name,
              avatar_url,
              class,
              role
            )
          ''')
          .eq('id', commentId)
          .is_('deleted_at', null)
          .is_('hidden_at', null)
          .single();

      return _parseCommentWithProfile(response);
    } on PostgrestException catch (e, stackTrace) {
      if (e.code == 'PGRST116') {
        throw NotFoundException(
          'Comment not found or deleted',
          'comment',
          commentId,
          stackTrace,
        );
      }
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to fetch comment: $e', stackTrace);
    }
  }

  /// Fetch all comments posted by a specific user
  ///
  /// Used for profile view with pagination support.
  Future<List<CommentModel>> getUserComments({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from('comments')
          .select('''
            *,
            profiles!user_id (
              full_name,
              avatar_url,
              class,
              role
            )
          ''')
          .eq('user_id', userId)
          .is_('deleted_at', null)
          .is_('hidden_at', null)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> data = response as List;
      return data.map((json) => _parseCommentWithProfile(json)).toList();
    } on PostgrestException catch (e, stackTrace) {
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to fetch user comments: $e', stackTrace);
    }
  }

  // ==========================================================================
  // 2. MUTATION OPERATIONS
  // ==========================================================================

  /// Post a new top-level comment on an event
  ///
  /// Triggers: profanity filter, spam rate limit, counter updates.
  Future<CommentModel> postComment({
    required String eventId,
    required String text,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const UnauthorizedException('User not authenticated');
      }

      final response = await _supabase
          .from('comments')
          .insert({
            'event_id': eventId,
            'user_id': currentUserId,
            'parent_comment_id': null,
            'text': text.trim(),
          })
          .select('''
            *,
            profiles!user_id (
              full_name,
              avatar_url,
              class,
              role
            )
          ''')
          .single();

      return _parseCommentWithProfile(response);
    } on PostgrestException catch (e, stackTrace) {
      // Map specific error codes to domain exceptions
      if (e.code == '23514') {
        // CHECK constraint violation (profanity filter)
        throw ValidationException(
          'Comment contains inappropriate language',
          'text',
          text,
          stackTrace,
        );
      } else if (e.code == 'P0001' &&
          e.message.contains('Rate limit exceeded')) {
        throw RateLimitException(
          'Too many comments. Please wait before posting again.',
          const Duration(minutes: 5),
          stackTrace,
        );
      } else if (e.code == '23503') {
        // Foreign key violation (event not found)
        throw NotFoundException(
          'Event not found or has been deleted',
          'event',
          eventId,
          stackTrace,
        );
      }
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to post comment: $e', stackTrace);
    }
  }

  /// Reply to an existing comment
  ///
  /// System enforces 1-level max threading server-side.
  Future<CommentModel> replyToComment({
    required String commentId,
    required String text,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const UnauthorizedException('User not authenticated');
      }

      final response = await _supabase
          .from('comments')
          .insert({
            'parent_comment_id': commentId,
            'user_id': currentUserId,
            'text': text.trim(),
            // event_id populated by trigger or must be fetched
          })
          .select('''
            *,
            profiles!user_id (
              full_name,
              avatar_url,
              class,
              role
            )
          ''')
          .single();

      return _parseCommentWithProfile(response);
    } on PostgrestException catch (e, stackTrace) {
      if (e.code == '23514') {
        throw ValidationException(
          'Reply contains inappropriate language',
          'text',
          text,
          stackTrace,
        );
      } else if (e.code == 'P0001' &&
          e.message.contains('Rate limit exceeded')) {
        throw RateLimitException(
          'Too many comments. Please wait before replying again.',
          const Duration(minutes: 5),
          stackTrace,
        );
      } else if (e.code == '23503') {
        throw NotFoundException(
          'Parent comment not found or deleted',
          'comment',
          commentId,
          stackTrace,
        );
      }
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to post reply: $e', stackTrace);
    }
  }

  /// Edit own comment within 5-minute window
  ///
  /// Server-side RLS policy enforces ownership and time window.
  Future<CommentModel> editComment({
    required String commentId,
    required String newText,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const UnauthorizedException('User not authenticated');
      }

      final response = await _supabase
          .from('comments')
          .update({
            'text': newText.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', commentId)
          .eq('user_id', currentUserId) // Ownership check
          .gte(
            'created_at',
            DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
          ) // 5-min window
          .select('''
            *,
            profiles!user_id (
              full_name,
              avatar_url,
              class,
              role
            )
          ''')
          .single();

      return _parseCommentWithProfile(response);
    } on PostgrestException catch (e, stackTrace) {
      if (e.code == '23514') {
        throw ValidationException(
          'Edited comment contains inappropriate language',
          'text',
          newText,
          stackTrace,
        );
      } else if (e.code == 'PGRST116') {
        // No rows updated (not owned, edit window expired, or doesn't exist)
        throw ForbiddenException(
          'Cannot edit this comment. It may not be yours or the 5-minute edit window has expired.',
          null,
          stackTrace,
        );
      }
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to edit comment: $e', stackTrace);
    }
  }

  /// Soft-delete own comment
  ///
  /// Text replaced with "[Commento eliminato]", deleted_at timestamp set.
  Future<void> deleteComment({
    required String commentId,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const UnauthorizedException('User not authenticated');
      }

      await _supabase
          .from('comments')
          .update({
            'text': '[Commento eliminato]',
            'deleted_at': DateTime.now().toIso8601String(),
            'deleted_by_user_id': currentUserId,
          })
          .eq('id', commentId)
          .eq('user_id', currentUserId) // Ownership check
          .is_('deleted_at', null); // Not already deleted
    } on PostgrestException catch (e, stackTrace) {
      if (e.code == 'PGRST116') {
        throw ForbiddenException(
          'Cannot delete this comment. It may not be yours or has already been deleted.',
          null,
          stackTrace,
        );
      }
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to delete comment: $e', stackTrace);
    }
  }

  // ==========================================================================
  // 3. LIKE OPERATIONS
  // ==========================================================================

  /// Like a comment (idempotent - duplicate likes ignored)
  ///
  /// Triggers: rate limit check (100/hour), counter update.
  Future<void> likeComment({
    required String commentId,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const UnauthorizedException('User not authenticated');
      }

      await _supabase
          .from('comment_likes')
          .insert({
            'comment_id': commentId,
            'user_id': currentUserId,
          })
          .select()
          .single();
    } on PostgrestException catch (e, stackTrace) {
      if (e.code == '23505') {
        // Duplicate like (idempotent - ignore)
        return;
      } else if (e.code == 'P0001' &&
          e.message.contains('Rate limit exceeded')) {
        throw RateLimitException(
          'You have reached the like limit. Please try again in a few minutes.',
          const Duration(hours: 1),
          stackTrace,
        );
      } else if (e.code == '23503') {
        throw NotFoundException(
          'Comment not found or deleted',
          'comment',
          commentId,
          stackTrace,
        );
      }
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to like comment: $e', stackTrace);
    }
  }

  /// Unlike a comment (idempotent - unliking already-unliked is no-op)
  ///
  /// Triggers: counter update (decrement like_count).
  Future<void> unlikeComment({
    required String commentId,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const UnauthorizedException('User not authenticated');
      }

      await _supabase
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', currentUserId);
    } on PostgrestException catch (e, stackTrace) {
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to unlike comment: $e', stackTrace);
    }
  }

  // ==========================================================================
  // 4. REPORT OPERATIONS
  // ==========================================================================

  /// Report a comment for moderation
  ///
  /// Triggers: counter update, auto-hide at 3+ reports.
  Future<CommentReportModel> reportComment({
    required String commentId,
    required CommentReportReason reason,
    String? details,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const UnauthorizedException('User not authenticated');
      }

      final response = await _supabase
          .from('comment_reports')
          .insert({
            'comment_id': commentId,
            'reporter_user_id': currentUserId,
            'reason': reason.value,
            'details': details?.trim(),
          })
          .select()
          .single();

      return CommentReportModel.fromJson(response);
    } on PostgrestException catch (e, stackTrace) {
      if (e.code == '23505') {
        // Unique constraint violation (user already reported)
        throw ConflictException(
          'You have already reported this comment',
          'duplicate_report',
          stackTrace,
        );
      } else if (e.code == '23503') {
        throw NotFoundException(
          'Comment not found or deleted',
          'comment',
          commentId,
          stackTrace,
        );
      }
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to report comment: $e', stackTrace);
    }
  }

  // ==========================================================================
  // 5. MODERATION OPERATIONS (Moderator-Only)
  // ==========================================================================

  /// Hard-hide a comment (moderator action)
  ///
  /// Sets hidden_at, hidden_reason='moderator_removed', moderator_id.
  Future<void> moderatorRemoveComment({
    required String commentId,
    String? reason,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const UnauthorizedException('User not authenticated');
      }

      await _supabase
          .from('comments')
          .update({
            'hidden_at': DateTime.now().toIso8601String(),
            'hidden_reason': reason ?? 'moderator_removed',
            'moderator_id': currentUserId,
          })
          .eq('id', commentId);
    } on PostgrestException catch (e, stackTrace) {
      if (e.code == '42501') {
        // Insufficient privilege (RLS policy - not a moderator)
        throw ForbiddenException(
          'You do not have permission to remove comments',
          'moderator',
          stackTrace,
        );
      } else if (e.code == 'PGRST116') {
        throw NotFoundException(
          'Comment not found',
          'comment',
          commentId,
          stackTrace,
        );
      }
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to remove comment: $e', stackTrace);
    }
  }

  /// Restore a hidden comment (moderator reviewed and approved)
  ///
  /// Sets hidden_at=NULL, hidden_reason=NULL.
  Future<void> moderatorRestoreComment({
    required String commentId,
  }) async {
    try {
      await _supabase
          .from('comments')
          .update({
            'hidden_at': null,
            'hidden_reason': null,
          })
          .eq('id', commentId)
          .not('hidden_at', 'is', null); // Ensure it was hidden
    } on PostgrestException catch (e, stackTrace) {
      if (e.code == '42501') {
        throw ForbiddenException(
          'You do not have permission to restore comments',
          'moderator',
          stackTrace,
        );
      } else if (e.code == 'PGRST116') {
        throw NotFoundException(
          'Comment not found or not hidden',
          'comment',
          commentId,
          stackTrace,
        );
      }
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to restore comment: $e', stackTrace);
    }
  }

  // ==========================================================================
  // 6. REAL-TIME OPERATIONS
  // ==========================================================================

  /// Subscribe to real-time comment updates for an event
  ///
  /// Returns stream that emits updated comment list on INSERT/UPDATE/DELETE.
  Stream<List<CommentModel>> subscribeToComments({
    required String eventId,
  }) {
    try {
      return _supabase
          .from('comments')
          .stream(primaryKey: ['id'])
          .eq('event_id', eventId)
          .eq('parent_comment_id', null) // Top-level only
          .order('created_at')
          .map((List<Map<String, dynamic>> data) {
            return data
                .map((json) => _parseCommentWithProfile(json))
                .toList();
          });
    } catch (e, stackTrace) {
      throw NetworkException(
        'Failed to subscribe to comments: $e',
        stackTrace,
      );
    }
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  /// Parse comment JSON with nested profile data
  ///
  /// Handles both nested object format and flat field format for author data.
  CommentModel _parseCommentWithProfile(Map<String, dynamic> json) {
    // Extract profile data (may be nested or flat)
    final profileData = json['profiles'];
    if (profileData != null && profileData is Map) {
      // Nested format from JOIN
      json['author_name'] = profileData['full_name'];
      json['author_avatar_url'] = profileData['avatar_url'];
      json['author_class'] = profileData['class'];
      json['author_role'] = profileData['role'];
    }

    return CommentModel.fromJson(json);
  }

  /// Map Supabase PostgrestException to domain CommentException
  ///
  /// Centralizes error handling logic per contracts/comments_exceptions.md.
  CommentException _mapSupabaseError(
    PostgrestException error,
    StackTrace stackTrace,
  ) {
    return fromSupabaseError(error.code ?? '', error.message, stackTrace);
  }
}
