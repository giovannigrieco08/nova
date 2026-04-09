import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/chat/data/models/chat_reaction_model.dart';
import 'package:nova/features/chat/domain/entities/chat_reaction.dart';

void main() {
  group('ChatReactionModel', () {
    final validJson = {
      'message_id': 'msg-001',
      'user_id': 'user-001',
      'emoji': '❤️',
      'created_at': '2025-06-15T10:00:00.000Z',
    };

    // =========================================================
    // HAPPY PATH TESTS (H:2)
    // =========================================================

    test('fromJson parses valid JSON correctly', () {
      final model = ChatReactionModel.fromJson(validJson);

      expect(model.messageId, 'msg-001');
      expect(model.userId, 'user-001');
      expect(model.emoji, '❤️');
      expect(model.createdAt, DateTime.utc(2025, 6, 15, 10, 0));
    });

    test('toJson produces correct output and fromJson roundtrip', () {
      final model = ChatReactionModel.fromJson(validJson);
      final json = model.toJson();

      // toJson only includes insert fields (no created_at)
      expect(json['message_id'], 'msg-001');
      expect(json['user_id'], 'user-001');
      expect(json['emoji'], '❤️');
      expect(json.containsKey('created_at'), isFalse);
    });

    // =========================================================
    // EDGE CASE TESTS (E:2)
    // =========================================================

    test('toEntity converts to domain entity correctly', () {
      final model = ChatReactionModel.fromJson(validJson);
      final entity = model.toEntity();

      expect(entity, isA<ChatReaction>());
      expect(entity.messageId, 'msg-001');
      expect(entity.userId, 'user-001');
      expect(entity.emoji, '❤️');
      expect(entity.createdAt, DateTime.utc(2025, 6, 15, 10, 0));
    });

    test('fromEntity roundtrip preserves data', () {
      final entity = ChatReaction(
        messageId: 'msg-002',
        userId: 'user-002',
        emoji: '🔥',
        createdAt: DateTime.utc(2025, 7, 1, 14, 30),
      );

      final model = ChatReactionModel.fromEntity(entity);
      expect(model.messageId, 'msg-002');
      expect(model.userId, 'user-002');
      expect(model.emoji, '🔥');

      final backToEntity = model.toEntity();
      expect(backToEntity.messageId, entity.messageId);
      expect(backToEntity.userId, entity.userId);
      expect(backToEntity.emoji, entity.emoji);
      expect(backToEntity.createdAt, entity.createdAt);
    });

    test('toInsertJson creates correct insert payload', () {
      final json = ChatReactionModel.toInsertJson(
        messageId: 'msg-003',
        userId: 'user-003',
        emoji: '😂',
      );

      expect(json['message_id'], 'msg-003');
      expect(json['user_id'], 'user-003');
      expect(json['emoji'], '😂');
      expect(json.containsKey('created_at'), isFalse);
    });
  });
}
