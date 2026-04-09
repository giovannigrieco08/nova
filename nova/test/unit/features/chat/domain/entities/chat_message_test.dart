import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/chat/domain/entities/mention_info.dart';
import '../../../../../fixtures/profile_fixtures.dart';
import '../../../../../fixtures/chat_fixtures.dart';

void main() {
  group('ChatMessage', () {
    // =========================================================
    // HAPPY PATH TESTS (H:4)
    // =========================================================

    group('creation with required fields', () {
      test('creates a basic text message with all required fields', () {
        final message = TestChatMessages.textMessage();

        expect(message.id, 'msg-001');
        expect(message.content, 'Ciao a tutti!');
        expect(message.mentions, isEmpty);
        expect(message.reactionCount, 0);
        expect(message.replyCount, 0);
        expect(message.reportCount, 0);
        expect(message.author.fullName, 'Mario Rossi');
        expect(message.reactionCounts, isEmpty);
        expect(message.currentUserReactions, isEmpty);
      });
    });

    group('computed properties', () {
      test('isReply returns true when replyToId is set', () {
        final reply = TestChatMessages.replyMessage();
        expect(reply.isReply, isTrue);
        expect(reply.replyToId, 'msg-001');
      });

      test('isDeleted and displayContent for deleted message', () {
        final deleted = TestChatMessages.deletedMessage();
        expect(deleted.isDeleted, isTrue);
        expect(deleted.deletedByUser, isTrue);
        expect(deleted.canDelete, isFalse);
        expect(deleted.displayContent, 'Messaggio eliminato');
      });

      test('isHidden and displayContent for hidden message', () {
        final hidden = TestChatMessages.hiddenMessage();
        expect(hidden.isHidden, isTrue);
        expect(hidden.hiddenReason, 'Violazione regolamento');
        expect(hidden.displayContent, '[Messaggio nascosto]');
      });

      test('isGif returns true for gif message', () {
        final gif = TestChatMessages.gifMessage();
        expect(gif.isGif, isTrue);
        expect(gif.gifUrl, 'https://media.giphy.com/test.gif');
        expect(gif.gifId, 'abc123');
      });
    });

    group('copyWith', () {
      test('copyWith updates specified fields and preserves others', () {
        final original = TestChatMessages.textMessage();
        final updated = original.copyWith(
          content: 'Messaggio aggiornato',
          reactionCount: 5,
          isPinned: true,
        );

        expect(updated.content, 'Messaggio aggiornato');
        expect(updated.reactionCount, 5);
        expect(updated.isPinned, isTrue);
        // Preserved fields
        expect(updated.id, original.id);
        expect(updated.userId, original.userId);
        expect(updated.author, original.author);
      });
    });

    group('equality and hashCode', () {
      test('messages with same id are equal', () {
        final msg1 = TestChatMessages.textMessage(id: 'same-id');
        final msg2 = TestChatMessages.textMessage(
          id: 'same-id',
          content: 'Different content',
        );

        expect(msg1, equals(msg2));
        expect(msg1.hashCode, equals(msg2.hashCode));
      });
    });

    // =========================================================
    // EDGE CASE TESTS (E:4)
    // =========================================================

    group('edge cases', () {
      test('normal message has correct boolean defaults', () {
        final msg = TestChatMessages.textMessage();

        expect(msg.isHidden, isFalse);
        expect(msg.isDeleted, isFalse);
        expect(msg.isReply, isFalse);
        expect(msg.hasMedia, isFalse);
        expect(msg.hasMentions, isFalse);
        expect(msg.isGif, isFalse);
        expect(msg.isEdited, isFalse);
        expect(msg.hasCaption, isFalse);
        expect(msg.canDelete, isTrue);
        expect(msg.displayContent, msg.content);
      });

      test('canEdit is false for message older than 15 minutes', () {
        final oldMessage = TestChatMessages.textMessage(
          createdAt: DateTime.now().subtract(const Duration(minutes: 16)),
        );

        expect(oldMessage.canEdit, isFalse);
        expect(oldMessage.editWindowMinutesRemaining, 0);
      });

      test('canEdit is true for message within 15 minutes', () {
        final recentMessage = TestChatMessages.textMessage(
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );

        expect(recentMessage.canEdit, isTrue);
        expect(recentMessage.editWindowMinutesRemaining, greaterThan(0));
      });

      test('canEdit is false for deleted message even within window', () {
        final deletedRecent = ChatMessage(
          id: 'msg-deleted-recent',
          userId: 'user-1',
          content: 'Was here',
          mentions: const [],
          reactionCount: 0,
          replyCount: 0,
          reportCount: 0,
          createdAt: DateTime.now(), // just created
          deletedAt: DateTime.now(),
          deletedByUser: true,
          author: TestProfiles.completeProfile(),
          reactionCounts: const {},
          currentUserReactions: const {},
        );

        expect(deletedRecent.canEdit, isFalse);
      });

      test('relativeTimestamp returns Adesso for recent message', () {
        final now = TestChatMessages.textMessage(
          createdAt: DateTime.now(),
        );
        expect(now.relativeTimestamp, 'Adesso');
      });

      test('relativeTimestamp returns min fa for minutes-old message', () {
        final fiveMinAgo = TestChatMessages.textMessage(
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        );
        expect(fiveMinAgo.relativeTimestamp, '5 min fa');
      });

      test('relativeTimestamp returns ora/ore fa for hours-old message', () {
        final oneHourAgo = TestChatMessages.textMessage(
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        expect(oneHourAgo.relativeTimestamp, '1 ora fa');

        final threeHoursAgo = TestChatMessages.textMessage(
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        );
        expect(threeHoursAgo.relativeTimestamp, '3 ore fa');
      });

      test('relativeTimestamp returns Ieri for day-old message', () {
        final yesterday = TestChatMessages.textMessage(
          createdAt: DateTime.now().subtract(const Duration(hours: 25)),
        );
        expect(yesterday.relativeTimestamp, 'Ieri');
      });

      test('messages with different ids are not equal', () {
        final msg1 = TestChatMessages.textMessage(id: 'id-1');
        final msg2 = TestChatMessages.textMessage(id: 'id-2');

        expect(msg1, isNot(equals(msg2)));
      });

      test('isGif returns false for empty gifUrl', () {
        final msg = ChatMessage(
          id: 'msg-empty-gif',
          userId: 'user-1',
          content: 'text',
          mentions: const [],
          reactionCount: 0,
          replyCount: 0,
          reportCount: 0,
          createdAt: DateTime.now(),
          gifUrl: '',
          author: TestProfiles.completeProfile(),
          reactionCounts: const {},
          currentUserReactions: const {},
        );

        expect(msg.isGif, isFalse);
      });

      test('hasCaption returns false for empty mediaCaption', () {
        final msg = ChatMessage(
          id: 'msg-empty-caption',
          userId: 'user-1',
          content: 'text',
          mentions: const [],
          reactionCount: 0,
          replyCount: 0,
          reportCount: 0,
          createdAt: DateTime.now(),
          mediaCaption: '',
          author: TestProfiles.completeProfile(),
          reactionCounts: const {},
          currentUserReactions: const {},
        );

        expect(msg.hasCaption, isFalse);
      });
    });
  });
}
