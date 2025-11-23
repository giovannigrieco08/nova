import '../entities/comment.dart';
import '../entities/comment_report.dart';

/// Comments Repository Interface
///
/// Abstract contract defining all operations for the comments feature.
/// Data layer implementations must provide concrete implementations.
///
/// Constitutional Principle 5 (SPEC_FIRST): Domain layer defines contracts,
/// data layer provides implementations. This ensures clean architecture
/// separation and testability.

// ============================================================================
// SUPPORTING TYPES
// ============================================================================

/// Sort order for comments
enum CommentSortOrder {
  recent, // created_at DESC (default)
  popular, // like_count DESC, created_at DESC
}

/// Paginated comments result
class PaginatedComments {
  final List<Comment> comments;
  final bool hasMore; // True if more pages available
  final DateTime? nextCursor; // Cursor for next page (created_at of last comment)

  const PaginatedComments({
    required this.comments,
    required this.hasMore,
    this.nextCursor,
  });
}

/// Offline action types
enum OfflineActionType {
  post,
  reply,
  edit,
  delete,
  like,
  unlike,
  report,
}

/// Offline comment action (queued when offline)
class OfflineCommentAction {
  final String tempId; // Client-generated UUID
  final OfflineActionType type;
  final String? commentId; // For edit, delete, like, unlike, report
  final String? eventId; // For post
  final String? parentCommentId; // For reply
  final String? text; // For post, reply, edit
  final CommentReportReason? reportReason; // For report
  final String? reportDetails; // For report
  final DateTime queuedAt;

  const OfflineCommentAction({
    required this.tempId,
    required this.type,
    this.commentId,
    this.eventId,
    this.parentCommentId,
    this.text,
    this.reportReason,
    this.reportDetails,
    required this.queuedAt,
  });
}

/// Offline action error (for sync failures)
class OfflineActionError {
  final OfflineCommentAction action;
  final Exception exception;

  const OfflineActionError(this.action, this.exception);
}

/// Offline sync result
class OfflineSyncResult {
  final int successCount;
  final int failureCount;
  final List<OfflineActionError> errors;

  const OfflineSyncResult({
    required this.successCount,
    required this.failureCount,
    required this.errors,
  });
}

// ============================================================================
// REPOSITORY INTERFACE
// ============================================================================

abstract class CommentsRepositoryInterface {
  // ==========================================================================
  // 1. QUERY OPERATIONS (4 methods)
  // ==========================================================================

  /// Fetch paginated top-level comments for an event with optional sorting
  ///
  /// Parameters:
  /// - [eventId]: Event UUID to fetch comments for
  /// - [sortOrder]: Sort by recent (created_at DESC) or popular (like_count DESC)
  /// - [limit]: Number of comments per page (default 20, max 50)
  /// - [cursorCreatedAt]: Cursor for pagination (timestamp of last comment from previous page)
  ///
  /// Returns: [PaginatedComments] with comments list, hasMore flag, and nextCursor
  ///
  /// Throws:
  /// - [NetworkException]: Network error or timeout
  /// - [UnauthorizedException]: User not authenticated
  /// - [NotFoundException]: Event does not exist
  /// - [ServerException]: Supabase error (5xx)
  Future<PaginatedComments> getCommentsForEvent({
    required String eventId,
    CommentSortOrder sortOrder = CommentSortOrder.recent,
    int limit = 20,
    DateTime? cursorCreatedAt,
  });

  /// Fetch all replies for a specific top-level comment
  ///
  /// Parameters:
  /// - [commentId]: Parent comment UUID
  ///
  /// Returns: List of [Comment] entities (sorted by created_at ASC)
  ///
  /// Throws:
  /// - [NetworkException]: Network error
  /// - [UnauthorizedException]: User not authenticated
  /// - [NotFoundException]: Parent comment does not exist
  /// - [ServerException]: Supabase error
  Future<List<Comment>> getRepliesForComment({
    required String commentId,
  });

  /// Fetch a single comment by ID (used for real-time updates)
  ///
  /// Parameters:
  /// - [commentId]: Comment UUID
  ///
  /// Returns: [Comment] entity
  ///
  /// Throws:
  /// - [NetworkException]: Network error
  /// - [UnauthorizedException]: User not authenticated
  /// - [NotFoundException]: Comment does not exist or is deleted
  /// - [ServerException]: Supabase error
  Future<Comment> getCommentById({
    required String commentId,
  });

  /// Fetch all comments posted by a specific user (for profile view)
  ///
  /// Parameters:
  /// - [userId]: User UUID
  /// - [limit]: Max comments to return (default 50)
  /// - [offset]: Skip first N comments (for pagination)
  ///
  /// Returns: List of [Comment] entities (sorted by created_at DESC)
  ///
  /// Throws:
  /// - [NetworkException]: Network error
  /// - [UnauthorizedException]: User not authenticated
  /// - [ServerException]: Supabase error
  Future<List<Comment>> getUserComments({
    required String userId,
    int limit = 50,
    int offset = 0,
  });

  // ==========================================================================
  // 2. MUTATION OPERATIONS (5 methods)
  // ==========================================================================

  /// Create a new top-level comment on an event
  ///
  /// Parameters:
  /// - [eventId]: Event UUID
  /// - [text]: Comment text (1-500 chars after trim)
  ///
  /// Returns: Created [Comment] entity with generated UUID
  ///
  /// Throws:
  /// - [ValidationException]: Text length invalid or contains profanity
  /// - [RateLimitException]: User exceeded rate limit (3 identical comments in 5 min)
  /// - [NetworkException]: Network error
  /// - [UnauthorizedException]: User not authenticated
  /// - [ForbiddenException]: Event not approved or user not allowed to comment
  /// - [ServerException]: Supabase error
  Future<Comment> postComment({
    required String eventId,
    required String text,
  });

  /// Create a reply to an existing comment (top-level or reply)
  ///
  /// Parameters:
  /// - [commentId]: Parent comment UUID (can be top-level or reply - system enforces 1-level max)
  /// - [text]: Reply text (1-500 chars after trim)
  ///
  /// Returns: Created [Comment] entity with parent_comment_id set
  ///
  /// Throws:
  /// - [ValidationException]: Text length invalid or contains profanity
  /// - [RateLimitException]: User exceeded rate limit
  /// - [NetworkException]: Network error
  /// - [UnauthorizedException]: User not authenticated
  /// - [NotFoundException]: Parent comment does not exist
  /// - [ForbiddenException]: Parent comment is deleted or hidden
  /// - [ServerException]: Supabase error
  Future<Comment> replyToComment({
    required String commentId,
    required String text,
  });

  /// Edit own comment within 5-minute window
  ///
  /// Parameters:
  /// - [commentId]: Comment UUID to edit
  /// - [newText]: Updated text (1-500 chars after trim)
  ///
  /// Returns: Updated [Comment] entity with updated_at set to NOW()
  ///
  /// Throws:
  /// - [ValidationException]: Text length invalid or contains profanity
  /// - [ForbiddenException]: Comment not owned by user, or edit window expired (>5 min)
  /// - [NetworkException]: Network error
  /// - [UnauthorizedException]: User not authenticated
  /// - [NotFoundException]: Comment does not exist
  /// - [ServerException]: Supabase error
  Future<Comment> editComment({
    required String commentId,
    required String newText,
  });

  /// Soft-delete own comment (text replaced with "[Commento eliminato]")
  ///
  /// Parameters:
  /// - [commentId]: Comment UUID to delete
  ///
  /// Returns: void (success is no exception thrown)
  ///
  /// Throws:
  /// - [ForbiddenException]: Comment not owned by user, or already deleted
  /// - [NetworkException]: Network error
  /// - [UnauthorizedException]: User not authenticated
  /// - [NotFoundException]: Comment does not exist
  /// - [ServerException]: Supabase error
  Future<void> deleteComment({
    required String commentId,
  });

  // ==========================================================================
  // 3. LIKE OPERATIONS (2 methods)
  // ==========================================================================

  /// Add a like to a comment (idempotent - duplicate likes ignored)
  ///
  /// Parameters:
  /// - [commentId]: Comment UUID to like
  ///
  /// Returns: void (success is no exception thrown)
  ///
  /// Side Effects:
  /// - Increments like_count on comment (via database trigger)
  /// - Inserts row in comment_likes table
  ///
  /// Throws:
  /// - [RateLimitException]: User exceeded like rate limit (100 likes/hour)
  /// - [NetworkException]: Network error
  /// - [UnauthorizedException]: User not authenticated
  /// - [NotFoundException]: Comment does not exist or is deleted
  /// - [ServerException]: Supabase error
  Future<void> likeComment({
    required String commentId,
  });

  /// Remove a like from a comment (idempotent - unliking already-unliked comment is no-op)
  ///
  /// Parameters:
  /// - [commentId]: Comment UUID to unlike
  ///
  /// Returns: void (success is no exception thrown)
  ///
  /// Side Effects:
  /// - Decrements like_count on comment (via database trigger)
  /// - Deletes row from comment_likes table
  ///
  /// Throws:
  /// - [NetworkException]: Network error
  /// - [UnauthorizedException]: User not authenticated
  /// - [NotFoundException]: Comment does not exist
  /// - [ServerException]: Supabase error
  Future<void> unlikeComment({
    required String commentId,
  });

  // ==========================================================================
  // 4. REPORT OPERATIONS (1 method)
  // ==========================================================================

  /// Submit a report for inappropriate comment
  ///
  /// Parameters:
  /// - [commentId]: Comment UUID to report
  /// - [reason]: Enum value (spam, inappropriate, bullying, off_topic)
  /// - [details]: Optional elaboration (max 500 chars)
  ///
  /// Returns: Created [CommentReport] entity
  ///
  /// Side Effects:
  /// - Increments report_count on comment (via database trigger)
  /// - Auto-hides comment if report_count >= 3 (via database trigger)
  ///
  /// Throws:
  /// - [ValidationException]: Details exceed 500 chars
  /// - [ConflictException]: User already reported this comment
  /// - [NetworkException]: Network error
  /// - [UnauthorizedException]: User not authenticated
  /// - [NotFoundException]: Comment does not exist
  /// - [ServerException]: Supabase error
  Future<CommentReport> reportComment({
    required String commentId,
    required CommentReportReason reason,
    String? details,
  });

  // ==========================================================================
  // 5. MODERATION OPERATIONS (2 methods - Moderator-Only)
  // ==========================================================================

  /// Hard-hide a comment (moderator action)
  ///
  /// Parameters:
  /// - [commentId]: Comment UUID to remove
  /// - [reason]: Internal notes explaining removal
  ///
  /// Returns: void (success is no exception thrown)
  ///
  /// Side Effects:
  /// - Sets hidden_at = NOW(), hidden_reason = 'moderator_removed', moderator_id = current_user
  /// - Comment no longer visible to students (visible to moderators for audit)
  ///
  /// Throws:
  /// - [ForbiddenException]: User is not a moderator
  /// - [NetworkException]: Network error
  /// - [UnauthorizedException]: User not authenticated
  /// - [NotFoundException]: Comment does not exist
  /// - [ServerException]: Supabase error
  Future<void> moderatorRemoveComment({
    required String commentId,
    String? reason,
  });

  /// Restore an auto-hidden comment (moderator reviewed and approved)
  ///
  /// Parameters:
  /// - [commentId]: Comment UUID to restore
  ///
  /// Returns: void (success is no exception thrown)
  ///
  /// Side Effects:
  /// - Sets hidden_at = NULL, hidden_reason = NULL
  /// - Comment becomes visible to students again
  ///
  /// Throws:
  /// - [ForbiddenException]: User is not a moderator
  /// - [NetworkException]: Network error
  /// - [UnauthorizedException]: User not authenticated
  /// - [NotFoundException]: Comment does not exist or not hidden
  /// - [ServerException]: Supabase error
  Future<void> moderatorRestoreComment({
    required String commentId,
  });

  // ==========================================================================
  // 6. REAL-TIME OPERATIONS (1 method)
  // ==========================================================================

  /// Subscribe to real-time comment updates for an event
  ///
  /// Parameters:
  /// - [eventId]: Event UUID to subscribe to
  ///
  /// Returns: Stream<List<Comment>> that emits updated comment list on each change
  ///
  /// Behavior:
  /// - Emits initial snapshot of all top-level comments
  /// - Emits updated list on INSERT, UPDATE, DELETE operations (via Supabase Realtime)
  /// - Stream closes when disposed or on error
  ///
  /// Throws (emitted via stream):
  /// - [NetworkException]: WebSocket connection failed
  /// - [UnauthorizedException]: User not authenticated
  /// - [ServerException]: Supabase Realtime error
  Stream<List<Comment>> subscribeToComments({
    required String eventId,
  });

  // ==========================================================================
  // 7. OFFLINE OPERATIONS (4 methods)
  // ==========================================================================

  /// Fetch comments from local Hive cache (offline support)
  ///
  /// Parameters:
  /// - [eventId]: Event UUID
  ///
  /// Returns: List of [Comment] entities from cache, or null if cache miss or expired (15-min TTL)
  ///
  /// Throws:
  /// - [CacheException]: Hive database error
  Future<List<Comment>?> getCachedComments({
    required String eventId,
  });

  /// Store comments in local Hive cache for offline viewing
  ///
  /// Parameters:
  /// - [eventId]: Event UUID (cache key)
  /// - [comments]: List of comments to cache
  ///
  /// Returns: void (success is no exception thrown)
  ///
  /// Throws:
  /// - [CacheException]: Hive database error (e.g., disk full)
  Future<void> cacheComments({
    required String eventId,
    required List<Comment> comments,
  });

  /// Queue a comment action (post, like, delete, report) for sync when online
  ///
  /// Parameters:
  /// - [action]: Action data (type, comment ID, text, etc.)
  ///
  /// Returns: void (success is no exception thrown)
  ///
  /// Throws:
  /// - [CacheException]: Hive database error
  Future<void> queueOfflineAction({
    required OfflineCommentAction action,
  });

  /// Sync all queued offline actions to server
  ///
  /// Returns: [OfflineSyncResult] with success/failure counts and errors
  ///
  /// Throws:
  /// - [NetworkException]: Network unavailable (queue remains, retry later)
  /// - [CacheException]: Hive database error
  Future<OfflineSyncResult> syncOfflineQueue();
}
