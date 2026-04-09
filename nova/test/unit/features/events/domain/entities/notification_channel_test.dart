import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/domain/entities/notification_channel.dart';

void main() {
  group('NotificationChannel', () {
    // =====================================================================
    // Happy Path Tests (H:2)
    // =====================================================================

    test('should have all six notification channel values', () {
      expect(NotificationChannel.values.length, 6);
      expect(NotificationChannel.values, contains(NotificationChannel.eventApproved));
      expect(NotificationChannel.values, contains(NotificationChannel.eventRejected));
      expect(NotificationChannel.values, contains(NotificationChannel.newPendingEvent));
      expect(NotificationChannel.values, contains(NotificationChannel.addedAsCoorganizer));
      expect(NotificationChannel.values, contains(NotificationChannel.eventModified));
      expect(NotificationChannel.values, contains(NotificationChannel.eventInvitation));
    });

    test('label returns correct Italian labels', () {
      expect(NotificationChannel.eventApproved.label, 'Evento Approvato');
      expect(NotificationChannel.eventRejected.label, 'Evento Rifiutato');
      expect(NotificationChannel.newPendingEvent.label, 'Nuovo Evento Pendente');
      expect(NotificationChannel.addedAsCoorganizer.label, 'Aggiunto come Co-Organizzatore');
      expect(NotificationChannel.eventModified.label, 'Evento Modificato');
      expect(NotificationChannel.eventInvitation.label, 'Invito a Collaborare');
    });

    // =====================================================================
    // Edge Case Tests (E:2)
    // =====================================================================

    test('importance levels are correctly assigned', () {
      expect(NotificationChannel.eventApproved.importance, NotificationImportance.high);
      expect(NotificationChannel.eventRejected.importance, NotificationImportance.high);
      expect(NotificationChannel.newPendingEvent.importance, NotificationImportance.low);
      expect(NotificationChannel.addedAsCoorganizer.importance, NotificationImportance.high);
      expect(NotificationChannel.eventModified.importance, NotificationImportance.default_);
      expect(NotificationChannel.eventInvitation.importance, NotificationImportance.high);
    });

    test('canOptOut is false for core moderation channels, true for optional ones', () {
      // Cannot opt out
      expect(NotificationChannel.eventApproved.canOptOut, isFalse);
      expect(NotificationChannel.eventRejected.canOptOut, isFalse);

      // Can opt out
      expect(NotificationChannel.newPendingEvent.canOptOut, isTrue);
      expect(NotificationChannel.addedAsCoorganizer.canOptOut, isTrue);
      expect(NotificationChannel.eventModified.canOptOut, isTrue);
      expect(NotificationChannel.eventInvitation.canOptOut, isTrue);
    });
  });
}
