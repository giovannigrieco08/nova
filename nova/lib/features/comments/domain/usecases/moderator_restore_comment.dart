import '../repositories/comments_repository_interface.dart';

/// ModeratorRestoreComment Use Case
///
/// Restores a hidden comment (reverses auto-hide false positives).
/// Moderator-only action to undo automatic hiding.
///
/// Business Rules:
/// - Only moderators/admins can execute this action (RLS enforced)
/// - Sets hidden_at = NULL, clears hidden_reason
/// - Comment becomes visible to all students again
/// - Action is logged for audit trail
///
/// **FR-031**: Moderators can restore auto-hidden comments
/// **FR-037**: All moderation actions are logged
///
/// Usage:
/// ```dart
/// final moderatorRestore = ref.read(moderatorRestoreCommentProvider);
/// try {
///   await moderatorRestore(commentId: '123');
///   // Show success: "Commento ripristinato"
/// } on UnauthorizedException catch (e) {
///   // Show: "Non hai i permessi per questa azione"
/// }
/// ```
class ModeratorRestoreComment {
  final CommentsRepositoryInterface _repository;

  ModeratorRestoreComment(this._repository);

  /// Execute use case
  ///
  /// Parameters:
  /// - [commentId]: ID of comment to restore
  ///
  /// Throws:
  /// - [NotFoundException]: Comment does not exist
  /// - [UnauthorizedException]: User is not a moderator/admin
  /// - [NotHiddenException]: Comment is not hidden
  /// - [NetworkException]: Network error
  Future<void> call({required String commentId}) async {
    await _repository.moderatorRestoreComment(commentId: commentId);
  }
}
