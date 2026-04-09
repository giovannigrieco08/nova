import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/comments/domain/usecases/get_replies_for_comment.dart';
import 'package:nova/features/comments/domain/entities/comment.dart';
import '../../../../../fixtures/comment_fixtures.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late GetRepliesForComment useCase;
  late MockCommentsRepository mockRepository;

  setUp(() {
    mockRepository = MockCommentsRepository();
    useCase = GetRepliesForComment(mockRepository);
  });

  group('call', () {
    test('happy: returns list of replies for a comment', () async {
      final replies = [
        TestComments.reply(parentCommentId: 'comment-001'),
      ];
      when(() =>
              mockRepository.getRepliesForComment(commentId: 'comment-001'))
          .thenAnswer((_) async => replies);

      final result = await useCase.call(commentId: 'comment-001');

      expect(result.length, 1);
      expect(result.first.parentCommentId, 'comment-001');
      verify(() =>
              mockRepository.getRepliesForComment(commentId: 'comment-001'))
          .called(1);
    });

    test('happy: returns empty list when no replies exist', () async {
      when(() =>
              mockRepository.getRepliesForComment(commentId: 'comment-001'))
          .thenAnswer((_) async => <Comment>[]);

      final result = await useCase.call(commentId: 'comment-001');

      expect(result, isEmpty);
    });

    test('edge: throws when repository throws network error', () async {
      when(() => mockRepository.getRepliesForComment(
              commentId: any(named: 'commentId')))
          .thenThrow(Exception('Network error'));

      expect(
        () => useCase.call(commentId: 'comment-001'),
        throwsException,
      );
    });

    test('edge: throws when parent comment does not exist', () async {
      when(() =>
              mockRepository.getRepliesForComment(commentId: 'nonexistent'))
          .thenThrow(Exception('Comment not found'));

      expect(
        () => useCase.call(commentId: 'nonexistent'),
        throwsException,
      );
    });
  });
}
