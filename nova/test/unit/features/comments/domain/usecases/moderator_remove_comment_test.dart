import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/comments/domain/usecases/moderator_remove_comment.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late ModeratorRemoveComment useCase;
  late MockCommentsRepository mockRepository;

  setUp(() {
    mockRepository = MockCommentsRepository();
    useCase = ModeratorRemoveComment(mockRepository);
  });

  group('call', () {
    test('happy: removes comment with valid reason', () async {
      when(() => mockRepository.moderatorRemoveComment(
            commentId: 'comment-001',
            reason: 'Linguaggio inappropriato',
          )).thenAnswer((_) async {});

      await useCase.call(
        commentId: 'comment-001',
        reason: 'Linguaggio inappropriato',
      );

      verify(() => mockRepository.moderatorRemoveComment(
            commentId: 'comment-001',
            reason: 'Linguaggio inappropriato',
          )).called(1);
    });

    test('happy: accepts reason at exactly 500 characters', () async {
      final reason = 'r' * 500;
      when(() => mockRepository.moderatorRemoveComment(
            commentId: 'comment-001',
            reason: reason,
          )).thenAnswer((_) async {});

      await useCase.call(commentId: 'comment-001', reason: reason);

      verify(() => mockRepository.moderatorRemoveComment(
            commentId: 'comment-001',
            reason: reason,
          )).called(1);
    });

    test('happy: propagates repository exceptions to caller', () async {
      when(() => mockRepository.moderatorRemoveComment(
            commentId: any(named: 'commentId'),
            reason: any(named: 'reason'),
          )).thenThrow(Exception('Not a moderator'));

      expect(
        () => useCase.call(
          commentId: 'comment-001',
          reason: 'Violation',
        ),
        throwsException,
      );
    });

    test('edge: throws ValidationException for empty reason', () async {
      expect(
        () => useCase.call(commentId: 'comment-001', reason: ''),
        throwsA(isA<ValidationException>()),
      );
      verifyNever(() => mockRepository.moderatorRemoveComment(
            commentId: any(named: 'commentId'),
            reason: any(named: 'reason'),
          ));
    });

    test('edge: throws ValidationException for whitespace-only reason',
        () async {
      expect(
        () => useCase.call(commentId: 'comment-001', reason: '   '),
        throwsA(isA<ValidationException>()),
      );
    });

    test('edge: throws ValidationException for reason exceeding 500 chars',
        () async {
      final longReason = 'r' * 501;
      expect(
        () => useCase.call(commentId: 'comment-001', reason: longReason),
        throwsA(isA<ValidationException>()),
      );
      verifyNever(() => mockRepository.moderatorRemoveComment(
            commentId: any(named: 'commentId'),
            reason: any(named: 'reason'),
          ));
    });
  });
}
