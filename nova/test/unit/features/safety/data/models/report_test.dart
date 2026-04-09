import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/safety/data/models/report.dart';

void main() {
  group('ReportCategory', () {
    test('fromString parses known values', () {
      expect(ReportCategory.fromString('spam'), ReportCategory.spam);
      expect(ReportCategory.fromString('offensive_content'),
          ReportCategory.offensiveContent);
      expect(ReportCategory.fromString('bullying'), ReportCategory.bullying);
      expect(ReportCategory.fromString('inappropriate'),
          ReportCategory.inappropriate);
      expect(ReportCategory.fromString('other'), ReportCategory.other);
    });

    test('fromString defaults to other for unknown value', () {
      expect(ReportCategory.fromString('nonexistent'), ReportCategory.other);
    });
  });

  group('ReportStatus', () {
    test('fromString parses known values', () {
      expect(ReportStatus.fromString('pending'), ReportStatus.pending);
      expect(ReportStatus.fromString('reviewed'), ReportStatus.reviewed);
      expect(ReportStatus.fromString('dismissed'), ReportStatus.dismissed);
      expect(
          ReportStatus.fromString('action_taken'), ReportStatus.actionTaken);
    });

    test('fromString defaults to pending for unknown value', () {
      expect(ReportStatus.fromString('unknown'), ReportStatus.pending);
    });
  });

  group('ReportableContentType', () {
    test('fromString parses known values', () {
      expect(ReportableContentType.fromString('event'),
          ReportableContentType.event);
      expect(ReportableContentType.fromString('comment'),
          ReportableContentType.comment);
      expect(ReportableContentType.fromString('chat_message'),
          ReportableContentType.chatMessage);
      expect(ReportableContentType.fromString('profile'),
          ReportableContentType.profile);
    });

    test('fromString defaults to event for unknown value', () {
      expect(
          ReportableContentType.fromString('unknown'), ReportableContentType.event);
    });
  });

  group('Report', () {
    final now = DateTime(2025, 6, 1, 10, 0);

    Report createReport({
      String id = 'report-001',
      String reporterId = 'user-001',
      ReportableContentType contentType = ReportableContentType.event,
      String contentId = 'event-001',
      ReportCategory category = ReportCategory.spam,
      String? note,
      ReportStatus status = ReportStatus.pending,
      DateTime? createdAt,
    }) {
      return Report(
        id: id,
        reporterId: reporterId,
        contentType: contentType,
        contentId: contentId,
        category: category,
        note: note,
        status: status,
        createdAt: createdAt ?? now,
      );
    }

    // ===================== HAPPY PATH =====================

    test('creates with required fields', () {
      final report = createReport();

      expect(report.id, 'report-001');
      expect(report.reporterId, 'user-001');
      expect(report.contentType, ReportableContentType.event);
      expect(report.contentId, 'event-001');
      expect(report.category, ReportCategory.spam);
      expect(report.status, ReportStatus.pending);
      expect(report.note, isNull);
      expect(report.reviewedBy, isNull);
      expect(report.reviewedAt, isNull);
    });

    test('fromJson parses complete report JSON', () {
      final json = {
        'id': 'r1',
        'reporter_id': 'u1',
        'content_type': 'comment',
        'content_id': 'c1',
        'category': 'bullying',
        'note': 'This is harassment',
        'status': 'action_taken',
        'reviewed_by': 'mod-001',
        'reviewed_at': '2025-06-02T12:00:00.000Z',
        'action_taken': 'User warned',
        'created_at': '2025-06-01T10:00:00.000Z',
      };

      final report = Report.fromJson(json);

      expect(report.contentType, ReportableContentType.comment);
      expect(report.category, ReportCategory.bullying);
      expect(report.note, 'This is harassment');
      expect(report.status, ReportStatus.actionTaken);
      expect(report.reviewedBy, 'mod-001');
      expect(report.reviewedAt, isNotNull);
      expect(report.actionTaken, 'User warned');
    });

    test('toJson produces insert-friendly JSON', () {
      final report = createReport(note: 'Some note');
      final json = report.toJson();

      expect(json['reporter_id'], 'user-001');
      expect(json['content_type'], 'event');
      expect(json['content_id'], 'event-001');
      expect(json['category'], 'spam');
      expect(json['note'], 'Some note');
      // Should not contain server-managed fields
      expect(json.containsKey('id'), false);
      expect(json.containsKey('status'), false);
      expect(json.containsKey('created_at'), false);
    });

    test('copyWith replaces specified fields', () {
      final report = createReport();
      final reviewed = report.copyWith(
        status: ReportStatus.reviewed,
        reviewedBy: 'mod-001',
        reviewedAt: DateTime(2025, 6, 2),
      );

      expect(reviewed.status, ReportStatus.reviewed);
      expect(reviewed.reviewedBy, 'mod-001');
      expect(reviewed.id, report.id);
      expect(reviewed.reporterId, report.reporterId);
    });

    test('equality is based on id', () {
      final a = createReport(id: 'r1');
      final b = createReport(id: 'r1', note: 'Different');
      final c = createReport(id: 'r2');

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });

    // ===================== EDGE CASES =====================

    test('toJson excludes null note', () {
      final report = createReport(note: null);
      final json = report.toJson();

      expect(json.containsKey('note'), false);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'r1',
        'reporter_id': 'u1',
        'content_type': 'event',
        'content_id': 'e1',
        'category': 'spam',
        'status': 'pending',
        'created_at': '2025-06-01T00:00:00.000Z',
      };

      final report = Report.fromJson(json);

      expect(report.note, isNull);
      expect(report.reviewedBy, isNull);
      expect(report.reviewedAt, isNull);
      expect(report.actionTaken, isNull);
    });

    test('enum displayName values are Italian', () {
      expect(ReportCategory.spam.displayName, 'Spam');
      expect(ReportCategory.bullying.displayName, 'Bullismo');
      expect(ReportStatus.pending.displayName, 'In attesa');
      expect(ReportStatus.actionTaken.displayName, 'Azione intrapresa');
    });
  });
}
