import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/comments/domain/usecases/reply_to_comment.dart';
import '../../../../../fixtures/comment_fixtures.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late ReplyToComment useCase;
  late MockCommentsRepository mockRepository;

  setUp(() {
    mockRepository = MockCommentsRepository();
    useCase = ReplyToComment(mockRepository);
  });

  group('call', () {
    test('happy: creates reply to a top-level comment', () async {
      final expected = TestComments.reply(parentCommentId: 'comment-001');
      when(() => mockRepository.replyToComment(
            commentId: 'comment-001',
            text: 'Concordo!',
          )).thenAnswer((_) async => expected);

      final result = await useCase.call(
        parentCommentId: 'comment-001',
        text: 'Concordo!',
      );

      expect(result.parentCommentId, 'comment-001');
      verify(() => mockRepository.replyToComment(
            commentId: 'comment-001',
            text: 'Concordo!',
          )).called(1);
    });

    test('happy: passes parentCommentId as commentId to repository',
        () async {
      final expected = TestComments.reply(parentCommentId: 'parent-123');
      when(() => mockRepository.replyToComment(
            commentId: 'parent-123',
            text: 'Nice!',
          )).thenAnswer((_) async => expected);

      await useCase.call(
        parentCommentId: 'parent-123',
        text: 'Nice!',
      );

      verify(() => mockRepository.replyToComment(
            commentId: 'parent-123',
            text: 'Nice!',
          )).called(1);
    });

    test('happy: returns the created reply comment entity', () async {
      final expected = TestComments.reply();
      when(() => mockRepository.replyToComment(
            commentId: any(named: 'commentId'),
            text: any(named: 'text'),
          )).thenAnswer((_) async => expected);

      final result = await useCase.call(
        parentCommentId: 'comment-001',
        text: 'Reply text',
      );

      expect(result.isReply, true);
      expect(result.depth, 1);
    });

    test('edge: throws when repository rejects reply to a reply', () async {
      when(() => mockRepository.replyToComment(
            commentId: any(named: 'commentId'),
            text: any(named: 'text'),
          )).thenThrow(Exception('Cannot reply to a reply'));

      expect(
        () => useCase.call(
          parentCommentId: 'reply-001',
          text: 'Nested reply',
        ),
        throwsException,
      );
    });

    test('edge: throws when repository throws network error', () async {
      when(() => mockRepository.replyToComment(
            commentId: any(named: 'commentId'),
            text: any(named: 'text'),
          )).thenThrow(Exception('Network error'));

      expect(
        () => useCase.call(
          parentCommentId: 'comment-001',
          text: 'Reply',
        ),
        throwsException,
      );
    });
  });
}
