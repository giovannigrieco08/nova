import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/domain/entities/event.dart';
import 'package:nova/features/events/domain/entities/event_status.dart';
import '../../../../../fixtures/test_fixtures.dart';

void main() {
  group('Event Entity', () {
    // =====================================================================
    // Happy Path Tests (H:5)
    // =====================================================================

    test('should create Event with all required fields', () {
      final now = DateTime(2025, 6, 15, 14, 30);
      final event = Event(
        id: 'event-001',
        title: 'Torneo di Calcetto',
        description: 'Torneo di calcetto organizzato dalla 4A',
        eventDate: now,
        creatorId: TestUserIds.student1,
        status: EventStatus.approved,
        createdAt: now,
        updatedAt: now,
      );

      expect(event.id, 'event-001');
      expect(event.title, 'Torneo di Calcetto');
      expect(event.description, 'Torneo di calcetto organizzato dalla 4A');
      expect(event.eventDate, now);
      expect(event.creatorId, TestUserIds.student1);
      expect(event.status, EventStatus.approved);
      expect(event.coOrganizers, isEmpty);
      expect(event.location, isNull);
      expect(event.imageUrl, isNull);
      expect(event.rejectionReason, isNull);
    });

    test('isApproved returns true only for approved events', () {
      final approved = TestEvents.approvedEvent();
      final pending = TestEvents.pendingEvent();
      final rejected = TestEvents.rejectedEvent();

      expect(approved.isApproved, isTrue);
      expect(pending.isApproved, isFalse);
      expect(rejected.isApproved, isFalse);
    });

    test('isUpcoming returns true for future event dates', () {
      final futureEvent = TestEvents.approvedEvent(
        eventDate: DateTime.now().add(const Duration(days: 30)),
      );

      expect(futureEvent.isUpcoming, isTrue);
    });

    test('formattedDateTime formats date in Italian style', () {
      final event = TestEvents.approvedEvent(
        eventDate: DateTime(2025, 2, 15, 14, 30),
      );

      expect(event.formattedDateTime, '15 Feb 2025 alle 14:30');
    });

    test('hasMapLocation and googleMapsUrl work with coordinates', () {
      final now = DateTime(2025, 6, 15);
      final event = Event(
        id: 'event-map',
        title: 'Test Map Event',
        description: 'Event with map coordinates',
        eventDate: now,
        creatorId: TestUserIds.student1,
        status: EventStatus.approved,
        createdAt: now,
        updatedAt: now,
        latitude: 45.4642,
        longitude: 9.1900,
      );

      expect(event.hasMapLocation, isTrue);
      expect(event.googleMapsUrl, contains('45.4642'));
      expect(event.googleMapsUrl, contains('9.19'));
    });

    // =====================================================================
    // Edge Case Tests (E:4)
    // =====================================================================

    test('isUpcoming returns false for past event dates', () {
      final pastEvent = TestEvents.approvedEvent(
        eventDate: DateTime(2020, 1, 1),
      );

      expect(pastEvent.isUpcoming, isFalse);
    });

    test('hasMapLocation returns false when coordinates are null', () {
      final event = TestEvents.approvedEvent();
      // Default event from fixtures has no lat/lng

      expect(event.hasMapLocation, isFalse);
      expect(event.googleMapsUrl, isNull);
    });

    test('coOrganizers defaults to empty list', () {
      final now = DateTime(2025, 6, 15);
      final event = Event(
        id: 'event-no-coorg',
        title: 'Solo Event',
        description: 'No co-organizers here',
        eventDate: now,
        creatorId: TestUserIds.student1,
        status: EventStatus.pending,
        createdAt: now,
        updatedAt: now,
      );

      expect(event.coOrganizers, isEmpty);
      expect(event.coOrganizers, isA<List<String>>());
    });

    test('formattedDateTime pads single-digit hours and minutes', () {
      final event = TestEvents.approvedEvent(
        eventDate: DateTime(2025, 1, 5, 8, 5),
      );

      expect(event.formattedDateTime, '5 Gen 2025 alle 08:05');
    });
  });
}
