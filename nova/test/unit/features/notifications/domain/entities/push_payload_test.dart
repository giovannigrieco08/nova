import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/notifications/domain/entities/push_payload.dart';

void main() {
  PushPayload createPayload({
    String title = 'Nova',
    String body = 'New notification',
    String targetType = 'event',
    String targetId = 'event-001',
    String notificationId = 'notif-001',
    int badgeCount = 3,
    String? eventId,
    Map<String, dynamic>? metadata,
  }) {
    return PushPayload(
      title: title,
      body: body,
      targetType: targetType,
      targetId: targetId,
      notificationId: notificationId,
      badgeCount: badgeCount,
      eventId: eventId,
      metadata: metadata,
    );
  }

  group('PushPayload', () {
    // ===================== HAPPY PATH =====================

    test('creates with all required fields', () {
      final payload = createPayload();

      expect(payload.title, 'Nova');
      expect(payload.body, 'New notification');
      expect(payload.targetType, 'event');
      expect(payload.targetId, 'event-001');
      expect(payload.notificationId, 'notif-001');
      expect(payload.badgeCount, 3);
      expect(payload.isEventTarget, true);
      expect(payload.isCommentTarget, false);
      expect(payload.navigationEventId, 'event-001');
    });

    test('fromFcmData parses FCM data map', () {
      final data = {
        'title': 'Test Title',
        'body': 'Test Body',
        'target_type': 'comment',
        'target_id': 'comment-001',
        'notification_id': 'n1',
        'badge_count': '5',
        'event_id': 'event-002',
      };

      final payload = PushPayload.fromFcmData(data);

      expect(payload.title, 'Test Title');
      expect(payload.body, 'Test Body');
      expect(payload.targetType, 'comment');
      expect(payload.targetId, 'comment-001');
      expect(payload.badgeCount, 5);
      expect(payload.eventId, 'event-002');
      expect(payload.isCommentTarget, true);
      expect(payload.navigationEventId, 'event-002');
    });

    test('toFcmData converts to string map', () {
      final payload = createPayload(eventId: 'ev-001');
      final data = payload.toFcmData();

      expect(data['title'], 'Nova');
      expect(data['badge_count'], '3');
      expect(data['event_id'], 'ev-001');
      // All values must be strings for FCM
      expect(data.values.every((v) => v is String), true);
    });

    // ===================== EDGE CASES =====================

    test('fromFcmData defaults missing fields', () {
      final payload = PushPayload.fromFcmData({});

      expect(payload.title, 'Nova');
      expect(payload.body, '');
      expect(payload.targetType, 'event');
      expect(payload.targetId, '');
      expect(payload.badgeCount, 0);
      expect(payload.eventId, isNull);
    });

    test('navigationEventId returns eventId for comment targets', () {
      final payload = createPayload(
        targetType: 'comment',
        targetId: 'comment-001',
        eventId: 'event-parent',
      );

      expect(payload.navigationEventId, 'event-parent');
    });

    test('navigationEventId returns null for comment target without eventId',
        () {
      final payload = createPayload(
        targetType: 'comment',
        targetId: 'comment-001',
      );

      expect(payload.navigationEventId, isNull);
    });
  });
}
