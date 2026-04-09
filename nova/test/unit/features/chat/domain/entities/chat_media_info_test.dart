import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';

void main() {
  group('ChatMediaInfo', () {
    ChatMediaInfo createMedia({
      String id = 'media-001',
      String messageId = 'msg-001',
      String uploaderUserId = 'user-001',
      String storagePath = 'chat_media/test.jpg',
      ChatMediaType mediaType = ChatMediaType.image,
      int fileSizeBytes = 1024000,
      int maxViews = 1,
      int viewCount = 0,
      DateTime? viewedAt,
      String? viewedByUserId,
      bool screenshotDetected = false,
      DateTime? expiresAt,
      DateTime? createdAt,
      int? durationSeconds,
    }) {
      return ChatMediaInfo(
        id: id,
        messageId: messageId,
        uploaderUserId: uploaderUserId,
        storagePath: storagePath,
        mediaType: mediaType,
        fileSizeBytes: fileSizeBytes,
        maxViews: maxViews,
        viewCount: viewCount,
        viewedAt: viewedAt,
        viewedByUserId: viewedByUserId,
        screenshotDetected: screenshotDetected,
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(hours: 24)),
        createdAt: createdAt ?? DateTime.now(),
        durationSeconds: durationSeconds,
      );
    }

    // =========================================================
    // HAPPY PATH TESTS (H:3)
    // =========================================================

    group('creation and basic properties', () {
      test('creates media with required fields and correct defaults', () {
        final media = createMedia();

        expect(media.id, 'media-001');
        expect(media.messageId, 'msg-001');
        expect(media.uploaderUserId, 'user-001');
        expect(media.storagePath, 'chat_media/test.jpg');
        expect(media.mediaType, ChatMediaType.image);
        expect(media.fileSizeBytes, 1024000);
        expect(media.maxViews, 1);
        expect(media.viewCount, 0);
        expect(media.screenshotDetected, isFalse);
      });
    });

    group('computed properties', () {
      test('isViewed, remainingViews, canView for unviewed media', () {
        final media = createMedia(maxViews: 2, viewCount: 0);

        expect(media.isViewed, isFalse);
        expect(media.remainingViews, 2);
        expect(media.canView, isTrue);
      });

      test('fileSizeFormatted returns correct human-readable sizes', () {
        expect(createMedia(fileSizeBytes: 500).fileSizeFormatted, '500 B');
        expect(
          createMedia(fileSizeBytes: 2048).fileSizeFormatted,
          '2.0 KB',
        );
        expect(
          createMedia(fileSizeBytes: 1572864).fileSizeFormatted,
          '1.5 MB',
        );
      });
    });

    group('equality and hashCode', () {
      test('media with same id are equal', () {
        final media1 = createMedia(id: 'same-id');
        final media2 = createMedia(id: 'same-id', fileSizeBytes: 999);

        expect(media1, equals(media2));
        expect(media1.hashCode, equals(media2.hashCode));
      });
    });

    // =========================================================
    // EDGE CASE TESTS (E:3)
    // =========================================================

    group('edge cases', () {
      test('isViewed true when viewCount equals maxViews', () {
        final media = createMedia(maxViews: 1, viewCount: 1);

        expect(media.isViewed, isTrue);
        expect(media.remainingViews, 0);
        expect(media.canView, isFalse);
      });

      test('canView is false when expired even if not fully viewed', () {
        final expiredMedia = createMedia(
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
          viewCount: 0,
        );

        expect(expiredMedia.isExpired, isTrue);
        expect(expiredMedia.canView, isFalse);
      });

      test('durationFormatted and duration for audio messages', () {
        final audio = createMedia(
          mediaType: ChatMediaType.audio,
          durationSeconds: 125,
        );

        expect(audio.duration, const Duration(seconds: 125));
        expect(audio.durationFormatted, '02:05');

        // Null duration
        final noAudio = createMedia(durationSeconds: null);
        expect(noAudio.duration, isNull);
        expect(noAudio.durationFormatted, '00:00');
      });

      test('remainingViews is clamped to 0 when viewCount exceeds maxViews',
          () {
        final overViewed = createMedia(maxViews: 1, viewCount: 3);
        expect(overViewed.remainingViews, 0);
      });

      test('media with different ids are not equal', () {
        final media1 = createMedia(id: 'id-1');
        final media2 = createMedia(id: 'id-2');
        expect(media1, isNot(equals(media2)));
      });
    });
  });

  group('ChatMediaType', () {
    test('fromValue returns correct enum values', () {
      expect(ChatMediaType.fromValue('image'), ChatMediaType.image);
      expect(ChatMediaType.fromValue('video'), ChatMediaType.video);
      expect(ChatMediaType.fromValue('audio'), ChatMediaType.audio);
    });

    test('fromValue defaults to image for unknown value', () {
      expect(ChatMediaType.fromValue('unknown'), ChatMediaType.image);
    });

    test('type predicates work correctly', () {
      expect(ChatMediaType.image.isImage, isTrue);
      expect(ChatMediaType.image.isVideo, isFalse);
      expect(ChatMediaType.video.isVideo, isTrue);
      expect(ChatMediaType.audio.isAudio, isTrue);
    });

    test('value property returns correct database string', () {
      expect(ChatMediaType.image.value, 'image');
      expect(ChatMediaType.video.value, 'video');
      expect(ChatMediaType.audio.value, 'audio');
    });
  });
}
