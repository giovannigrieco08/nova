import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/comments/domain/usecases/moderator_restore_comment.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late ModeratorRestoreComment useCase;
  late MockCommentsRepository mockRepository;

  setUp(() {
    mockRepository = MockCommentsRepository();
    useCase = ModeratorRestoreComment(mockRepository);
  });

  group('call', () {
    test('happy: restores hidden comment successfully', () async {
      when(() =>
              mockRepository.moderatorRestoreComment(commentId: 'comment-001'))
          .thenAnswer((_) async {});

      await useCase.call(commentId: 'comment-001');

      verify(() =>
              mockRepository.moderatorRestoreComment(commentId: 'comment-001'))
          .called(1);
    });

    test('happy: delegates directly to repository without extra logic',
        () async {
      when(() => mockRepository.moderatorRestoreComment(
              commentId: 'comment-hidden-001'))
          .thenAnswer((_) async {});

      await useCase.call(commentId: 'comment-hidden-001');

      verify(() => mockRepository.moderatorRestoreComment(
              commentId: 'comment-hidden-001'))
          .called(1);
    });

    test('edge: throws when repository throws unauthorized error', () async {
      when(() => mockRepository.moderatorRestoreComment(
              commentId: any(named: 'commentId')))
          .thenThrow(Exception('Not a moderator'));

      expect(
        () => useCase.call(commentId: 'comment-001'),
        throwsException,
      );
    });

    test('edge: throws when comment is not hidden', () async {
      when(() => mockRepository.moderatorRestoreComment(
              commentId: 'comment-001'))
          .thenThrow(Exception('Comment is not hidden'));

      expect(
        () => useCase.call(commentId: 'comment-001'),
        throwsException,
      );
    });
  });
}
