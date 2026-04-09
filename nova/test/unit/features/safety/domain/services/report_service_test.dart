import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/safety/domain/services/report_service.dart';
import 'package:nova/features/safety/data/repositories/report_repository.dart';
import 'package:nova/features/safety/data/models/report.dart';

class MockReportRepository extends Mock implements ReportRepository {}

void main() {
  late ReportService service;
  late MockReportRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(ReportableContentType.event);
    registerFallbackValue(ReportCategory.spam);
  });

  setUp(() {
    mockRepository = MockReportRepository();
    service = ReportService(repository: mockRepository);
  });

  final testReport = Report(
    id: 'report-001',
    reporterId: 'user-001',
    contentType: ReportableContentType.event,
    contentId: 'event-001',
    category: ReportCategory.offensiveContent,
    status: ReportStatus.pending,
    createdAt: DateTime(2025, 6, 1),
  );

  group('ReportService', () {
    // ===== HAPPY PATH TESTS =====

    test('submitReport creates report when not already reported', () async {
      when(() => mockRepository.hasUserReported(
            contentType: any(named: 'contentType'),
            contentId: any(named: 'contentId'),
          )).thenAnswer((_) async => false);

      when(() => mockRepository.createReport(
            contentType: any(named: 'contentType'),
            contentId: any(named: 'contentId'),
            category: any(named: 'category'),
            note: any(named: 'note'),
          )).thenAnswer((_) async => testReport);

      final result = await service.submitReport(
        contentType: ReportableContentType.event,
        contentId: 'event-001',
        category: ReportCategory.offensiveContent,
        note: 'Contenuto offensivo',
      );

      expect(result, equals(testReport));
      verify(() => mockRepository.hasUserReported(
            contentType: ReportableContentType.event,
            contentId: 'event-001',
          )).called(1);
      verify(() => mockRepository.createReport(
            contentType: ReportableContentType.event,
            contentId: 'event-001',
            category: ReportCategory.offensiveContent,
            note: 'Contenuto offensivo',
          )).called(1);
    });

    test('canReport returns true when content not yet reported', () async {
      when(() => mockRepository.hasUserReported(
            contentType: any(named: 'contentType'),
            contentId: any(named: 'contentId'),
          )).thenAnswer((_) async => false);

      final result = await service.canReport(
        contentType: ReportableContentType.event,
        contentId: 'event-001',
      );

      expect(result, isTrue);
    });

    test('getMyReports returns list of user reports', () async {
      when(() => mockRepository.getUserReports(
            limit: any(named: 'limit'),
            offset: any(named: 'offset'),
          )).thenAnswer((_) async => [testReport]);

      final result = await service.getMyReports();

      expect(result, hasLength(1));
      expect(result.first, equals(testReport));
    });

    // ===== EDGE CASE / ERROR TESTS =====

    test('submitReport throws ArgumentError for empty contentId', () async {
      expect(
        () => service.submitReport(
          contentType: ReportableContentType.event,
          contentId: '',
          category: ReportCategory.spam,
        ),
        throwsA(isA<ArgumentError>()),
      );

      verifyNever(() => mockRepository.hasUserReported(
            contentType: any(named: 'contentType'),
            contentId: any(named: 'contentId'),
          ));
    });

    test('submitReport throws ReportAlreadyExistsException if already reported',
        () async {
      when(() => mockRepository.hasUserReported(
            contentType: any(named: 'contentType'),
            contentId: any(named: 'contentId'),
          )).thenAnswer((_) async => true);

      expect(
        () => service.submitReport(
          contentType: ReportableContentType.event,
          contentId: 'event-001',
          category: ReportCategory.spam,
        ),
        throwsA(isA<ReportAlreadyExistsException>()),
      );

      verifyNever(() => mockRepository.createReport(
            contentType: any(named: 'contentType'),
            contentId: any(named: 'contentId'),
            category: any(named: 'category'),
            note: any(named: 'note'),
          ));
    });
  });
}
