import '../entities/comment.dart';
import '../repositories/comments_repository_interface.dart';

/// LikeComment Use Case
///
/// Adds a like to a comment from the current user.
/// Idempotent: If user already liked, returns existing like (no-op).
///
/// Business Rules:
/// - User cannot like their own comment (validation done server-side)
/// - User can like a comment only once (enforced by unique constraint)
/// - Rate limit: 100 likes per hour per user (enforced server-side)
/// - Deleted comments cannot be liked (check Comment.isDeleted client-side)
///
/// **FR-028**: Students can like/unlike comments instantly
/// **FR-029**: Like count visible to all users (denormalized counter)
/// **FR-030**: Rate limiting prevents like spam (100/hour)
///
/// Usage:
/// ```dart
/// final likeComment = ref.read(likeCommentProvider);
/// try {
///   final updatedComment = await likeComment(commentId: '123');
///   // UI updates with new like count
/// } on RateLimitException catch (e) {
///   // Show "Hai raggiunto il limite. Riprova tra Xm Ys"
/// }
/// ```
class LikeComment {
  final CommentsRepositoryInterface _repository;

  LikeComment(this._repository);

  /// Execute use case
  ///
  /// Returns updated Comment entity with new like_count and isLikedByCurrentUser=true.
  /// Throws RateLimitException if user exceeded 100 likes/hour.
  /// Throws ValidationException if comment is deleted.
  /// Throws NetworkException on connectivity issues.
  Future<Comment> call({
    required String commentId,
  }) async {
    // Client-side validation: cannot like deleted comments
    // (Server-side RLS prevents this too, but provide better UX)
    // Note: We don't have the comment entity here, so this check
    // is done in the repository/UI layer instead

    // Delegate to repository (handles idempotency)
    return await _repository.likeComment(
      commentId: commentId,
    );
  }
}
