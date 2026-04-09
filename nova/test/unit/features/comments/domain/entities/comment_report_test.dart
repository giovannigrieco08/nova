import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/comments/domain/entities/comment_report.dart';

void main() {
  group('CommentReport Entity', () {
    final now = DateTime(2025, 6, 1, 12, 0);

    CommentReport createReport({
      String id = 'report-001',
      String commentId = 'comment-001',
      String reporterUserId = 'user-001',
      CommentReportReason reason = CommentReportReason.spam,
      String? details,
      CommentReportStatus status = CommentReportStatus.pending,
      String? reviewedByModeratorId,
      DateTime? reviewedAt,
      String? moderatorNotes,
      DateTime? createdAt,
    }) {
      return CommentReport(
        id: id,
        commentId: commentId,
        reporterUserId: reporterUserId,
        reason: reason,
        details: details,
        status: status,
        reviewedByModeratorId: reviewedByModeratorId,
        reviewedAt: reviewedAt,
        moderatorNotes: moderatorNotes,
        createdAt: createdAt ?? now,
      );
    }

    // ========================================================================
    // HAPPY PATH
    // ========================================================================

    group('creation and computed properties', () {
      test('creates report with required fields and defaults', () {
        final report = createReport();

        expect(report.id, 'report-001');
        expect(report.commentId, 'comment-001');
        expect(report.reporterUserId, 'user-001');
        expect(report.reason, CommentReportReason.spam);
        expect(report.status, CommentReportStatus.pending);
        expect(report.details, isNull);
        expect(report.isPending, isTrue);
        expect(report.isReviewed, isFalse);
        expect(report.isDismissed, isFalse);
      });

      test('isPending/isReviewed/isDismissed reflect correct status', () {
        final reviewed = createReport(status: CommentReportStatus.reviewed);
        expect(reviewed.isPending, isFalse);
        expect(reviewed.isReviewed, isTrue);
        expect(reviewed.isDismissed, isFalse);

        final dismissed = createReport(status: CommentReportStatus.dismissed);
        expect(dismissed.isPending, isFalse);
        expect(dismissed.isReviewed, isFalse);
        expect(dismissed.isDismissed, isTrue);
      });

      test('displayReason and displayStatus return localized strings', () {
        final report = createReport(
          reason: CommentReportReason.bullying,
          status: CommentReportStatus.reviewed,
        );

        expect(report.displayReason, 'Bullismo/molestie');
        expect(report.displayStatus, 'Revisionato');
      });

      test('isReportedBy returns correct result', () {
        final report = createReport(reporterUserId: 'user-abc');
        expect(report.isReportedBy('user-abc'), isTrue);
        expect(report.isReportedBy('user-xyz'), isFalse);
      });
    });

    group('copyWith and equality', () {
      test('copyWith returns new instance with updated fields', () {
        final report = createReport();
        final updated = report.copyWith(
          status: CommentReportStatus.reviewed,
          reviewedByModeratorId: 'mod-001',
          moderatorNotes: 'Reviewed and confirmed',
        );

        expect(updated.status, CommentReportStatus.reviewed);
        expect(updated.reviewedByModeratorId, 'mod-001');
        expect(updated.moderatorNotes, 'Reviewed and confirmed');
        expect(updated.id, report.id); // unchanged
      });

      test('equality is based on id only', () {
        final a = createReport(id: 'same-id');
        final b = createReport(
          id: 'same-id',
          reason: CommentReportReason.inappropriate,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different ids are not equal', () {
        final a = createReport(id: 'id-1');
        final b = createReport(id: 'id-2');
        expect(a, isNot(equals(b)));
      });
    });

    // ========================================================================
    // EDGE CASES
    // ========================================================================

    group('edge cases', () {
      test('CommentReportReason.fromValue returns correct enum', () {
        expect(CommentReportReason.fromValue('spam'), CommentReportReason.spam);
        expect(
          CommentReportReason.fromValue('inappropriate'),
          CommentReportReason.inappropriate,
        );
        expect(
          CommentReportReason.fromValue('bullying'),
          CommentReportReason.bullying,
        );
        expect(
          CommentReportReason.fromValue('off_topic'),
          CommentReportReason.offTopic,
        );
        expect(
          CommentReportReason.fromValue('other'),
          CommentReportReason.other,
        );
      });

      test('CommentReportReason.fromValue defaults to other for unknown', () {
        expect(
          CommentReportReason.fromValue('unknown_reason'),
          CommentReportReason.other,
        );
        expect(
          CommentReportReason.fromValue(''),
          CommentReportReason.other,
        );
      });

      test('CommentReportStatus.fromValue returns correct enum', () {
        expect(
          CommentReportStatus.fromValue('pending'),
          CommentReportStatus.pending,
        );
        expect(
          CommentReportStatus.fromValue('reviewed'),
          CommentReportStatus.reviewed,
        );
        expect(
          CommentReportStatus.fromValue('dismissed'),
          CommentReportStatus.dismissed,
        );
      });

      test('CommentReportStatus.fromValue defaults to pending for unknown', () {
        expect(
          CommentReportStatus.fromValue('invalid_status'),
          CommentReportStatus.pending,
        );
      });

      test('toString contains key fields', () {
        final report = createReport(
          reason: CommentReportReason.bullying,
          status: CommentReportStatus.pending,
        );
        final str = report.toString();

        expect(str, contains('report-001'));
        expect(str, contains('comment-001'));
        expect(str, contains('Bullismo/molestie'));
        expect(str, contains('In attesa'));
      });

      test('report with all optional fields populated', () {
        final report = createReport(
          details: 'Dettagli aggiuntivi',
          status: CommentReportStatus.reviewed,
          reviewedByModeratorId: 'mod-001',
          reviewedAt: now,
          moderatorNotes: 'Note moderatore',
        );

        expect(report.details, 'Dettagli aggiuntivi');
        expect(report.reviewedByModeratorId, 'mod-001');
        expect(report.reviewedAt, now);
        expect(report.moderatorNotes, 'Note moderatore');
      });
    });
  });
}
