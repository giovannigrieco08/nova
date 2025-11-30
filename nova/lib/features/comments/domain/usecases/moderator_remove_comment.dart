import '../repositories/comments_repository_interface.dart';

/// ModeratorRemoveComment Use Case
///
/// Hard-hides an inappropriate comment with action logging.
/// Moderator-only action that removes comment from all student views.
///
/// Business Rules:
/// - Only moderators/admins can execute this action (RLS enforced)
/// - Sets hidden_at, hidden_reason = 'moderator_removed', moderator_id
/// - Comment disappears from student views immediately
/// - Action is logged for audit trail
/// - Comment author receives notification with reason
///
/// **FR-030**: Moderators can remove inappropriate comments
/// **FR-037**: All moderation actions are logged
///
/// Usage:
/// ```dart
/// final moderatorRemove = ref.read(moderatorRemoveCommentProvider);
/// try {
///   await moderatorRemove(
///     commentId: '123',
///     reason: 'Linguaggio inappropriato',
///   );
///   // Show success: "Commento rimosso"
/// } on UnauthorizedException catch (e) {
///   // Show: "Non hai i permessi per questa azione"
/// }
/// ```
class ModeratorRemoveComment {
  final CommentsRepositoryInterface _repository;

  ModeratorRemoveComment(this._repository);

  /// Execute use case
  ///
  /// Parameters:
  /// - [commentId]: ID of comment to remove
  /// - [reason]: Reason for removal (shown to comment author)
  ///
  /// Throws:
  /// - [NotFoundException]: Comment does not exist
  /// - [UnauthorizedException]: User is not a moderator/admin
  /// - [AlreadyHiddenException]: Comment already hidden
  /// - [NetworkException]: Network error
  Future<void> call({
    required String commentId,
    required String reason,
  }) async {
    // Validate reason
    if (reason.trim().isEmpty) {
      throw ValidationException(
        message: 'È richiesta una motivazione per la rimozione',
      );
    }

    if (reason.length > 500) {
      throw ValidationException(
        message: 'La motivazione non può superare 500 caratteri',
      );
    }

    await _repository.moderatorRemoveComment(
      commentId: commentId,
      reason: reason,
    );
  }
}

/// Validation exception for moderator actions
class ValidationException implements Exception {
  final String message;
  final StackTrace? stackTrace;

  ValidationException({required this.message, this.stackTrace});

  @override
  String toString() => 'ValidationException: $message';
}
