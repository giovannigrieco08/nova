import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/chat/domain/entities/chat_reaction.dart';

void main() {
  group('ChatReaction', () {
    // =========================================================
    // HAPPY PATH TESTS (H:2)
    // =========================================================

    test('creates reaction with required fields', () {
      final now = DateTime(2025, 6, 15, 10, 30);
      final reaction = ChatReaction(
        messageId: 'msg-001',
        userId: 'user-001',
        emoji: ChatEmoji.heart,
        createdAt: now,
      );

      expect(reaction.messageId, 'msg-001');
      expect(reaction.userId, 'user-001');
      expect(reaction.emoji, ChatEmoji.heart);
      expect(reaction.createdAt, now);
    });

    test('equality is based on messageId, userId, and emoji', () {
      final r1 = ChatReaction(
        messageId: 'msg-001',
        userId: 'user-001',
        emoji: ChatEmoji.fire,
        createdAt: DateTime(2025, 1, 1),
      );
      final r2 = ChatReaction(
        messageId: 'msg-001',
        userId: 'user-001',
        emoji: ChatEmoji.fire,
        createdAt: DateTime(2025, 6, 1), // different time
      );

      expect(r1, equals(r2));
      expect(r1.hashCode, equals(r2.hashCode));
    });

    // =========================================================
    // EDGE CASE TESTS (E:2)
    // =========================================================

    test('reactions with different emoji are not equal', () {
      final r1 = ChatReaction(
        messageId: 'msg-001',
        userId: 'user-001',
        emoji: ChatEmoji.heart,
        createdAt: DateTime.now(),
      );
      final r2 = ChatReaction(
        messageId: 'msg-001',
        userId: 'user-001',
        emoji: ChatEmoji.fire,
        createdAt: DateTime.now(),
      );

      expect(r1, isNot(equals(r2)));
    });

    test('reactions with different userId are not equal', () {
      final r1 = ChatReaction(
        messageId: 'msg-001',
        userId: 'user-001',
        emoji: ChatEmoji.heart,
        createdAt: DateTime.now(),
      );
      final r2 = ChatReaction(
        messageId: 'msg-001',
        userId: 'user-002',
        emoji: ChatEmoji.heart,
        createdAt: DateTime.now(),
      );

      expect(r1, isNot(equals(r2)));
    });
  });

  group('ChatEmoji', () {
    test('all contains exactly 6 allowed emoji', () {
      expect(ChatEmoji.all, hasLength(6));
      expect(ChatEmoji.all, contains(ChatEmoji.heart));
      expect(ChatEmoji.all, contains(ChatEmoji.thumbsUp));
      expect(ChatEmoji.all, contains(ChatEmoji.laughing));
      expect(ChatEmoji.all, contains(ChatEmoji.surprised));
      expect(ChatEmoji.all, contains(ChatEmoji.sad));
      expect(ChatEmoji.all, contains(ChatEmoji.fire));
    });

    test('isValid returns true for allowed emoji and false for others', () {
      expect(ChatEmoji.isValid(ChatEmoji.heart), isTrue);
      expect(ChatEmoji.isValid(ChatEmoji.fire), isTrue);
      expect(ChatEmoji.isValid('invalid'), isFalse);
      expect(ChatEmoji.isValid(''), isFalse);
    });

    test('labelFor returns Italian labels for known emoji', () {
      expect(ChatEmoji.labelFor(ChatEmoji.heart), 'Cuore');
      expect(ChatEmoji.labelFor(ChatEmoji.thumbsUp), 'Mi piace');
      expect(ChatEmoji.labelFor(ChatEmoji.laughing), 'Divertente');
      expect(ChatEmoji.labelFor(ChatEmoji.surprised), 'Sorpreso');
      expect(ChatEmoji.labelFor(ChatEmoji.sad), 'Triste');
      expect(ChatEmoji.labelFor(ChatEmoji.fire), 'Fuoco');
    });

    test('labelFor returns the emoji itself for unknown emoji', () {
      expect(ChatEmoji.labelFor('unknown'), 'unknown');
    });
  });
}
