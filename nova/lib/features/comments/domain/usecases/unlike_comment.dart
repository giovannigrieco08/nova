import '../entities/comment.dart';
import '../repositories/comments_repository_interface.dart';

/// UnlikeComment Use Case
///
/// Removes a like from a comment for the current user.
/// Idempotent: If user hasn't liked, returns comment unchanged (no-op).
///
/// Business Rules:
/// - User can only unlike comments they previously liked
/// - Deleted comments can be unliked (to cleanup orphaned likes)
/// - No rate limit on unlikes (only applies to liking)
///
/// **FR-028**: Students can like/unlike comments instantly
/// **FR-029**: Like count visible to all users (denormalized counter)
///
/// Usage:
/// ```dart
/// final unlikeComment = ref.read(unlikeCommentProvider);
/// try {
///   final updatedComment = await unlikeComment(commentId: '123');
///   // UI updates with decremented like count
/// } on NetworkException catch (_) {
///   // Show "Nessuna connessione. Riprova più tardi."
/// }
/// ```
class UnlikeComment {
  final CommentsRepositoryInterface _repository;

  UnlikeComment(this._repository);

  /// Execute use case
  ///
  /// Returns updated Comment entity with decremented like_count and isLikedByCurrentUser=false.
  /// Throws NetworkException on connectivity issues.
  /// Returns comment unchanged if user hasn't liked it (idempotent).
  Future<Comment> call({
    required String commentId,
  }) async {
    // No client-side validation needed (unlike is always safe)

    // Delegate to repository (handles idempotency)
    return await _repository.unlikeComment(
      commentId: commentId,
    );
  }
}
