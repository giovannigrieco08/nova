import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/comments/domain/usecases/send_reply_notification.dart';
import '../../../../../fixtures/comment_fixtures.dart';
import '../../../../../mocks/mock_repositories.dart';

void main() {
  late SendReplyNotification useCase;
  late MockCommentsRepository mockRepository;

  setUp(() {
    mockRepository = MockCommentsRepository();
    useCase = SendReplyNotification();
  });

  group('call', () {
    test('happy: completes without error for valid reply and parent comment',
        () async {
      final reply = TestComments.reply(parentCommentId: 'comment-001');
      final parent = TestComments.topLevel(id: 'comment-001');

      // Current implementation is a no-op (server-side trigger handles it)
      await useCase.call(reply: reply, parentComment: parent);

      // Should complete without throwing
    });

    test('happy: does not call repository (server-side trigger handles it)',
        () async {
      final reply = TestComments.reply();
      final parent = TestComments.topLevel();

      await useCase.call(reply: reply, parentComment: parent);

      // No repository calls expected - notification is handled by DB trigger
      verifyNoMoreInteractions(mockRepository);
    });

    test('happy: accepts any valid comment entities', () async {
      final reply = TestComments.reply(parentCommentId: 'mod-comment');
      final parent = TestComments.moderatorComment();

      await useCase.call(reply: reply, parentComment: parent);

      // No-op implementation should not throw
    });

    test('edge: handles deleted parent comment without error', () async {
      final reply = TestComments.reply();
      final deletedParent = TestComments.deleted();

      // Should still complete - server trigger handles edge cases
      await useCase.call(reply: reply, parentComment: deletedParent);
    });

    test('edge: handles hidden parent comment without error', () async {
      final reply = TestComments.reply();
      final hiddenParent = TestComments.hidden();

      await useCase.call(reply: reply, parentComment: hiddenParent);
    });
  });
}
