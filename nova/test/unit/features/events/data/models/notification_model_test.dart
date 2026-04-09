import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/data/models/notification_model.dart';
import 'package:nova/features/events/domain/entities/app_notification.dart';
import 'package:nova/features/events/domain/entities/notification_channel.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 0);

  group('NotificationModel', () {
    // =====================================================================
    // Happy Path Tests (H:3)
    // =====================================================================

    test('should create NotificationModel with all fields', () {
      final model = NotificationModel(
        id: 'notif-001',
        userId: 'user-001',
        channel: 'eventApproved',
        title: 'Evento Approvato',
        body: 'Il tuo evento e stato approvato!',
        eventId: 'event-001',
        sentAt: now,
        read: false,
        delivered: true,
      );

      expect(model.id, 'notif-001');
      expect(model.userId, 'user-001');
      expect(model.channel, 'eventApproved');
      expect(model.title, 'Evento Approvato');
      expect(model.eventId, 'event-001');
      expect(model.read, isFalse);
      expect(model.delivered, isTrue);
    });

    test('toEntity converts model to AppNotification domain entity', () {
      final model = NotificationModel(
        id: 'notif-001',
        userId: 'user-001',
        channel: 'eventApproved',
        title: 'Evento Approvato',
        body: 'Approvato dal moderatore.',
        eventId: 'event-001',
        sentAt: now,
        read: true,
        delivered: true,
      );

      final entity = model.toEntity();

      expect(entity, isA<AppNotification>());
      expect(entity.id, 'notif-001');
      expect(entity.channel, NotificationChannel.eventApproved);
      expect(entity.read, isTrue);
      expect(entity.delivered, isTrue);
    });

    test('fromEntity creates model from AppNotification entity', () {
      final entity = AppNotification(
        id: 'notif-001',
        userId: 'user-001',
        channel: NotificationChannel.eventRejected,
        title: 'Rifiutato',
        body: 'Il tuo evento e stato rifiutato.',
        eventId: 'event-001',
        sentAt: now,
        read: false,
        delivered: false,
      );

      final model = NotificationModel.fromEntity(entity);

      expect(model.id, entity.id);
      expect(model.channel, 'eventRejected');
      expect(model.read, false);
      expect(model.delivered, false);
    });

    // =====================================================================
    // Edge Case Tests (E:3)
    // =====================================================================

    test('toEntity and fromEntity roundtrip for all channels', () {
      for (final channel in NotificationChannel.values) {
        final entity = AppNotification(
          id: 'notif-${channel.name}',
          userId: 'user-001',
          channel: channel,
          title: 'Test',
          body: 'Test body',
          sentAt: now,
        );

        final model = NotificationModel.fromEntity(entity);
        final restored = model.toEntity();

        expect(restored.channel, channel);
        expect(restored.id, entity.id);
      }
    });

    test('equality is based on id only', () {
      final m1 = NotificationModel(
        id: 'notif-001', userId: 'u1', channel: 'eventApproved',
        title: 'A', body: 'B', sentAt: now, read: false, delivered: false,
      );
      final m2 = NotificationModel(
        id: 'notif-001', userId: 'u2', channel: 'eventRejected',
        title: 'C', body: 'D', sentAt: now, read: true, delivered: true,
      );

      expect(m1, equals(m2));
      expect(m1.hashCode, m2.hashCode);
    });

    test('copyWith updates specific fields', () {
      final model = NotificationModel(
        id: 'notif-001', userId: 'u1', channel: 'eventApproved',
        title: 'Original', body: 'Body', sentAt: now,
        read: false, delivered: false,
      );

      final updated = model.copyWith(read: true, delivered: true);

      expect(updated.read, isTrue);
      expect(updated.delivered, isTrue);
      expect(updated.id, model.id);
      expect(updated.title, 'Original');
    });
  });
}
