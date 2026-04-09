import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/chat/data/models/chat_media_model.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';

void main() {
  group('ChatMediaModel', () {
    final validJson = {
      'id': 'media-001',
      'message_id': 'msg-001',
      'uploader_user_id': 'user-001',
      'storage_path': 'chat_media/img_001.jpg',
      'media_type': 'image',
      'file_size_bytes': 2048000,
      'max_views': 2,
      'view_count': 1,
      'viewed_at': '2025-06-15T11:00:00.000Z',
      'viewed_by_user_id': 'user-002',
      'screenshot_detected_at': '2025-06-15T11:05:00.000Z',
      'screenshot_notified': true,
      'expires_at': '2025-06-16T10:00:00.000Z',
      'created_at': '2025-06-15T10:00:00.000Z',
      'duration_seconds': null,
    };

    final minimalJson = {
      'id': 'media-002',
      'message_id': 'msg-002',
      'uploader_user_id': 'user-001',
      'storage_path': 'chat_media/img_002.jpg',
      'media_type': 'image',
      'file_size_bytes': 1024,
      'expires_at': '2025-06-16T10:00:00.000Z',
      'created_at': '2025-06-15T10:00:00.000Z',
    };

    // =========================================================
    // HAPPY PATH TESTS (H:3)
    // =========================================================

    test('fromJson parses full valid JSON correctly', () {
      final model = ChatMediaModel.fromJson(validJson);

      expect(model.id, 'media-001');
      expect(model.messageId, 'msg-001');
      expect(model.uploaderUserId, 'user-001');
      expect(model.storagePath, 'chat_media/img_001.jpg');
      expect(model.mediaType, 'image');
      expect(model.fileSizeBytes, 2048000);
      expect(model.maxViews, 2);
      expect(model.viewCount, 1);
      expect(model.viewedAt, DateTime.utc(2025, 6, 15, 11, 0));
      expect(model.viewedByUserId, 'user-002');
      expect(model.screenshotDetectedAt, DateTime.utc(2025, 6, 15, 11, 5));
      expect(model.screenshotNotified, isTrue);
      expect(model.expiresAt, DateTime.utc(2025, 6, 16, 10, 0));
      expect(model.durationSeconds, isNull);
    });

    test('toJson produces correct output for insert', () {
      final model = ChatMediaModel.fromJson(validJson);
      final json = model.toJson();

      expect(json['id'], 'media-001');
      expect(json['message_id'], 'msg-001');
      expect(json['uploader_user_id'], 'user-001');
      expect(json['storage_path'], 'chat_media/img_001.jpg');
      expect(json['media_type'], 'image');
      expect(json['file_size_bytes'], 2048000);
      expect(json['max_views'], 2);
      expect(json['view_count'], 1);
      expect(json['screenshot_notified'], isTrue);
      expect(json['expires_at'], isNotNull);
      // viewed_at is present since it was set
      expect(json['viewed_at'], isNotNull);
    });

    test('toEntity converts model to domain entity correctly', () {
      final model = ChatMediaModel.fromJson(validJson);
      final entity = model.toEntity();

      expect(entity, isA<ChatMediaInfo>());
      expect(entity.id, 'media-001');
      expect(entity.mediaType, ChatMediaType.image);
      expect(entity.maxViews, 2);
      expect(entity.viewCount, 1);
      expect(entity.screenshotDetected, isTrue); // based on screenshotDetectedAt != null
      expect(entity.remainingViews, 1);
      expect(entity.isViewed, isFalse);
    });

    // =========================================================
    // EDGE CASE TESTS (E:3)
    // =========================================================

    test('fromJson handles missing optional fields with defaults', () {
      final model = ChatMediaModel.fromJson(minimalJson);

      expect(model.maxViews, 1);
      expect(model.viewCount, 0);
      expect(model.viewedAt, isNull);
      expect(model.viewedByUserId, isNull);
      expect(model.screenshotDetectedAt, isNull);
      expect(model.screenshotNotified, isFalse);
      expect(model.durationSeconds, isNull);
    });

    test('toEntity sets screenshotDetected false when screenshotDetectedAt is null',
        () {
      final model = ChatMediaModel.fromJson(minimalJson);
      final entity = model.toEntity();

      expect(entity.screenshotDetected, isFalse);
    });

    test('fromEntity and back to entity roundtrip preserves data', () {
      final entity = ChatMediaInfo(
        id: 'media-003',
        messageId: 'msg-003',
        uploaderUserId: 'user-003',
        storagePath: 'chat_media/audio_001.ogg',
        mediaType: ChatMediaType.audio,
        fileSizeBytes: 50000,
        maxViews: 1,
        viewCount: 0,
        screenshotDetected: false,
        expiresAt: DateTime.utc(2025, 7, 2, 10, 0),
        createdAt: DateTime.utc(2025, 7, 1, 10, 0),
        durationSeconds: 45,
      );

      final model = ChatMediaModel.fromEntity(entity);
      expect(model.mediaType, 'audio');
      expect(model.durationSeconds, 45);
      expect(model.screenshotDetectedAt, isNull); // fromEntity always sets null
      expect(model.screenshotNotified, isFalse);

      final backToEntity = model.toEntity();
      expect(backToEntity.id, entity.id);
      expect(backToEntity.mediaType, ChatMediaType.audio);
      expect(backToEntity.fileSizeBytes, 50000);
      expect(backToEntity.durationSeconds, 45);
      expect(backToEntity.screenshotDetected, isFalse);
    });

    test('toInsertJson creates correct payload with optional durationSeconds',
        () {
      final json = ChatMediaModel.toInsertJson(
        messageId: 'msg-004',
        uploaderUserId: 'user-004',
        storagePath: 'chat_media/vid_001.mp4',
        mediaType: ChatMediaType.video,
        fileSizeBytes: 5000000,
        maxViews: 2,
      );

      expect(json['message_id'], 'msg-004');
      expect(json['uploader_user_id'], 'user-004');
      expect(json['storage_path'], 'chat_media/vid_001.mp4');
      expect(json['media_type'], 'video');
      expect(json['file_size_bytes'], 5000000);
      expect(json['max_views'], 2);
      expect(json.containsKey('duration_seconds'), isFalse);
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('created_at'), isFalse);

      // With duration
      final audioJson = ChatMediaModel.toInsertJson(
        messageId: 'msg-005',
        uploaderUserId: 'user-005',
        storagePath: 'chat_media/audio.ogg',
        mediaType: ChatMediaType.audio,
        fileSizeBytes: 30000,
        durationSeconds: 60,
      );

      expect(audioJson['duration_seconds'], 60);
    });

    test('fromJson → toJson roundtrip preserves key fields', () {
      final model = ChatMediaModel.fromJson(validJson);
      final json = model.toJson();

      expect(json['id'], validJson['id']);
      expect(json['message_id'], validJson['message_id']);
      expect(json['uploader_user_id'], validJson['uploader_user_id']);
      expect(json['storage_path'], validJson['storage_path']);
      expect(json['media_type'], validJson['media_type']);
      expect(json['file_size_bytes'], validJson['file_size_bytes']);
      expect(json['max_views'], validJson['max_views']);
      expect(json['view_count'], validJson['view_count']);
    });
  });
}
