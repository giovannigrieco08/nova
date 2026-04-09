import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/notifications/domain/entities/notification.dart';
import 'package:nova/features/notifications/domain/entities/notification_channel.dart';

void main() {
  AppNotification createNotification({
    String id = 'notif-001',
    String userId = 'user-001',
    NotificationChannel channel = NotificationChannel.eventModeration,
    String title = 'Test Notification',
    String body = 'Test body',
    Map<String, dynamic>? data,
    bool isRead = false,
    DateTime? createdAt,
    String? actorId,
    String? actorName,
    String? actorAvatarUrl,
  }) {
    return AppNotification(
      id: id,
      userId: userId,
      channel: channel,
      title: title,
      body: body,
      data: data,
      isRead: isRead,
      createdAt: createdAt ?? DateTime(2025, 6, 1),
      actorId: actorId,
      actorName: actorName,
      actorAvatarUrl: actorAvatarUrl,
    );
  }

  group('AppNotification', () {
    // ===================== HAPPY PATH =====================

    test('creates with all required fields', () {
      final notif = createNotification();

      expect(notif.id, 'notif-001');
      expect(notif.userId, 'user-001');
      expect(notif.channel, NotificationChannel.eventModeration);
      expect(notif.title, 'Test Notification');
      expect(notif.body, 'Test body');
      expect(notif.isRead, false);
    });

    test('fromJson parses complete JSON with actor profile join', () {
      final json = {
        'id': 'n1',
        'recipient_id': 'user-002',
        'type': 'new_comment',
        'title': 'Nuovo commento',
        'description': 'Mario ha commentato',
        'is_read': false,
        'created_at': '2025-06-01T10:00:00.000Z',
        'sender_id': 'actor-001',
        'actor': {
          'full_name': 'Mario Rossi',
          'avatar_url': 'https://example.com/avatar.jpg',
        },
        'target_type': 'event',
        'target_id': 'event-001',
        'metadata': {'extra': 'data'},
      };

      final notif = AppNotification.fromJson(json);

      expect(notif.id, 'n1');
      expect(notif.userId, 'user-002');
      expect(notif.channel, NotificationChannel.newComment);
      expect(notif.title, 'Nuovo commento');
      expect(notif.body, 'Mario ha commentato');
      expect(notif.actorId, 'actor-001');
      expect(notif.actorName, 'Mario Rossi');
      expect(notif.actorAvatarUrl, 'https://example.com/avatar.jpg');
      expect(notif.data!['target_type'], 'event');
      expect(notif.data!['target_id'], 'event-001');
      expect(notif.data!['extra'], 'data');
    });

    test('hasAction and ctaLabel are correct for each channel', () {
      // Channels with actions
      expect(
        createNotification(channel: NotificationChannel.newComment).hasAction,
        true,
      );
      expect(
        createNotification(channel: NotificationChannel.newComment).ctaLabel,
        'Rispondi',
      );
      expect(
        createNotification(channel: NotificationChannel.moderatorAlert)
            .hasAction,
        true,
      );
      expect(
        createNotification(channel: NotificationChannel.moderatorAlert)
            .ctaLabel,
        'Modera',
      );

      // Channels without actions
      expect(
        createNotification(channel: NotificationChannel.eventLike).hasAction,
        false,
      );
      expect(
        createNotification(channel: NotificationChannel.eventParticipation)
            .hasAction,
        false,
      );
    });

    // ===================== EDGE CASES =====================

    test('fromJson defaults unknown type to eventModeration', () {
      final json = {
        'id': 'n1',
        'recipient_id': 'u1',
        'type': 'unknown_type',
        'created_at': '2025-01-01T00:00:00.000Z',
      };

      final notif = AppNotification.fromJson(json);
      expect(notif.channel, NotificationChannel.eventModeration);
    });

    test('fromJson falls back to metadata for actor name', () {
      final json = {
        'id': 'n1',
        'recipient_id': 'u1',
        'type': 'event_moderation',
        'created_at': '2025-01-01T00:00:00.000Z',
        'sender_id': 'actor-001',
        'metadata': {'actor_name': 'Fallback Name'},
      };

      final notif = AppNotification.fromJson(json);
      expect(notif.actorName, 'Fallback Name');
    });

    test('copyWith replaces specified fields', () {
      final original = createNotification();
      final modified = original.copyWith(isRead: true, title: 'Updated');

      expect(modified.isRead, true);
      expect(modified.title, 'Updated');
      expect(modified.id, original.id);
      expect(modified.userId, original.userId);
    });
  });

  group('NotificationState', () {
    test('creates with defaults', () {
      const state = NotificationState();

      expect(state.notifications, isEmpty);
      expect(state.isLoading, false);
      expect(state.error, isNull);
    });

    test('copyWith replaces specified fields', () {
      const state = NotificationState(isLoading: true);
      final modified = state.copyWith(isLoading: false, error: 'Oops');

      expect(modified.isLoading, false);
      expect(modified.error, 'Oops');
    });
  });
}
