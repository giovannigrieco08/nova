import 'package:uuid/uuid.dart';

import '../../domain/entities/comment.dart';
import '../../domain/entities/comment_report.dart';
import '../../domain/exceptions/comments_exceptions.dart';
import '../../domain/repositories/comments_repository_interface.dart';
import '../datasources/comments_local_datasource.dart';
import '../datasources/comments_remote_datasource.dart';

/// CommentsRepository
///
/// Implements CommentsRepositoryInterface by coordinating remote and local data sources.
/// Provides offline-first caching, optimistic updates, and queue-based sync.
///
/// Constitutional Principle 5 (SPEC_FIRST): Repository implements domain contract
/// using data layer abstractions, ensuring clean architecture separation.
///
/// Architecture:
/// - Read operations: Try cache first (if offline), fallback to network
/// - Write operations: Queue offline actions, sync when online
/// - Real-time: Direct stream from remote data source
class CommentsRepository implements CommentsRepositoryInterface {
  final CommentsRemoteDataSource _remoteDataSource;
  final CommentsLocalDataSource _localDataSource;
  final Uuid _uuid = const Uuid();

  CommentsRepository(this._remoteDataSource, this._localDataSource);

  // ==========================================================================
  // 1. QUERY OPERATIONS
  // ==========================================================================

  @override
  Future<PaginatedComments> getCommentsForEvent({
    required String eventId,
    CommentSortOrder sortOrder = CommentSortOrder.recent,
    int limit = 20,
    DateTime? cursorCreatedAt,
  }) async {
    try {
      // Try remote first
      final result = await _remoteDataSource.getCommentsForEvent(
        eventId: eventId,
        sortOrder: sortOrder,
        limit: limit,
        cursorCreatedAt: cursorCreatedAt,
      );

      // Cache comments for offline viewing (only cache first page)
      if (cursorCreatedAt == null && result.comments.isNotEmpty) {
        await _localDataSource.cacheComments(
          eventId: eventId,
          comments: result.comments,
        );
      }

      return result;
    } on NetworkException catch (_) {
      // Network error - try cache
      final cachedComments = await _localDataSource.getCachedComments(
        eventId: eventId,
      );

      if (cachedComments != null) {
        // Return cached data with no pagination
        return PaginatedComments(
          comments: cachedComments.map((model) => model.toEntity()).toList(),
          hasMore: false,
          nextCursor: null,
        );
      }

      // No cache available - rethrow network error
      rethrow;
    }
  }

  @override
  Future<List<Comment>> getRepliesForComment({
    required String commentId,
  }) async {
    final replies = await _remoteDataSource.getRepliesForComment(
      commentId: commentId,
    );

    return replies.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Comment> getCommentById({
    required String commentId,
  }) async {
    final comment = await _remoteDataSource.getCommentById(
      commentId: commentId,
    );

    return comment.toEntity();
  }

  @override
  Future<List<Comment>> getUserComments({
    required String userId,
    int limit = 50,
    int offset = 0,
  }) async {
    final comments = await _remoteDataSource.getUserComments(
      userId: userId,
      limit: limit,
      offset: offset,
    );

    return comments.map((model) => model.toEntity()).toList();
  }

  // ==========================================================================
  // 2. MUTATION OPERATIONS
  // ==========================================================================

  @override
  Future<Comment> postComment({
    required String eventId,
    required String text,
  }) async {
    try {
      final comment = await _remoteDataSource.postComment(
        eventId: eventId,
        text: text,
      );

      return comment.toEntity();
    } on NetworkException catch (_) {
      // Queue for offline sync
      final tempId = _uuid.v4();
      await _localDataSource.queueOfflineAction(
        action: OfflineCommentAction(
          tempId: tempId,
          type: OfflineActionType.post,
          eventId: eventId,
          text: text,
          queuedAt: DateTime.now(),
        ),
      );

      // Rethrow network exception so UI can show pending state
      rethrow;
    }
  }

  @override
  Future<Comment> replyToComment({
    required String commentId,
    required String text,
  }) async {
    try {
      final reply = await _remoteDataSource.replyToComment(
        commentId: commentId,
        text: text,
      );

      return reply.toEntity();
    } on NetworkException catch (_) {
      // Queue for offline sync
      final tempId = _uuid.v4();
      await _localDataSource.queueOfflineAction(
        action: OfflineCommentAction(
          tempId: tempId,
          type: OfflineActionType.reply,
          parentCommentId: commentId,
          text: text,
          queuedAt: DateTime.now(),
        ),
      );

      rethrow;
    }
  }

  @override
  Future<Comment> editComment({
    required String commentId,
    required String newText,
  }) async {
    try {
      final comment = await _remoteDataSource.editComment(
        commentId: commentId,
        newText: newText,
      );

      return comment.toEntity();
    } on NetworkException catch (_) {
      // Queue for offline sync
      final tempId = _uuid.v4();
      await _localDataSource.queueOfflineAction(
        action: OfflineCommentAction(
          tempId: tempId,
          type: OfflineActionType.edit,
          commentId: commentId,
          text: newText,
          queuedAt: DateTime.now(),
        ),
      );

      rethrow;
    }
  }

  @override
  Future<void> deleteComment({
    required String commentId,
  }) async {
    try {
      await _remoteDataSource.deleteComment(
        commentId: commentId,
      );
    } on NetworkException catch (_) {
      // Queue for offline sync
      final tempId = _uuid.v4();
      await _localDataSource.queueOfflineAction(
        action: OfflineCommentAction(
          tempId: tempId,
          type: OfflineActionType.delete,
          commentId: commentId,
          queuedAt: DateTime.now(),
        ),
      );

      rethrow;
    }
  }

  // ==========================================================================
  // 3. LIKE OPERATIONS
  // ==========================================================================

  @override
  Future<void> likeComment({
    required String commentId,
  }) async {
    try {
      await _remoteDataSource.likeComment(
        commentId: commentId,
      );
    } on NetworkException catch (_) {
      // Queue for offline sync
      final tempId = _uuid.v4();
      await _localDataSource.queueOfflineAction(
        action: OfflineCommentAction(
          tempId: tempId,
          type: OfflineActionType.like,
          commentId: commentId,
          queuedAt: DateTime.now(),
        ),
      );

      rethrow;
    }
  }

  @override
  Future<void> unlikeComment({
    required String commentId,
  }) async {
    try {
      await _remoteDataSource.unlikeComment(
        commentId: commentId,
      );
    } on NetworkException catch (_) {
      // Queue for offline sync
      final tempId = _uuid.v4();
      await _localDataSource.queueOfflineAction(
        action: OfflineCommentAction(
          tempId: tempId,
          type: OfflineActionType.unlike,
          commentId: commentId,
          queuedAt: DateTime.now(),
        ),
      );

      rethrow;
    }
  }

  // ==========================================================================
  // 4. REPORT OPERATIONS
  // ==========================================================================

  @override
  Future<CommentReport> reportComment({
    required String commentId,
    required CommentReportReason reason,
    String? details,
  }) async {
    try {
      final report = await _remoteDataSource.reportComment(
        commentId: commentId,
        reason: reason,
        details: details,
      );

      return report.toEntity();
    } on NetworkException catch (_) {
      // Queue for offline sync
      final tempId = _uuid.v4();
      await _localDataSource.queueOfflineAction(
        action: OfflineCommentAction(
          tempId: tempId,
          type: OfflineActionType.report,
          commentId: commentId,
          reportReason: reason,
          reportDetails: details,
          queuedAt: DateTime.now(),
        ),
      );

      rethrow;
    }
  }

  // ==========================================================================
  // 5. MODERATION OPERATIONS (Moderator-Only)
  // ==========================================================================

  @override
  Future<void> moderatorRemoveComment({
    required String commentId,
    String? reason,
  }) async {
    await _remoteDataSource.moderatorRemoveComment(
      commentId: commentId,
      reason: reason,
    );
  }

  @override
  Future<void> moderatorRestoreComment({
    required String commentId,
  }) async {
    await _remoteDataSource.moderatorRestoreComment(
      commentId: commentId,
    );
  }

  // ==========================================================================
  // 6. REAL-TIME OPERATIONS
  // ==========================================================================

  @override
  Stream<List<Comment>> subscribeToComments({
    required String eventId,
  }) {
    return _remoteDataSource
        .subscribeToComments(eventId: eventId)
        .map((models) => models.map((model) => model.toEntity()).toList());
  }

  // ==========================================================================
  // 7. OFFLINE OPERATIONS
  // ==========================================================================

  @override
  Future<List<Comment>?> getCachedComments({
    required String eventId,
  }) async {
    final cachedComments = await _localDataSource.getCachedComments(
      eventId: eventId,
    );

    return cachedComments?.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> cacheComments({
    required String eventId,
    required List<Comment> comments,
  }) async {
    // Convert entities to models for caching
    final models = comments
        .map((entity) => _commentEntityToModel(entity))
        .toList();

    await _localDataSource.cacheComments(
      eventId: eventId,
      comments: models,
    );
  }

  @override
  Future<void> queueOfflineAction({
    required OfflineCommentAction action,
  }) async {
    await _localDataSource.queueOfflineAction(action: action);
  }

  @override
  Future<OfflineSyncResult> syncOfflineQueue() async {
    final queue = await _localDataSource.getOfflineQueue();

    if (queue.isEmpty) {
      return const OfflineSyncResult(
        successCount: 0,
        failureCount: 0,
        errors: [],
      );
    }

    int successCount = 0;
    int failureCount = 0;
    final errors = <OfflineActionError>[];

    // Process queue in FIFO order
    for (final action in queue) {
      try {
        await _executeOfflineAction(action);
        await _localDataSource.removeFromQueue(tempId: action.tempId);
        successCount++;
      } on NetworkException catch (e) {
        // Network still unavailable - stop syncing, keep queue
        return OfflineSyncResult(
          successCount: successCount,
          failureCount: failureCount,
          errors: errors,
        );
      } catch (e) {
        // Other error (validation, permission, etc.) - remove from queue
        await _localDataSource.removeFromQueue(tempId: action.tempId);
        failureCount++;
        errors.add(OfflineActionError(action, e as Exception));
      }
    }

    return OfflineSyncResult(
      successCount: successCount,
      failureCount: failureCount,
      errors: errors,
    );
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  /// Execute a single offline action
  ///
  /// Maps action type to corresponding remote data source method.
  Future<void> _executeOfflineAction(OfflineCommentAction action) async {
    switch (action.type) {
      case OfflineActionType.post:
        await _remoteDataSource.postComment(
          eventId: action.eventId!,
          text: action.text!,
        );
        break;

      case OfflineActionType.reply:
        await _remoteDataSource.replyToComment(
          commentId: action.parentCommentId!,
          text: action.text!,
        );
        break;

      case OfflineActionType.edit:
        await _remoteDataSource.editComment(
          commentId: action.commentId!,
          newText: action.text!,
        );
        break;

      case OfflineActionType.delete:
        await _remoteDataSource.deleteComment(
          commentId: action.commentId!,
        );
        break;

      case OfflineActionType.like:
        await _remoteDataSource.likeComment(
          commentId: action.commentId!,
        );
        break;

      case OfflineActionType.unlike:
        await _remoteDataSource.unlikeComment(
          commentId: action.commentId!,
        );
        break;

      case OfflineActionType.report:
        await _remoteDataSource.reportComment(
          commentId: action.commentId!,
          reason: action.reportReason!,
          details: action.reportDetails,
        );
        break;
    }
  }

  /// Convert Comment entity to CommentModel for caching
  ///
  /// Helper to avoid circular imports.
  dynamic _commentEntityToModel(Comment entity) {
    // Use dynamic to avoid importing CommentModel here
    // Alternative: Create a factory method in CommentModel
    return {
      'id': entity.id,
      'event_id': entity.eventId,
      'user_id': entity.userId,
      'parent_comment_id': entity.parentCommentId,
      'text': entity.text,
      'like_count': entity.likeCount,
      'reply_count': entity.replyCount,
      'report_count': entity.reportCount,
      'deleted_at': entity.deletedAt?.toIso8601String(),
      'deleted_by_user_id': entity.deletedByUserId,
      'hidden_at': entity.hiddenAt?.toIso8601String(),
      'hidden_reason': entity.hiddenReason,
      'moderator_id': entity.moderatorId,
      'created_at': entity.createdAt.toIso8601String(),
      'updated_at': entity.updatedAt?.toIso8601String(),
      'author_name': entity.authorName,
      'author_avatar_url': entity.authorAvatarUrl,
      'author_class': entity.authorClass,
      'author_role': entity.authorRole,
      'is_liked_by_current_user': entity.isLikedByCurrentUser,
    };
  }
}
