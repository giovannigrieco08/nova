import '../repositories/comments_repository_interface.dart';

/// DeleteComment Use Case
///
/// Soft-deletes a user's own comment with GDPR compliance.
///
/// Business Rules:
/// - User can only delete their own comments (RLS enforced)
/// - Soft delete: sets deleted_at timestamp, text = "[Commento eliminato]"
/// - If comment has replies: preserve structure, show placeholder
/// - If comment has 0 replies: can be fully removed later (GDPR erasure)
/// - Already deleted comments cannot be deleted again
///
/// **FR-036**: Students can delete their own comments
/// **FR-075**: GDPR Right to Erasure (soft delete mechanism)
///
/// Usage:
/// ```dart
/// final deleteComment = ref.read(deleteCommentProvider);
/// try {
///   await deleteComment(commentId: '123');
///   // Show success: comment deleted
/// } on NotFoundException catch (e) {
///   // Show: "Commento non trovato"
/// } on UnauthorizedException catch (e) {
///   // Show: "Non puoi eliminare questo commento"
/// }
/// ```
class DeleteComment {
  final CommentsRepositoryInterface _repository;

  DeleteComment(this._repository);

  /// Execute use case
  ///
  /// Parameters:
  /// - [commentId]: ID of comment to delete
  ///
  /// Throws:
  /// - [NotFoundException]: Comment does not exist
  /// - [UnauthorizedException]: User is not the comment author
  /// - [AlreadyDeletedException]: Comment already deleted
  /// - [NetworkException]: Network error
  Future<void> call({required String commentId}) async {
    await _repository.deleteComment(commentId: commentId);
  }
}
