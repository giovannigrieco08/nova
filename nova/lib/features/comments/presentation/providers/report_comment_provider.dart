import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/comment_report.dart';
import '../../domain/usecases/report_comment.dart';
import 'comments_notifier.dart';

/// Provider for ReportComment use case
///
/// Usage:
/// ```dart
/// final reportComment = ref.read(reportCommentProvider);
/// await reportComment(
///   commentId: '123',
///   reason: CommentReportReason.inappropriate,
///   details: 'Optional details',
/// );
/// ```
final reportCommentProvider = Provider<ReportComment>((ref) {
  final repository = ref.read(commentsRepositoryProvider);
  return ReportComment(repository);
});

/// State notifier for report submission
///
/// Manages the async state of submitting a comment report.
/// Handles loading, success, and error states.
class ReportCommentNotifier extends StateNotifier<AsyncValue<void>> {
  final ReportComment _reportComment;

  ReportCommentNotifier(this._reportComment) : super(const AsyncValue.data(null));

  /// Submit a report
  ///
  /// Returns result indicating success, duplicate, validation error, or generic error.
  /// Handles duplicate report detection (ConflictException).
  Future<ReportSubmissionResult> submitReport({
    required String commentId,
    required CommentReportReason reason,
    String? details,
  }) async {
    state = const AsyncValue.loading();

    try {
      await _reportComment(
        commentId: commentId,
        reason: reason,
        details: details,
      );
      state = const AsyncValue.data(null);
      return ReportSubmissionResult.success;
    } on ValidationException catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
      return ReportSubmissionResult.validationError;
    } catch (e) {
      // Check for duplicate report (409 Conflict)
      if (e.toString().contains('duplicate') ||
          e.toString().contains('Conflict') ||
          e.toString().contains('già segnalato')) {
        state = const AsyncValue.data(null);
        return ReportSubmissionResult.duplicate;
      }
      state = AsyncValue.error(e, StackTrace.current);
      return ReportSubmissionResult.error;
    }
  }
}

/// Report submission result
enum ReportSubmissionResult {
  success,
  duplicate,
  validationError,
  error,
}

/// Provider for report submission state
final reportCommentNotifierProvider =
    StateNotifierProvider.autoDispose<ReportCommentNotifier, AsyncValue<void>>((ref) {
  final reportComment = ref.read(reportCommentProvider);
  return ReportCommentNotifier(reportComment);
});
