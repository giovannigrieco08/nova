import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/features/safety/data/models/report.dart';
import 'package:nova/features/safety/data/repositories/report_repository.dart';
import '../../../../../mocks/mock_supabase.dart';

void main() {
  late ReportRepository repository;
  late MockSupabaseClient mockSupabase;
  late MockGoTrueClient mockAuth;
  late MockUser mockUser;

  setUp(() {
    mockSupabase = MockSupabaseClient();
    mockAuth = MockGoTrueClient();
    mockUser = MockUser();

    when(() => mockSupabase.auth).thenAnswer((_) => mockAuth);
    when(() => mockAuth.currentUser).thenAnswer((_) => mockUser);
    when(() => mockUser.id).thenReturn('user-001');

    repository = ReportRepository(supabase: mockSupabase);
  });

  group('createReport', () {
    test('creates report and returns Report model', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery({
        'id': 'report-001',
        'reporter_id': 'user-001',
        'content_type': 'event',
        'content_id': 'event-001',
        'category': 'spam',
        'note': 'This is spam',
        'status': 'pending',
        'reviewed_by': null,
        'reviewed_at': null,
        'action_taken': null,
        'created_at': '2025-06-01T00:00:00.000',
      });
      when(() => mockSupabase.from('reports')).thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      final result = await repository.createReport(
        contentType: ReportableContentType.event,
        contentId: 'event-001',
        category: ReportCategory.spam,
        note: 'This is spam',
      );

      expect(result.id, 'report-001');
      expect(result.category, ReportCategory.spam);
      expect(result.status, ReportStatus.pending);
    });

    test('sanitizes HTML from note', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockSingleQuery({
        'id': 'report-001',
        'reporter_id': 'user-001',
        'content_type': 'event',
        'content_id': 'event-001',
        'category': 'spam',
        'note': 'Clean text',
        'status': 'pending',
        'created_at': '2025-06-01T00:00:00.000',
      });
      when(() => mockSupabase.from('reports')).thenAnswer((_) => mockQb);
      when(() => mockQb.insert(any())).thenAnswer((_) => fb);

      await repository.createReport(
        contentType: ReportableContentType.event,
        contentId: 'event-001',
        category: ReportCategory.spam,
        note: '<script>alert("xss")</script>Clean text',
      );

      verify(() => mockQb.insert(any())).called(1);
    });

    test('throws when note exceeds 500 characters', () async {
      expect(
        () => repository.createReport(
          contentType: ReportableContentType.event,
          contentId: 'event-001',
          category: ReportCategory.spam,
          note: 'x' * 501,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws when not authenticated', () async {
      when(() => mockAuth.currentUser).thenAnswer((_) => null);

      expect(
        () => repository.createReport(
          contentType: ReportableContentType.event,
          contentId: 'event-001',
          category: ReportCategory.spam,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('hasUserReported', () {
    test('returns true when user has reported content', () async {
      when(() => mockSupabase.rpc('has_user_reported', params: {
            'p_content_type': 'event',
            'p_content_id': 'event-001',
          })).thenAnswer((_) => mockFilterChain<dynamic>(true));

      final result = await repository.hasUserReported(
        contentType: ReportableContentType.event,
        contentId: 'event-001',
      );

      expect(result, true);
    });

    test('returns false when RPC returns null', () async {
      when(() => mockSupabase.rpc('has_user_reported', params: {
            'p_content_type': 'event',
            'p_content_id': 'event-001',
          })).thenAnswer((_) => mockFilterChain<dynamic>(null));

      final result = await repository.hasUserReported(
        contentType: ReportableContentType.event,
        contentId: 'event-001',
      );

      expect(result, false);
    });
  });

  group('getReportById', () {
    test('returns Report when found', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery([{
        'id': 'report-001',
        'reporter_id': 'user-001',
        'content_type': 'event',
        'content_id': 'event-001',
        'category': 'spam',
        'status': 'pending',
        'created_at': '2025-06-01T00:00:00.000',
      }]);
      when(() => mockSupabase.from('reports')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await repository.getReportById('report-001');

      expect(result, isNotNull);
      expect(result!.id, 'report-001');
    });

    test('returns null when not found', () async {
      final mockQb = MockSupabaseQueryBuilder();
      final fb = mockListQuery(<Map<String, dynamic>>[]);
      when(() => mockSupabase.from('reports')).thenAnswer((_) => mockQb);
      when(() => mockQb.select(any())).thenAnswer((_) => fb);

      final result = await repository.getReportById('missing');

      expect(result, isNull);
    });
  });
}
