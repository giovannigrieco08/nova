import '../entities/comment.dart';
import '../repositories/comments_repository_interface.dart';

/// EditComment Use Case
///
/// Allows students to edit their own comments within a 5-minute window.
/// Shows "(modificato)" indicator after edit.
///
/// **T104**: Edit comment with 5-min window validation
///
/// Business Rules:
/// - Only the comment author can edit (RLS enforced)
/// - Edit window: 5 minutes from creation (NOW() - created_at <= 5 minutes)
/// - Text validation: 1-500 chars after trim
/// - Profanity filter applied server-side
/// - Sets updated_at = NOW() after successful edit
///
/// **FR-035**: Students can edit own comments within 5 minutes
/// **NFR-017**: Edit window is 5 minutes, not configurable
///
/// Usage:
/// ```dart
/// final editComment = ref.read(editCommentProvider);
/// try {
///   final updatedComment = await editComment(
///     commentId: '123',
///     newText: 'Fixed typo',
///   );
///   // Show success: comment updated with "(modificato)"
/// } on EditWindowExpiredException catch (e) {
///   // Show: "Tempo scaduto per modifica (>5 min)"
/// } on ValidationException catch (e) {
///   // Show: "Il commento contiene linguaggio inappropriato"
/// }
/// ```
class EditComment {
  final CommentsRepositoryInterface _repository;

  /// Edit window duration (5 minutes)
  static const Duration editWindow = Duration(minutes: 5);

  EditComment(this._repository);

  /// Execute use case
  ///
  /// Parameters:
  /// - [commentId]: ID of comment to edit
  /// - [newText]: New text content (1-500 chars after trim)
  ///
  /// Returns: Updated [Comment] with updated_at set
  ///
  /// Throws:
  /// - [EditWindowExpiredException]: More than 5 minutes since creation
  /// - [ValidationException]: Text empty, too long, or contains profanity
  /// - [UnauthorizedException]: Not the comment author
  /// - [NotFoundException]: Comment does not exist
  /// - [NetworkException]: Network error
  Future<Comment> call({
    required String commentId,
    required String newText,
  }) async {
    // Client-side validation
    final trimmedText = newText.trim();

    if (trimmedText.isEmpty) {
      throw EditValidationException(
        message: 'Il commento non può essere vuoto',
      );
    }

    if (trimmedText.length > 500) {
      throw EditValidationException(
        message: 'Il commento non può superare i 500 caratteri',
      );
    }

    // Server-side handles:
    // - 5-minute window validation
    // - Author verification (RLS)
    // - Profanity filter
    return await _repository.editComment(
      commentId: commentId,
      newText: trimmedText,
    );
  }

  /// Check if a comment is still editable (client-side check)
  ///
  /// Returns true if comment was created within the last 5 minutes.
  /// Note: Server performs authoritative check - this is for UI hint only.
  bool canEdit(Comment comment) {
    final now = DateTime.now();
    final elapsed = now.difference(comment.createdAt);
    return elapsed <= editWindow;
  }

  /// Get remaining edit time in seconds
  ///
  /// Returns 0 if edit window has expired.
  int remainingEditSeconds(Comment comment) {
    final now = DateTime.now();
    final elapsed = now.difference(comment.createdAt);
    final remaining = editWindow - elapsed;
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }
}

/// Edit validation exception
class EditValidationException implements Exception {
  final String message;

  EditValidationException({required this.message});

  @override
  String toString() => 'EditValidationException: $message';
}

/// Edit window expired exception
class EditWindowExpiredException implements Exception {
  final String message;

  EditWindowExpiredException({
    this.message = 'Tempo scaduto per modifica (>5 min)',
  });

  @override
  String toString() => 'EditWindowExpiredException: $message';
}
