import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/chat/data/models/chat_message_model.dart';

void main() {
  group('ChatMessageModel', () {
    final baseJson = {
      'id': 'msg-001',
      'user_id': 'user-001',
      'content': 'Ciao a tutti!',
      'mentions': <dynamic>[],
      'reaction_count': 2,
      'reply_count': 1,
      'report_count': 0,
      'created_at': '2025-06-15T10:00:00.000Z',
    };

    final fullJson = {
      ...baseJson,
      'reply_to_id': 'msg-000',
      'hidden_at': '2025-06-15T12:00:00.000Z',
      'hidden_reason': 'Violazione',
      'edited_at': '2025-06-15T10:05:00.000Z',
      'original_content': 'Ciao!',
      'is_pinned': true,
      'pinned_at': '2025-06-15T11:00:00.000Z',
      'pinned_by_user_id': 'mod-001',
      'gif_url': 'https://media.giphy.com/test.gif',
      'gif_id': 'abc123',
      'media_caption': 'Foto del cortile',
      'deleted_at': null,
      'deleted_by_user': false,
      'profiles': {
        'user_id': 'user-001',
        'email': 'mario@galileimoro.edu.it',
        'full_name': 'Mario Rossi',
        'username': 'mario.rossi',
        'class': '4A',
        'role': 'student',
        'profile_visible': true,
        'created_at': '2025-01-01T00:00:00.000Z',
        'updated_at': '2025-01-02T00:00:00.000Z',
      },
      'chat_reactions': [
        {'message_id': 'msg-001', 'user_id': 'user-001', 'emoji': '❤️'},
        {'message_id': 'msg-001', 'user_id': 'user-002', 'emoji': '❤️'},
        {'message_id': 'msg-001', 'user_id': 'user-002', 'emoji': '🔥'},
      ],
      'mentions': [
        {
          'user_id': 'user-002',
          'username': 'lucia.bianchi',
          'start_index': 0,
          'end_index': 14,
        },
      ],
    };

    // =========================================================
    // HAPPY PATH TESTS (H:4)
    // =========================================================

    group('fromJson', () {
      test('parses minimal valid JSON correctly', () {
        final model = ChatMessageModel.fromJson(baseJson);

        expect(model.id, 'msg-001');
        expect(model.userId, 'user-001');
        expect(model.content, 'Ciao a tutti!');
        expect(model.mentionsJson, isEmpty);
        expect(model.reactionCount, 2);
        expect(model.replyCount, 1);
        expect(model.reportCount, 0);
        expect(model.createdAt, DateTime.utc(2025, 6, 15, 10, 0));
        expect(model.replyToId, isNull);
        expect(model.hiddenAt, isNull);
        expect(model.editedAt, isNull);
        expect(model.isPinned, isFalse);
        expect(model.deletedAt, isNull);
        expect(model.deletedByUser, isFalse);
      });

      test('parses full JSON with all optional fields', () {
        final model = ChatMessageModel.fromJson(fullJson);

        expect(model.replyToId, 'msg-000');
        expect(model.hiddenAt, isNotNull);
        expect(model.hiddenReason, 'Violazione');
        expect(model.editedAt, isNotNull);
        expect(model.originalContent, 'Ciao!');
        expect(model.isPinned, isTrue);
        expect(model.pinnedAt, isNotNull);
        expect(model.pinnedByUserId, 'mod-001');
        expect(model.gifUrl, 'https://media.giphy.com/test.gif');
        expect(model.gifId, 'abc123');
        expect(model.mediaCaption, 'Foto del cortile');
        expect(model.authorJson, isNotNull);
        expect(model.reactionsJson, hasLength(3));
        expect(model.mentionsJson, hasLength(1));
      });
    });

    group('toJson', () {
      test('produces correct output for insert/update', () {
        final model = ChatMessageModel.fromJson(baseJson);
        final json = model.toJson();

        expect(json['id'], 'msg-001');
        expect(json['user_id'], 'user-001');
        expect(json['content'], 'Ciao a tutti!');
        expect(json['mentions'], isEmpty);
        expect(json['created_at'], '2025-06-15T10:00:00.000Z');
        expect(json['reply_to_id'], isNull);
        // Deleted fields should not be present when null/false
        expect(json.containsKey('deleted_at'), isFalse);
        expect(json.containsKey('deleted_by_user'), isFalse);
      });
    });

    group('toEntity', () {
      test('converts model to domain entity with reactions aggregated', () {
        final model = ChatMessageModel.fromJson(fullJson);
        final entity = model.toEntity(currentUserId: 'user-001');

        expect(entity.id, 'msg-001');
        expect(entity.content, 'Ciao a tutti!');
        expect(entity.mentions, hasLength(1));
        expect(entity.mentions.first.username, 'lucia.bianchi');
        expect(entity.author.fullName, 'Mario Rossi');
        expect(entity.isPinned, isTrue);
        expect(entity.gifUrl, 'https://media.giphy.com/test.gif');

        // Reaction aggregation
        expect(entity.reactionCounts['❤️'], 2);
        expect(entity.reactionCounts['🔥'], 1);

        // Current user reactions
        expect(entity.currentUserReactions, contains('❤️'));
        expect(entity.currentUserReactions, isNot(contains('🔥')));
      });
    });

    group('toInsertJson', () {
      test('creates correct insert payload', () {
        final json = ChatMessageModel.toInsertJson(
          userId: 'user-001',
          content: 'Nuovo messaggio',
          mentions: [
            {'user_id': 'user-002', 'username': 'lucia', 'start_index': 0, 'end_index': 6},
          ],
          replyToId: 'msg-parent',
        );

        expect(json['user_id'], 'user-001');
        expect(json['content'], 'Nuovo messaggio');
        expect(json['mentions'], hasLength(1));
        expect(json['reply_to_id'], 'msg-parent');
        // Should not contain server-generated fields
        expect(json.containsKey('id'), isFalse);
        expect(json.containsKey('created_at'), isFalse);
        expect(json.containsKey('reaction_count'), isFalse);
      });
    });

    // =========================================================
    // EDGE CASE TESTS (E:5)
    // =========================================================

    group('edge cases', () {
      test('fromJson handles null/missing optional count fields with defaults',
          () {
        final json = {
          'id': 'msg-002',
          'user_id': 'user-001',
          'content': 'Hello',
          'created_at': '2025-06-15T10:00:00.000Z',
          // No mentions, no counts, no is_pinned, no deleted_by_user
        };

        final model = ChatMessageModel.fromJson(json);
        expect(model.mentionsJson, isEmpty);
        expect(model.reactionCount, 0);
        expect(model.replyCount, 0);
        expect(model.reportCount, 0);
        expect(model.isPinned, isFalse);
        expect(model.deletedByUser, isFalse);
      });

      test('toEntity returns placeholder profile when authorJson is null', () {
        final model = ChatMessageModel.fromJson(baseJson);
        final entity = model.toEntity(currentUserId: 'user-001');

        // authorJson is null in baseJson so should get placeholder
        expect(entity.author.fullName, 'Utente');
        expect(entity.author.username, 'utente');
      });

      test('toEntity returns empty reactions when reactionsJson is null', () {
        final model = ChatMessageModel.fromJson(baseJson);
        final entity = model.toEntity(currentUserId: 'user-001');

        expect(entity.reactionCounts, isEmpty);
        expect(entity.currentUserReactions, isEmpty);
      });

      test('_parseMediaJson handles list with single item', () {
        final json = {
          ...baseJson,
          'chat_media': [
            {
              'id': 'media-001',
              'message_id': 'msg-001',
              'uploader_user_id': 'user-001',
              'storage_path': 'chat_media/test.jpg',
              'media_type': 'image',
              'file_size_bytes': 1024,
              'max_views': 1,
              'view_count': 0,
              'screenshot_notified': false,
              'expires_at': '2025-06-16T10:00:00.000Z',
              'created_at': '2025-06-15T10:00:00.000Z',
            }
          ],
        };

        final model = ChatMessageModel.fromJson(json);
        expect(model.mediaJson, isNotNull);
        expect(model.mediaJson!['id'], 'media-001');

        final entity = model.toEntity(currentUserId: 'user-001');
        expect(entity.media, isNotNull);
        expect(entity.media!.id, 'media-001');
      });

      test('_parseMediaJson handles empty list as null', () {
        final json = {
          ...baseJson,
          'chat_media': <dynamic>[],
        };

        final model = ChatMessageModel.fromJson(json);
        expect(model.mediaJson, isNull);
      });

      test('toJson includes deleted fields when set', () {
        final json = {
          ...baseJson,
          'deleted_at': '2025-06-15T12:00:00.000Z',
          'deleted_by_user': true,
        };

        final model = ChatMessageModel.fromJson(json);
        final output = model.toJson();

        expect(output.containsKey('deleted_at'), isTrue);
        expect(output['deleted_by_user'], isTrue);
      });
    });
  });
}
