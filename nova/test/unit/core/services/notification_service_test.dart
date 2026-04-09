/// Tests for NotificationService (legacy) and NotificationChannels
///
/// Tests channel name/description mappings and service construction.

import 'package:flutter_test/flutter_test.dart';

import 'package:nova/core/services/notification_service.dart';

void main() {
  group('NotificationChannels', () {
    // =========================================================================
    // HAPPY PATH - Channel name mappings
    // =========================================================================

    group('getChannelName', () {
      test('returns correct name for eventApproved (happy)', () {
        expect(
          NotificationChannels.getChannelName(
              NotificationChannels.eventApproved),
          equals('Evento Approvato'),
        );
      });

      test('returns correct name for eventRejected (happy)', () {
        expect(
          NotificationChannels.getChannelName(
              NotificationChannels.eventRejected),
          equals('Evento Rifiutato'),
        );
      });

      test('returns correct name for all known channels (happy)', () {
        final channelNames = {
          NotificationChannels.eventApproved: 'Evento Approvato',
          NotificationChannels.eventRejected: 'Evento Rifiutato',
          NotificationChannels.newPendingEvent: 'Nuovi Eventi da Moderare',
          NotificationChannels.addedAsCoorganizer: 'Co-Organizer',
          NotificationChannels.eventModified: 'Eventi Modificati',
        };

        for (final entry in channelNames.entries) {
          expect(
            NotificationChannels.getChannelName(entry.key),
            equals(entry.value),
          );
        }
      });
    });

    // =========================================================================
    // EDGE CASES
    // =========================================================================

    group('getChannelName edge cases', () {
      test('returns default for unknown channel ID (edge)', () {
        expect(
          NotificationChannels.getChannelName('unknown_channel'),
          equals('Notifiche'),
        );
      });

      test('returns default for empty string (edge)', () {
        expect(
          NotificationChannels.getChannelName(''),
          equals('Notifiche'),
        );
      });
    });

    group('getChannelDescription', () {
      test('returns description for all known channels (happy)', () {
        for (final channelId in [
          NotificationChannels.eventApproved,
          NotificationChannels.eventRejected,
          NotificationChannels.newPendingEvent,
          NotificationChannels.addedAsCoorganizer,
          NotificationChannels.eventModified,
        ]) {
          final description =
              NotificationChannels.getChannelDescription(channelId);
          expect(description, isNotEmpty);
          expect(description, isNot(equals('Notifiche generali')));
        }
      });

      test('returns default description for unknown channel (edge)', () {
        expect(
          NotificationChannels.getChannelDescription('nonexistent'),
          equals('Notifiche generali'),
        );
      });
    });

    // =========================================================================
    // Channel constants
    // =========================================================================

    group('channel constants', () {
      test('channel IDs are non-empty strings (edge)', () {
        expect(NotificationChannels.eventApproved, isNotEmpty);
        expect(NotificationChannels.eventRejected, isNotEmpty);
        expect(NotificationChannels.newPendingEvent, isNotEmpty);
        expect(NotificationChannels.addedAsCoorganizer, isNotEmpty);
        expect(NotificationChannels.eventModified, isNotEmpty);
      });

      test('channel IDs are all unique (edge)', () {
        final ids = [
          NotificationChannels.eventApproved,
          NotificationChannels.eventRejected,
          NotificationChannels.newPendingEvent,
          NotificationChannels.addedAsCoorganizer,
          NotificationChannels.eventModified,
        ];
        expect(ids.toSet().length, equals(ids.length));
      });
    });

    // =========================================================================
    // getChannelDescription - specific channel descriptions
    // =========================================================================

    group('getChannelDescription specific values', () {
      test('eventApproved description mentions approvati', () {
        expect(
          NotificationChannels.getChannelDescription(
              NotificationChannels.eventApproved),
          equals('Notifiche quando i tuoi eventi vengono approvati'),
        );
      });

      test('eventRejected description mentions rifiutati', () {
        expect(
          NotificationChannels.getChannelDescription(
              NotificationChannels.eventRejected),
          equals('Notifiche quando i tuoi eventi vengono rifiutati'),
        );
      });

      test('newPendingEvent description mentions moderatori', () {
        expect(
          NotificationChannels.getChannelDescription(
              NotificationChannels.newPendingEvent),
          equals(
              'Notifiche per moderatori: nuovi eventi da revisionare'),
        );
      });

      test('addedAsCoorganizer description mentions co-organizer', () {
        expect(
          NotificationChannels.getChannelDescription(
              NotificationChannels.addedAsCoorganizer),
          equals(
              'Notifiche quando sei aggiunto come co-organizer'),
        );
      });

      test('eventModified description mentions modificati', () {
        expect(
          NotificationChannels.getChannelDescription(
              NotificationChannels.eventModified),
          equals(
              'Notifiche quando eventi che organizzi vengono modificati'),
        );
      });

      test('returns default description for empty string (edge)', () {
        expect(
          NotificationChannels.getChannelDescription(''),
          equals('Notifiche generali'),
        );
      });
    });

    // =========================================================================
    // Channel constant values
    // =========================================================================

    group('channel constant values', () {
      test('eventApproved has expected string value', () {
        expect(NotificationChannels.eventApproved, equals('event_approved'));
      });

      test('eventRejected has expected string value', () {
        expect(NotificationChannels.eventRejected, equals('event_rejected'));
      });

      test('newPendingEvent has expected string value', () {
        expect(
            NotificationChannels.newPendingEvent, equals('new_pending_event'));
      });

      test('addedAsCoorganizer has expected string value', () {
        expect(NotificationChannels.addedAsCoorganizer,
            equals('added_as_coorganizer'));
      });

      test('eventModified has expected string value', () {
        expect(NotificationChannels.eventModified, equals('event_modified'));
      });
    });
  });
}
