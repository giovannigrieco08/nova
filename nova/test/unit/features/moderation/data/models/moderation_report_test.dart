import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/moderation/data/models/moderation_report.dart';
import 'package:nova/features/safety/data/models/report.dart';

void main() {
  group('ModerationReport', () {
    // ===================== HAPPY PATH =====================

    test('creates with all required fields', () {
      final report = ModerationReport(
        id: 'mr-001',
        reporterId: 'user-001',
        contentType: ReportableContentType.event,
        contentId: 'event-001',
        category: ReportCategory.spam,
        status: ReportStatus.pending,
        createdAt: DateTime(2025, 6, 1),
        hoursPending: 12.5,
        isUrgent: false,
        reporterName: 'Mario Rossi',
        reporterUsername: 'mario.rossi',
      );

      expect(report.id, 'mr-001');
      expect(report.reporterId, 'user-001');
      expect(report.contentType, ReportableContentType.event);
      expect(report.category, ReportCategory.spam);
      expect(report.hoursPending, 12.5);
      expect(report.isUrgent, false);
      expect(report.reporterName, 'Mario Rossi');
    });

    test('fromJson parses complete JSON with flat fields', () {
      final json = {
        'id': 'mr-001',
        'reporter_id': 'user-001',
        'content_type': 'comment',
        'content_id': 'comment-001',
        'category': 'bullying',
        'note': 'This is harassment',
        'status': 'pending',
        'created_at': '2025-06-01T10:00:00.000Z',
        'hours_pending': 24.5,
        'is_urgent': true,
        'reporter_name': 'Luigi Verdi',
        'reporter_username': 'luigi.verdi',
        'reported_user_id': 'user-002',
        'reported_user_name': 'Mario Rossi',
        'reported_user_username': 'mario.rossi',
        'reported_user_avatar_url': 'https://example.com/avatar.jpg',
      };

      final report = ModerationReport.fromJson(json);

      expect(report.contentType, ReportableContentType.comment);
      expect(report.category, ReportCategory.bullying);
      expect(report.note, 'This is harassment');
      expect(report.hoursPending, 24.5);
      expect(report.isUrgent, true);
      expect(report.reporterName, 'Luigi Verdi');
      expect(report.reportedUserId, 'user-002');
      expect(report.reportedUserName, 'Mario Rossi');
    });

    test('fromJson parses nested reporter object', () {
      final json = {
        'id': 'mr-001',
        'content_type': 'profile',
        'content_id': 'p1',
        'category': 'inappropriate',
        'status': 'pending',
        'created_at': '2025-06-01T00:00:00.000Z',
        'reporter': {
          'user_id': 'user-nested',
          'full_name': 'Nested Reporter',
          'username': 'nested.user',
        },
      };

      final report = ModerationReport.fromJson(json);

      expect(report.reporterId, 'user-nested');
      expect(report.reporterName, 'Nested Reporter');
      expect(report.reporterUsername, 'nested.user');
    });

    test('contentTypeDisplayName returns Italian labels', () {
      expect(
        ModerationReport(
          id: '1',
          reporterId: 'u1',
          contentType: ReportableContentType.event,
          contentId: 'c1',
          category: ReportCategory.spam,
          status: ReportStatus.pending,
          createdAt: DateTime(2025, 1, 1),
          hoursPending: 0,
          isUrgent: false,
        ).contentTypeDisplayName,
        'Evento',
      );

      expect(
        ModerationReport(
          id: '1',
          reporterId: 'u1',
          contentType: ReportableContentType.chatMessage,
          contentId: 'c1',
          category: ReportCategory.spam,
          status: ReportStatus.pending,
          createdAt: DateTime(2025, 1, 1),
          hoursPending: 0,
          isUrgent: false,
        ).contentTypeDisplayName,
        'Messaggio',
      );
    });

    test('reportedUserDisplayName returns name, username fallback, or default',
        () {
      final withName = ModerationReport(
        id: '1',
        reporterId: 'u1',
        contentType: ReportableContentType.profile,
        contentId: 'c1',
        category: ReportCategory.spam,
        status: ReportStatus.pending,
        createdAt: DateTime(2025, 1, 1),
        hoursPending: 0,
        isUrgent: false,
        reportedUserName: 'Mario Rossi',
      );
      expect(withName.reportedUserDisplayName, 'Mario Rossi');

      final withUsername = ModerationReport(
        id: '1',
        reporterId: 'u1',
        contentType: ReportableContentType.profile,
        contentId: 'c1',
        category: ReportCategory.spam,
        status: ReportStatus.pending,
        createdAt: DateTime(2025, 1, 1),
        hoursPending: 0,
        isUrgent: false,
        reportedUserUsername: 'mario.rossi',
      );
      expect(withUsername.reportedUserDisplayName, '@mario.rossi');

      final withNothing = ModerationReport(
        id: '1',
        reporterId: 'u1',
        contentType: ReportableContentType.profile,
        contentId: 'c1',
        category: ReportCategory.spam,
        status: ReportStatus.pending,
        createdAt: DateTime(2025, 1, 1),
        hoursPending: 0,
        isUrgent: false,
      );
      expect(withNothing.reportedUserDisplayName, 'Utente');
    });

    test('equality is based on id', () {
      final a = ModerationReport(
        id: 'mr-001',
        reporterId: 'u1',
        contentType: ReportableContentType.event,
        contentId: 'c1',
        category: ReportCategory.spam,
        status: ReportStatus.pending,
        createdAt: DateTime(2025, 1, 1),
        hoursPending: 0,
        isUrgent: false,
      );
      final b = ModerationReport(
        id: 'mr-001',
        reporterId: 'u2',
        contentType: ReportableContentType.comment,
        contentId: 'c2',
        category: ReportCategory.bullying,
        status: ReportStatus.reviewed,
        createdAt: DateTime(2025, 6, 1),
        hoursPending: 10,
        isUrgent: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    // ===================== EDGE CASES =====================

    test('fromJson defaults missing numeric/boolean fields', () {
      final json = {
        'id': 'mr-001',
        'reporter_id': 'u1',
        'content_type': 'event',
        'content_id': 'e1',
        'category': 'other',
        'status': 'pending',
        'created_at': '2025-06-01T00:00:00.000Z',
      };

      final report = ModerationReport.fromJson(json);

      expect(report.hoursPending, 0.0);
      expect(report.isUrgent, false);
      expect(report.reporterName, isNull);
      expect(report.reportedUserId, isNull);
    });

    test('reportedUserDisplayName returns Utente for empty strings', () {
      final report = ModerationReport(
        id: '1',
        reporterId: 'u1',
        contentType: ReportableContentType.profile,
        contentId: 'c1',
        category: ReportCategory.spam,
        status: ReportStatus.pending,
        createdAt: DateTime(2025, 1, 1),
        hoursPending: 0,
        isUrgent: false,
        reportedUserName: '',
        reportedUserUsername: '',
      );
      expect(report.reportedUserDisplayName, 'Utente');
    });
  });
}
