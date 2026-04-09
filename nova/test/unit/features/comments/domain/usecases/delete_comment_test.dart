import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/comments/domain/usecases/delete_comment.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late DeleteComment useCase;
  late MockCommentsRepository mockRepository;

  setUp(() {
    mockRepository = MockCommentsRepository();
    useCase = DeleteComment(mockRepository);
  });

  group('call', () {
    test('happy: deletes comment successfully', () async {
      when(() => mockRepository.deleteComment(commentId: 'comment-001'))
          .thenAnswer((_) async {});

      await useCase.call(commentId: 'comment-001');

      verify(() => mockRepository.deleteComment(commentId: 'comment-001'))
          .called(1);
    });

    test('happy: delegates to repository without additional logic', () async {
      when(() => mockRepository.deleteComment(commentId: 'comment-002'))
          .thenAnswer((_) async {});

      await useCase.call(commentId: 'comment-002');

      verify(() => mockRepository.deleteComment(commentId: 'comment-002'))
          .called(1);
    });

    test('edge: throws when repository throws NotFoundException', () async {
      when(() => mockRepository.deleteComment(
              commentId: any(named: 'commentId')))
          .thenThrow(Exception('Comment not found'));

      expect(
        () => useCase.call(commentId: 'nonexistent'),
        throwsException,
      );
    });

    test('edge: throws when repository throws UnauthorizedException',
        () async {
      when(() => mockRepository.deleteComment(commentId: 'comment-001'))
          .thenThrow(Exception('Not authorized'));

      expect(
        () => useCase.call(commentId: 'comment-001'),
        throwsException,
      );
    });
  });
}
