import '../../../../core/exceptions/nova_exceptions.dart';
import '../entities/comment_report.dart';
import '../repositories/comments_repository_interface.dart';

/// ReportComment Use Case
///
/// Submits a report for an inappropriate comment.
/// Prevents duplicate reports from same user.
///
/// Business Rules:
/// - User can only report a comment once
/// - Reports with valid reasons are logged for moderation
/// - 3+ reports trigger auto-hide and moderator notification
/// - Server-side validation ensures user exists and comment exists
///
/// **FR-033**: Students can report comments for moderation
/// **FR-034**: 3+ reports trigger auto-hide
/// **FR-035**: Moderators are notified of auto-hidden comments
///
/// Usage:
/// ```dart
/// final reportComment = ref.read(reportCommentProvider);
/// try {
///   await reportComment(
///     commentId: '123',
///     reason: CommentReportReason.inappropriate,
///     additionalDetails: 'Contains offensive language',
///   );
///   // Show success: "Segnalazione inviata"
/// } on ConflictException catch (e) {
///   // Show: "Hai già segnalato questo commento"
/// }
/// ```
class ReportComment {
  final CommentsRepositoryInterface _repository;

  ReportComment(this._repository);

  /// Execute use case
  ///
  /// Parameters:
  /// - [commentId]: ID of comment to report
  /// - [reason]: Reason for reporting (enum)
  /// - [details]: Optional text for "Altro" reason
  ///
  /// Throws:
  /// - [ConflictException]: User already reported this comment
  /// - [NotFoundException]: Comment does not exist
  /// - [ValidationException]: Invalid reason or details too long
  /// - [NetworkException]: Network error
  Future<void> call({
    required String commentId,
    required CommentReportReason reason,
    String? details,
  }) async {
    // Validate details length
    if (details != null && details.length > 500) {
      throw const ValidationException(
        'I dettagli aggiuntivi non possono superare 500 caratteri',
        field: 'details',
      );
    }

    // Submit report to repository
    await _repository.reportComment(
      commentId: commentId,
      reason: reason,
      details: details,
    );
  }
}
