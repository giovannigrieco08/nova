import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/data/models/report_model.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 0);

  group('ReportModel', () {
    // =====================================================================
    // Happy Path Tests (H:3)
    // =====================================================================

    test('should create ReportModel with required fields and defaults', () {
      final report = ReportModel(
        id: 'report-001',
        eventId: 'event-001',
        reporterId: 'user-001',
        reason: 'spam',
        explanation: 'This event is clearly spam content.',
        createdAt: now,
      );

      expect(report.id, 'report-001');
      expect(report.eventId, 'event-001');
      expect(report.reporterId, 'user-001');
      expect(report.reason, 'spam');
      expect(report.explanation, 'This event is clearly spam content.');
      expect(report.reviewed, isFalse);
    });

    test('reasonText returns user-friendly labels for known reasons', () {
      final spam = ReportModel(
        id: 'r1', eventId: 'e1', reporterId: 'u1',
        reason: 'spam', explanation: 'x', createdAt: now,
      );
      final inappropriate = spam.copyWith(reason: 'inappropriate');
      final harassment = spam.copyWith(reason: 'harassment');
      final other = spam.copyWith(reason: 'other');

      expect(spam.reasonText, 'Spam');
      expect(inappropriate.reasonText, 'Inappropriate Content');
      expect(harassment.reasonText, 'Harassment');
      expect(other.reasonText, 'Other');
    });

    test('isValidReason validates allowed reason strings', () {
      expect(ReportModel.isValidReason('inappropriate'), isTrue);
      expect(ReportModel.isValidReason('spam'), isTrue);
      expect(ReportModel.isValidReason('harassment'), isTrue);
      expect(ReportModel.isValidReason('other'), isTrue);
    });

    // =====================================================================
    // Edge Case Tests (E:3)
    // =====================================================================

    test('isValidReason returns false for unknown reasons', () {
      expect(ReportModel.isValidReason('unknown'), isFalse);
      expect(ReportModel.isValidReason(''), isFalse);
      expect(ReportModel.isValidReason('SPAM'), isFalse); // case-sensitive
    });

    test('reasonText returns raw reason for unknown values', () {
      final report = ReportModel(
        id: 'r1', eventId: 'e1', reporterId: 'u1',
        reason: 'custom_reason', explanation: 'x', createdAt: now,
      );

      expect(report.reasonText, 'custom_reason');
    });

    test('equality is based on id only', () {
      final report1 = ReportModel(
        id: 'report-001', eventId: 'e1', reporterId: 'u1',
        reason: 'spam', explanation: 'x', createdAt: now,
      );
      final report2 = ReportModel(
        id: 'report-001', eventId: 'e2', reporterId: 'u2',
        reason: 'harassment', explanation: 'y', createdAt: now,
      );

      expect(report1, equals(report2));
      expect(report1.hashCode, report2.hashCode);
    });
  });
}
