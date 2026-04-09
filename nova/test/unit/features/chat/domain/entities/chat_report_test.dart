import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/chat/domain/entities/chat_report.dart';

void main() {
  group('ChatReport', () {
    // =========================================================
    // HAPPY PATH TESTS (H:2)
    // =========================================================

    test('creates report with required fields and correct defaults', () {
      final now = DateTime(2025, 6, 15, 10, 0);
      final report = ChatReport(
        id: 'report-001',
        messageId: 'msg-001',
        reporterUserId: 'user-001',
        reason: ChatReportReason.bullying,
        status: ChatReportStatus.pending,
        createdAt: now,
      );

      expect(report.id, 'report-001');
      expect(report.messageId, 'msg-001');
      expect(report.reporterUserId, 'user-001');
      expect(report.reason, ChatReportReason.bullying);
      expect(report.status, ChatReportStatus.pending);
      expect(report.createdAt, now);
      expect(report.reviewedByModeratorId, isNull);
      expect(report.reviewedAt, isNull);
      expect(report.moderatorNotes, isNull);
    });

    test('isReviewed returns true for non-pending status', () {
      final reviewed = ChatReport(
        id: 'report-002',
        messageId: 'msg-001',
        reporterUserId: 'user-001',
        reason: ChatReportReason.spam,
        status: ChatReportStatus.reviewed,
        reviewedByModeratorId: 'mod-001',
        reviewedAt: DateTime.now(),
        moderatorNotes: 'Confermato spam',
        createdAt: DateTime.now(),
      );

      expect(reviewed.isReviewed, isTrue);

      final dismissed = ChatReport(
        id: 'report-003',
        messageId: 'msg-001',
        reporterUserId: 'user-002',
        reason: ChatReportReason.inappropriate,
        status: ChatReportStatus.dismissed,
        createdAt: DateTime.now(),
      );

      expect(dismissed.isReviewed, isTrue);
    });

    // =========================================================
    // EDGE CASE TESTS (E:2)
    // =========================================================

    test('isReviewed returns false for pending status', () {
      final pending = ChatReport(
        id: 'report-004',
        messageId: 'msg-001',
        reporterUserId: 'user-001',
        reason: ChatReportReason.offTopic,
        status: ChatReportStatus.pending,
        createdAt: DateTime.now(),
      );

      expect(pending.isReviewed, isFalse);
    });

    test('equality is based on id only', () {
      final r1 = ChatReport(
        id: 'same-id',
        messageId: 'msg-001',
        reporterUserId: 'user-001',
        reason: ChatReportReason.spam,
        status: ChatReportStatus.pending,
        createdAt: DateTime(2025, 1, 1),
      );
      final r2 = ChatReport(
        id: 'same-id',
        messageId: 'msg-002', // different
        reporterUserId: 'user-002', // different
        reason: ChatReportReason.bullying, // different
        status: ChatReportStatus.reviewed, // different
        createdAt: DateTime(2025, 6, 1),
      );

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));

      final r3 = ChatReport(
        id: 'different-id',
        messageId: 'msg-001',
        reporterUserId: 'user-001',
        reason: ChatReportReason.spam,
        status: ChatReportStatus.pending,
        createdAt: DateTime.now(),
      );
      expect(r1, isNot(equals(r3)));
    });
  });

  group('ChatReportReason', () {
    test('fromValue returns correct enum for valid values', () {
      expect(ChatReportReason.fromValue('spam'), ChatReportReason.spam);
      expect(ChatReportReason.fromValue('inappropriate'),
          ChatReportReason.inappropriate);
      expect(ChatReportReason.fromValue('bullying'), ChatReportReason.bullying);
      expect(ChatReportReason.fromValue('off_topic'), ChatReportReason.offTopic);
    });

    test('fromValue defaults to inappropriate for unknown values', () {
      expect(ChatReportReason.fromValue('unknown'),
          ChatReportReason.inappropriate);
    });

    test('label returns Italian labels', () {
      expect(ChatReportReason.spam.label, 'Spam');
      expect(ChatReportReason.inappropriate.label, 'Contenuto inappropriato');
      expect(ChatReportReason.bullying.label, 'Bullismo');
      expect(ChatReportReason.offTopic.label, 'Off-topic');
    });
  });

  group('ChatReportStatus', () {
    test('fromValue returns correct enum for valid values', () {
      expect(ChatReportStatus.fromValue('pending'), ChatReportStatus.pending);
      expect(ChatReportStatus.fromValue('reviewed'), ChatReportStatus.reviewed);
      expect(
          ChatReportStatus.fromValue('dismissed'), ChatReportStatus.dismissed);
    });

    test('fromValue defaults to pending for unknown values', () {
      expect(ChatReportStatus.fromValue('unknown'), ChatReportStatus.pending);
    });
  });
}
