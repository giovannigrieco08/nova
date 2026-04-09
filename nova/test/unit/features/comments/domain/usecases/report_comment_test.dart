import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/comments/domain/usecases/report_comment.dart';
import 'package:nova/features/comments/domain/entities/comment_report.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late ReportComment useCase;
  late MockCommentsRepository mockRepository;

  setUpAll(() {
    registerFallbackValue(CommentReportReason.spam);
  });

  setUp(() {
    mockRepository = MockCommentsRepository();
    useCase = ReportComment(mockRepository);
  });

  group('call', () {
    test('happy: reports comment with reason and no details', () async {
      when(() => mockRepository.reportComment(
            commentId: 'comment-001',
            reason: CommentReportReason.inappropriate,
            details: null,
          )).thenAnswer((_) async => CommentReport(
            id: 'report-001',
            commentId: 'comment-001',
            reporterUserId: 'user-001',
            reason: CommentReportReason.inappropriate,
            createdAt: DateTime.now(),
          ));

      await useCase.call(
        commentId: 'comment-001',
        reason: CommentReportReason.inappropriate,
      );

      verify(() => mockRepository.reportComment(
            commentId: 'comment-001',
            reason: CommentReportReason.inappropriate,
            details: null,
          )).called(1);
    });

    test('happy: reports comment with reason and details', () async {
      when(() => mockRepository.reportComment(
            commentId: 'comment-001',
            reason: CommentReportReason.other,
            details: 'Contenuto offensivo',
          )).thenAnswer((_) async => CommentReport(
            id: 'report-002',
            commentId: 'comment-001',
            reporterUserId: 'user-001',
            reason: CommentReportReason.other,
            details: 'Contenuto offensivo',
            createdAt: DateTime.now(),
          ));

      await useCase.call(
        commentId: 'comment-001',
        reason: CommentReportReason.other,
        details: 'Contenuto offensivo',
      );

      verify(() => mockRepository.reportComment(
            commentId: 'comment-001',
            reason: CommentReportReason.other,
            details: 'Contenuto offensivo',
          )).called(1);
    });

    test('happy: accepts details at exactly 500 characters', () async {
      final details = 'x' * 500;
      when(() => mockRepository.reportComment(
            commentId: any(named: 'commentId'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
          )).thenAnswer((_) async => CommentReport(
            id: 'report-003',
            commentId: 'comment-001',
            reporterUserId: 'user-001',
            reason: CommentReportReason.spam,
            details: details,
            createdAt: DateTime.now(),
          ));

      await useCase.call(
        commentId: 'comment-001',
        reason: CommentReportReason.spam,
        details: details,
      );

      verify(() => mockRepository.reportComment(
            commentId: 'comment-001',
            reason: CommentReportReason.spam,
            details: details,
          )).called(1);
    });

    test('edge: throws when details exceed 500 characters', () async {
      final longDetails = 'x' * 501;

      expect(
        () => useCase.call(
          commentId: 'comment-001',
          reason: CommentReportReason.spam,
          details: longDetails,
        ),
        throwsException,
      );
      verifyNever(() => mockRepository.reportComment(
            commentId: any(named: 'commentId'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
          ));
    });

    test('edge: throws when repository throws conflict (duplicate report)',
        () async {
      when(() => mockRepository.reportComment(
            commentId: any(named: 'commentId'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
          )).thenThrow(Exception('Already reported'));

      expect(
        () => useCase.call(
          commentId: 'comment-001',
          reason: CommentReportReason.bullying,
        ),
        throwsException,
      );
    });
  });
}
