import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/comment.dart';
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
  /// Returns comments with profile data fetched separately (no FK required).
  ///
  /// ACTUAL DB SCHEMA: id, event_id, author_id, content, created_at
  Future<PaginatedComments> getCommentsForEvent({
    required String eventId,
    CommentSortOrder sortOrder = CommentSortOrder.recent,
    int limit = 20,
    DateTime? cursorCreatedAt,
  }) async {
    try {
      // Validate limit (max 50 per API spec)
      final validLimit = limit.clamp(1, 50);

      // Build query - DB uses author_id not user_id, content not text
      // Filter for top-level comments only (parent_comment_id IS NULL)
      dynamic query;
      if (cursorCreatedAt != null) {
        query = _supabase
            .from('comments')
            .select('*')
            .eq('event_id', eventId)
            .isFilter('parent_comment_id', null)  // Top-level only
            .lt('created_at', cursorCreatedAt.toIso8601String())
            .order('created_at', ascending: false)
            .limit(validLimit + 1);
      } else {
        query = _supabase
            .from('comments')
            .select('*')
            .eq('event_id', eventId)
            .isFilter('parent_comment_id', null)  // Top-level only
            .order('created_at', ascending: false)
            .limit(validLimit + 1);
      }

      final response = await query;

      // Parse response
      final List<dynamic> data = response as List;
      final hasMore = data.length > validLimit;
      final commentsData = hasMore ? data.take(validLimit).toList() : data;

      // Fetch profiles for all comment authors (DB uses author_id)
      final userIds = commentsData
          .map((json) => json['author_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> profilesMap = {};
      if (userIds.isNotEmpty) {
        final profilesResponse = await _supabase
            .from('profiles')
            .select('user_id, full_name, avatar_url, class')
            .inFilter('user_id', userIds);

        for (final profile in profilesResponse as List) {
          profilesMap[profile['user_id'] as String] = profile;
        }
      }

      // Fetch likes by current user for these comments
      final currentUserId = _supabase.auth.currentUser?.id;
      Set<String> likedCommentIds = {};
      if (currentUserId != null && commentsData.isNotEmpty) {
        final commentIds = commentsData
            .map((json) => json['id'] as String)
            .toList();
        final likesResponse = await _supabase
            .from('comment_likes')
            .select('comment_id')
            .eq('user_id', currentUserId)
            .inFilter('comment_id', commentIds);
        likedCommentIds = (likesResponse as List)
            .map((like) => like['comment_id'] as String)
            .toSet();
      }

      // Parse comments with profile data and like status
      final commentModels = commentsData.map((json) {
        final authorId = json['author_id'] as String?;
        final commentId = json['id'] as String;
        final profile = authorId != null ? profilesMap[authorId] : null;
        // Normalize DB schema to model schema
        final normalizedJson = _normalizeCommentJson(json);
        // Add like status for current user
        normalizedJson['is_liked_by_current_user'] = likedCommentIds.contains(commentId);
        return _parseCommentWithProfileData(normalizedJson, profile);
      }).toList();

      // Convert models to domain entities
      var comments = commentModels.map((m) => m.toEntity()).toList();

      // Fetch replies for comments that have replyCount > 0
      final commentsWithReplies = await _fetchRepliesForComments(comments, profilesMap);
      comments = commentsWithReplies;

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
      // Fetch replies without profile JOIN
      final response = await _supabase
          .from('comments')
          .select('*')
          .eq('parent_comment_id', commentId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List;

      // Fetch profiles for all reply authors (DB uses author_id, not user_id)
      final authorIds = data
          .map((json) => json['author_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      Map<String, Map<String, dynamic>> profilesMap = {};
      if (authorIds.isNotEmpty) {
        final profilesResponse = await _supabase
            .from('profiles')
            .select('user_id, full_name, avatar_url, class')
            .inFilter('user_id', authorIds);

        for (final profile in profilesResponse as List) {
          profilesMap[profile['user_id'] as String] = profile;
        }
      }

      // Fetch likes by current user for these replies
      final currentUserId = _supabase.auth.currentUser?.id;
      Set<String> likedCommentIds = {};
      if (currentUserId != null && data.isNotEmpty) {
        final replyIds = data
            .map((json) => json['id'] as String)
            .toList();
        final likesResponse = await _supabase
            .from('comment_likes')
            .select('comment_id')
            .eq('user_id', currentUserId)
            .inFilter('comment_id', replyIds);
        likedCommentIds = (likesResponse as List)
            .map((like) => like['comment_id'] as String)
            .toSet();
      }

      return data.map((json) {
        final authorId = json['author_id'] as String?;
        final replyId = json['id'] as String;
        final profile = authorId != null ? profilesMap[authorId] : null;
        // Normalize DB schema (author_id -> user_id, content -> text)
        final normalizedJson = _normalizeCommentJson(json);
        // Add like status for current user
        normalizedJson['is_liked_by_current_user'] = likedCommentIds.contains(replyId);
        return _parseCommentWithProfileData(normalizedJson, profile);
      }).toList();
    } on PostgrestException catch (e, stackTrace) {
      throw _mapSupabaseError(e, stackTrace);
    } catch (e, stackTrace) {
      throw NetworkException('Failed to fetch replies: $e', stackTrace);
    }
  }

  /// Fetch a single comment by ID
  ///
  /// Used for real-time updates or fetching specific comment details.
  /// ACTUAL DB SCHEMA: id, event_id, author_id, content, created_at
  Future<CommentModel> getCommentById({
    required String commentId,
  }) async {
    try {
      // Fetch comment without profile JOIN
      // Note: DB doesn't have deleted_at column
      final response = await _supabase
          .from('comments')
          .select('*')
          .eq('id', commentId)
          .single();

      // Fetch profile for author (DB uses author_id)
      final authorId = response['author_id'] as String?;
      Map<String, dynamic>? profileData;
      if (authorId != null) {
        final profileResponse = await _supabase
            .from('profiles')
            .select('user_id, full_name, avatar_url, class')
            .eq('user_id', authorId)
            .maybeSingle();
        profileData = profileResponse;
      }

      // Check if current user has liked this comment
      final currentUserId = _supabase.auth.currentUser?.id;
      bool isLikedByCurrentUser = false;
      if (currentUserId != null) {
        final likeResponse = await _supabase
            .from('comment_likes')
            .select('comment_id')
            .eq('user_id', currentUserId)
            .eq('comment_id', commentId)
            .maybeSingle();
        isLikedByCurrentUser = likeResponse != null;
      }

      final normalizedJson = _normalizeCommentJson(response);
      normalizedJson['is_liked_by_current_user'] = isLikedByCurrentUser;
      return _parseCommentWithProfileData(normalizedJson, profileData);
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
      // Fetch comments without profile JOIN
      final response = await _supabase
          .from('comments')
          .select('*')
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final List<dynamic> data = response as List;

      // Fetch profile for the user
      Map<String, dynamic>? profileData;
      final profileResponse = await _supabase
          .from('profiles')
          .select('user_id, full_name, avatar_url, class')
          .eq('user_id', userId)
          .maybeSingle();
      profileData = profileResponse;

      return data.map((json) => _parseCommentWithProfileData(json, profileData)).toList();
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
  /// ACTUAL DB SCHEMA: id, event_id, author_id, content, created_at
  Future<CommentModel> postComment({
    required String eventId,
    required String text,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const UnauthorizedException('User not authenticated');
      }

      // Insert comment - DB uses author_id and content (not user_id and text)
      final response = await _supabase
          .from('comments')
          .insert({
            'event_id': eventId,
            'author_id': currentUserId,  // DB uses author_id
            'content': text.trim(),       // DB uses content
          })
          .select('*')
          .single();

      // Fetch profile for current user
      final profileResponse = await _supabase
          .from('profiles')
          .select('user_id, full_name, avatar_url, class')
          .eq('user_id', currentUserId)
          .maybeSingle();
      // Normalize DB response to model schema
      final normalizedJson = _normalizeCommentJson(response);
      return _parseCommentWithProfileData(normalizedJson, profileResponse);
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
  /// System enforces max 3-level threading server-side via trigger.
  /// depth 0 = top-level, depth 1-3 = replies
  Future<CommentModel> replyToComment({
    required String commentId,
    required String text,
  }) async {
    try {
      final currentUserId = _supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        throw const UnauthorizedException('User not authenticated');
      }

      // First, get the parent comment to get event_id and check depth
      final parentComment = await _supabase
          .from('comments')
          .select('event_id, depth')
          .eq('id', commentId)
          .single();

      // Client-side validation for better UX (server also enforces this)
      final parentDepth = parentComment['depth'] as int? ?? 0;
      if (parentDepth >= Comment.maxDepth) {
        throw ValidationException(
          'Non puoi rispondere a questo commento. Profondità massima raggiunta.',
          'depth',
          parentDepth.toString(),
          StackTrace.current,
        );
      }

      final eventId = parentComment['event_id'] as String;

      // Insert reply - DB uses author_id and content (not user_id and text)
      final response = await _supabase
          .from('comments')
          .insert({
            'event_id': eventId,
            'parent_comment_id': commentId,
            'author_id': currentUserId,  // DB uses author_id
            'content': text.trim(),       // DB uses content
          })
          .select('*')
          .single();

      // Fetch profile for current user
      final profileResponse = await _supabase
          .from('profiles')
          .select('user_id, full_name, avatar_url, class')
          .eq('user_id', currentUserId)
          .maybeSingle();

      // Normalize DB response to model schema
      final normalizedJson = _normalizeCommentJson(response);
      return _parseCommentWithProfileData(normalizedJson, profileResponse);
    } on PostgrestException catch (e, stackTrace) {
      if (e.code == '23514') {
        // CHECK constraint violation - could be profanity or max_nesting_depth
        if (e.message.contains('max_nesting_depth')) {
          throw ValidationException(
            'Non puoi rispondere a questo commento. Profondità massima raggiunta.',
            'depth',
            '',
            stackTrace,
          );
        }
        throw ValidationException(
          'Reply contains inappropriate language',
          'text',
          text,
          stackTrace,
        );
      } else if (e.code == 'P0001') {
        // Trigger exception
        if (e.message.contains('Maximum comment nesting depth')) {
          throw ValidationException(
            'Non puoi rispondere a questo commento. Profondità massima raggiunta.',
            'depth',
            '',
            stackTrace,
          );
        } else if (e.message.contains('Rate limit exceeded')) {
          throw RateLimitException(
            'Too many comments. Please wait before replying again.',
            const Duration(minutes: 5),
            stackTrace,
          );
        }
        throw _mapSupabaseError(e, stackTrace);
      } else if (e.code == '23503') {
        throw NotFoundException(
          'Parent comment not found or deleted',
          'comment',
          commentId,
          stackTrace,
        );
      }
      throw _mapSupabaseError(e, stackTrace);
    } on ValidationException {
      rethrow; // Client-side depth validation
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

      // Update comment without profile JOIN
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
          .select('*')
          .single();

      // Fetch profile for current user
      final profileResponse = await _supabase
          .from('profiles')
          .select('user_id, full_name, avatar_url, class')
          .eq('user_id', currentUserId)
          .maybeSingle();

      return _parseCommentWithProfileData(response, profileResponse);
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
          .isFilter('deleted_at', null); // Not already deleted
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
  Future<Comment> likeComment({
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

      // Fetch and return the updated comment
      final model = await getCommentById(commentId: commentId);
      return model.toEntity();
    } on PostgrestException catch (e, stackTrace) {
      if (e.code == '23505') {
        // Duplicate like (idempotent - return current comment state)
        final model = await getCommentById(commentId: commentId);
        return model.toEntity();
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
  Future<Comment> unlikeComment({
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

      // Fetch and return the updated comment
      final model = await getCommentById(commentId: commentId);
      return model.toEntity();
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
      // Note: SupabaseStreamBuilder only supports one .eq() filter
      // Additional filtering done in map callback
      return _supabase
          .from('comments')
          .stream(primaryKey: ['id'])
          .eq('event_id', eventId)
          .order('created_at')
          .map((List<Map<String, dynamic>> data) {
            // Filter top-level comments only (parent_comment_id is null)
            final topLevelComments = data.where(
              (json) => json['parent_comment_id'] == null
            );
            return topLevelComments
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
    // Extract profile data (may be nested as 'author' alias or flat)
    final profileData = json['author'] ?? json['profiles'];
    if (profileData != null && profileData is Map) {
      // Nested format from JOIN
      json['author_name'] = profileData['full_name'];
      json['author_avatar_url'] = profileData['avatar_url'];
      json['author_class'] = profileData['class'];
    }

    return CommentModel.fromJson(json);
  }

  /// Parse comment JSON with separately fetched profile data
  ///
  /// Used when FK relationship is not available for embedded select.
  CommentModel _parseCommentWithProfileData(
    Map<String, dynamic> json,
    Map<String, dynamic>? profileData,
  ) {
    if (profileData != null) {
      json['author_name'] = profileData['full_name'];
      json['author_avatar_url'] = profileData['avatar_url'];
      json['author_class'] = profileData['class'];
    }

    return CommentModel.fromJson(json);
  }

  /// Fetch replies for all top-level comments
  ///
  /// Efficiently batches all reply fetches into a single query.
  /// Note: We fetch replies for ALL comments, not just those with replyCount > 0,
  /// because reply_count might not be accurately maintained by triggers.
  Future<List<Comment>> _fetchRepliesForComments(
    List<Comment> comments,
    Map<String, Map<String, dynamic>> existingProfilesMap,
  ) async {
    if (comments.isEmpty) {
      return comments;
    }

    // Get all comment IDs to check for replies
    final commentIds = comments.map((c) => c.id).toList();

    try {
      // Fetch all replies in a single query
      final repliesResponse = await _supabase
          .from('comments')
          .select('*')
          .inFilter('parent_comment_id', commentIds)
          .order('created_at', ascending: true);

      final List<dynamic> repliesData = repliesResponse as List;

      if (repliesData.isEmpty) {
        return comments;
      }

      // Fetch profiles for reply authors not already in cache
      final replyAuthorIds = repliesData
          .map((json) => (json['author_id'] ?? json['user_id']) as String?)
          .whereType<String>()
          .where((id) => !existingProfilesMap.containsKey(id))
          .toSet()
          .toList();

      if (replyAuthorIds.isNotEmpty) {
        final profilesResponse = await _supabase
            .from('profiles')
            .select('user_id, full_name, avatar_url, class')
            .inFilter('user_id', replyAuthorIds);

        for (final profile in profilesResponse as List) {
          existingProfilesMap[profile['user_id'] as String] = profile;
        }
      }

      // Group replies by parent_comment_id
      final repliesByParent = <String, List<Comment>>{};
      for (final replyJson in repliesData) {
        final parentId = replyJson['parent_comment_id'] as String;
        final authorId = (replyJson['author_id'] ?? replyJson['user_id']) as String?;
        final profile = authorId != null ? existingProfilesMap[authorId] : null;

        final normalizedJson = _normalizeCommentJson(replyJson);
        final replyModel = _parseCommentWithProfileData(normalizedJson, profile);
        final reply = replyModel.toEntity();

        repliesByParent.putIfAbsent(parentId, () => []);
        repliesByParent[parentId]!.add(reply);
      }

      // Attach replies to parent comments
      return comments.map((comment) {
        final replies = repliesByParent[comment.id];
        if (replies != null && replies.isNotEmpty) {
          return comment.copyWith(replies: replies);
        }
        return comment;
      }).toList();
    } catch (e) {
      // Return original comments without replies on error
      return comments;
    }
  }

  /// Normalize actual DB schema to expected model schema
  ///
  /// ACTUAL DB: id, event_id, author_id, content, created_at
  /// MODEL EXPECTS: id, event_id, user_id, text, created_at, etc.
  Map<String, dynamic> _normalizeCommentJson(Map<String, dynamic> json) {
    return {
      ...json,
      // Map author_id -> user_id
      'user_id': json['author_id'] ?? json['user_id'],
      // Map content -> text
      'text': json['content'] ?? json['text'] ?? '',
      // Provide defaults for missing columns
      'parent_comment_id': json['parent_comment_id'],
      'like_count': json['like_count'] ?? 0,
      'reply_count': json['reply_count'] ?? 0,
      'report_count': json['report_count'] ?? 0,
      'deleted_at': json['deleted_at'],
      'updated_at': json['updated_at'],
    };
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
