import '../entities/comment.dart';
import '../repositories/comments_repository_interface.dart';

/// Use Case: Get Comments For Event
///
/// Fetches paginated top-level comments for a specific event.
/// Supports sorting by recent or popular.
///
/// Business Rules:
/// - Only returns non-deleted, non-hidden comments
/// - Top-level comments only (parentCommentId = null)
/// - Default sort: recent (created_at DESC)
/// - Default limit: 20 comments per page
/// - Returns PaginatedComments with hasMore flag and nextCursor
///
/// Constitutional Principle 5 (SPEC_FIRST): Use cases encapsulate business logic
/// and coordinate repository calls. Single Responsibility Principle applied.
class GetCommentsForEvent {
  final CommentsRepositoryInterface _repository;

  GetCommentsForEvent(this._repository);

  /// Execute use case
  ///
  /// Parameters:
  /// - [eventId]: Event UUID to fetch comments for
  /// - [sortOrder]: Sort by recent (default) or popular
  /// - [limit]: Comments per page (default 20, max 50)
  /// - [cursorCreatedAt]: Pagination cursor (timestamp of last comment)
  ///
  /// Returns: PaginatedComments with comments list, hasMore flag, nextCursor
  ///
  /// Throws:
  /// - [NetworkException]: Network error or timeout
  /// - [UnauthorizedException]: User not authenticated
  /// - [NotFoundException]: Event does not exist
  /// - [ServerException]: Supabase error (5xx)
  Future<PaginatedComments> call({
    required String eventId,
    CommentSortOrder sortOrder = CommentSortOrder.recent,
    int limit = 20,
    DateTime? cursorCreatedAt,
  }) async {
    return await _repository.getCommentsForEvent(
      eventId: eventId,
      sortOrder: sortOrder,
      limit: limit,
      cursorCreatedAt: cursorCreatedAt,
    );
  }
}
