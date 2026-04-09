import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/domain/entities/app_notification.dart';
import 'package:nova/features/events/domain/entities/notification_channel.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 0);

  group('AppNotification', () {
    // =====================================================================
    // Happy Path Tests (H:2)
    // =====================================================================

    test('should create AppNotification with required fields and defaults', () {
      final notification = AppNotification(
        id: 'notif-001',
        userId: 'user-001',
        channel: NotificationChannel.eventApproved,
        title: 'Evento Approvato',
        body: 'Il tuo evento "Torneo" e stato approvato!',
        sentAt: now,
      );

      expect(notification.id, 'notif-001');
      expect(notification.userId, 'user-001');
      expect(notification.channel, NotificationChannel.eventApproved);
      expect(notification.title, 'Evento Approvato');
      expect(notification.body, contains('Torneo'));
      expect(notification.eventId, isNull);
      expect(notification.read, isFalse);
      expect(notification.delivered, isFalse);
    });

    test('should create AppNotification with all optional fields', () {
      final notification = AppNotification(
        id: 'notif-002',
        userId: 'user-001',
        channel: NotificationChannel.eventRejected,
        title: 'Evento Rifiutato',
        body: 'Il tuo evento e stato rifiutato.',
        eventId: 'event-001',
        sentAt: now,
        read: true,
        delivered: true,
      );

      expect(notification.eventId, 'event-001');
      expect(notification.read, isTrue);
      expect(notification.delivered, isTrue);
    });

    // =====================================================================
    // Edge Case Tests (E:2)
    // =====================================================================

    test('read and delivered default to false', () {
      final notification = AppNotification(
        id: 'notif-003',
        userId: 'user-002',
        channel: NotificationChannel.addedAsCoorganizer,
        title: 'Co-organizzatore',
        body: 'Sei stato aggiunto come co-organizzatore.',
        sentAt: now,
      );

      expect(notification.read, false);
      expect(notification.delivered, false);
    });

    test('supports all notification channels', () {
      for (final channel in NotificationChannel.values) {
        final notification = AppNotification(
          id: 'notif-${channel.name}',
          userId: 'user-001',
          channel: channel,
          title: 'Test',
          body: 'Test body',
          sentAt: now,
        );

        expect(notification.channel, channel);
      }
    });
  });
}
