import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/comments/domain/usecases/unlike_comment.dart';
import '../../../../../fixtures/comment_fixtures.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late UnlikeComment useCase;
  late MockCommentsRepository mockRepository;

  setUp(() {
    mockRepository = MockCommentsRepository();
    useCase = UnlikeComment(mockRepository);
  });

  group('call', () {
    test('happy: unlikes comment and returns updated comment', () async {
      final expected = TestComments.topLevel().copyWith(
        likeCount: 4,
        isLikedByCurrentUser: false,
      );
      when(() => mockRepository.unlikeComment(commentId: 'comment-001'))
          .thenAnswer((_) async => expected);

      final result = await useCase.call(commentId: 'comment-001');

      expect(result.likeCount, 4);
      expect(result.isLikedByCurrentUser, false);
      verify(() => mockRepository.unlikeComment(commentId: 'comment-001'))
          .called(1);
    });

    test('happy: idempotent - returns comment unchanged if not liked',
        () async {
      final notLiked = TestComments.topLevel().copyWith(
        likeCount: 5,
        isLikedByCurrentUser: false,
      );
      when(() => mockRepository.unlikeComment(commentId: 'comment-001'))
          .thenAnswer((_) async => notLiked);

      final result = await useCase.call(commentId: 'comment-001');

      expect(result.isLikedByCurrentUser, false);
      expect(result.likeCount, 5);
    });

    test('edge: throws when repository throws network error', () async {
      when(() => mockRepository.unlikeComment(
              commentId: any(named: 'commentId')))
          .thenThrow(Exception('Network error'));

      expect(
        () => useCase.call(commentId: 'comment-001'),
        throwsException,
      );
    });

    test('edge: throws when comment does not exist', () async {
      when(() => mockRepository.unlikeComment(commentId: 'nonexistent'))
          .thenThrow(Exception('Comment not found'));

      expect(
        () => useCase.call(commentId: 'nonexistent'),
        throwsException,
      );
    });
  });
}
