import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/comments/domain/usecases/like_comment.dart';
import '../../../../../fixtures/comment_fixtures.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late LikeComment useCase;
  late MockCommentsRepository mockRepository;

  setUp(() {
    mockRepository = MockCommentsRepository();
    useCase = LikeComment(mockRepository);
  });

  group('call', () {
    test('happy: likes comment and returns updated comment', () async {
      final expected = TestComments.topLevel().copyWith(
        likeCount: 6,
        isLikedByCurrentUser: true,
      );
      when(() => mockRepository.likeComment(commentId: 'comment-001'))
          .thenAnswer((_) async => expected);

      final result = await useCase.call(commentId: 'comment-001');

      expect(result.likeCount, 6);
      expect(result.isLikedByCurrentUser, true);
      verify(() => mockRepository.likeComment(commentId: 'comment-001'))
          .called(1);
    });

    test('happy: idempotent - returns existing like without error', () async {
      final alreadyLiked = TestComments.topLevel().copyWith(
        likeCount: 5,
        isLikedByCurrentUser: true,
      );
      when(() => mockRepository.likeComment(commentId: 'comment-001'))
          .thenAnswer((_) async => alreadyLiked);

      final result = await useCase.call(commentId: 'comment-001');

      expect(result.isLikedByCurrentUser, true);
    });

    test('edge: throws when repository throws rate limit error', () async {
      when(() => mockRepository.likeComment(
              commentId: any(named: 'commentId')))
          .thenThrow(Exception('Rate limit exceeded'));

      expect(
        () => useCase.call(commentId: 'comment-001'),
        throwsException,
      );
    });

    test('edge: throws when repository throws network error', () async {
      when(() => mockRepository.likeComment(commentId: 'comment-001'))
          .thenThrow(Exception('Network error'));

      expect(
        () => useCase.call(commentId: 'comment-001'),
        throwsException,
      );
    });
  });
}
