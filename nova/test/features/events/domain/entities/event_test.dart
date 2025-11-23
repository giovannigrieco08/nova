// =====================================================================
// Nova - Event Entity Unit Tests
// =====================================================================
// Purpose: Test Event entity with business logic and serialization
// Architecture: Tests isApproved, isUpcoming, formattedDateTime, equality
// =====================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/domain/entities/event.dart';
import 'package:nova/features/events/domain/entities/event_status.dart';

// =====================================================================
// Test Helper Functions
// =====================================================================

/// Create test Event with default values
Event createTestEvent({
  String id = 'test-event-id',
  String title = 'Test Event',
  String description = 'This is a test event description',
  DateTime? eventDate,
  String? location,
  String? imageUrl,
  String creatorId = 'test-creator-id',
  List<String> coOrganizers = const [],
  EventStatus status = EventStatus.approved,
  String? rejectionReason,
  String? moderatedBy,
  DateTime? moderatedAt,
  DateTime? createdAt,
  DateTime? updatedAt,
  int submissionCount = 1,
}) {
  final now = DateTime.now();
  return Event(
    id: id,
    title: title,
    description: description,
    eventDate: eventDate ?? now.add(const Duration(days: 7)),
    location: location,
    imageUrl: imageUrl,
    creatorId: creatorId,
    coOrganizers: coOrganizers,
    status: status,
    rejectionReason: rejectionReason,
    moderatedBy: moderatedBy,
    moderatedAt: moderatedAt,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
    submissionCount: submissionCount,
  );
}

// =====================================================================
// Test Suite
// =====================================================================

void main() {
  group('Event', () {
    // =================================================================
    // isApproved Tests
    // =================================================================

    group('isApproved', () {
      test('returns true when status is approved', () {
        // Arrange
        final event = createTestEvent(status: EventStatus.approved);

        // Act
        final result = event.isApproved;

        // Assert
        expect(result, true);
      });

      test('returns false when status is pending', () {
        // Arrange
        final event = createTestEvent(status: EventStatus.pending);

        // Act
        final result = event.isApproved;

        // Assert
        expect(result, false);
      });

      test('returns false when status is rejected', () {
        // Arrange
        final event = createTestEvent(status: EventStatus.rejected);

        // Act
        final result = event.isApproved;

        // Assert
        expect(result, false);
      });
    });

    // =================================================================
    // isUpcoming Tests
    // =================================================================

    group('isUpcoming', () {
      test('returns true when event date is in the future', () {
        // Arrange
        final futureDate = DateTime.now().add(const Duration(days: 7));
        final event = createTestEvent(eventDate: futureDate);

        // Act
        final result = event.isUpcoming;

        // Assert
        expect(result, true);
      });

      test('returns true when event date is today', () {
        // Arrange
        final today = DateTime.now();
        final todayEvent = DateTime(today.year, today.month, today.day, 14, 30);
        final event = createTestEvent(eventDate: todayEvent);

        // Act
        final result = event.isUpcoming;

        // Assert
        expect(result, true);
      });

      test('returns false when event date is in the past', () {
        // Arrange
        final pastDate = DateTime.now().subtract(const Duration(days: 7));
        final event = createTestEvent(eventDate: pastDate);

        // Act
        final result = event.isUpcoming;

        // Assert
        expect(result, false);
      });

      test('returns false when event date is yesterday', () {
        // Arrange
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final event = createTestEvent(eventDate: yesterday);

        // Act
        final result = event.isUpcoming;

        // Assert
        expect(result, false);
      });
    });

    // =================================================================
    // formattedDateTime Tests
    // =================================================================

    group('formattedDateTime', () {
      test('returns correct Italian format for February', () {
        // Arrange
        final eventDate = DateTime(2025, 2, 15, 14, 30);
        final event = createTestEvent(eventDate: eventDate);

        // Act
        final result = event.formattedDateTime;

        // Assert
        expect(result, '15 Feb 2025 alle 14:30');
      });

      test('returns correct Italian format for January', () {
        // Arrange
        final eventDate = DateTime(2025, 1, 5, 9, 0);
        final event = createTestEvent(eventDate: eventDate);

        // Act
        final result = event.formattedDateTime;

        // Assert
        expect(result, '5 Gen 2025 alle 09:00');
      });

      test('returns correct Italian format for December', () {
        // Arrange
        final eventDate = DateTime(2025, 12, 31, 23, 59);
        final event = createTestEvent(eventDate: eventDate);

        // Act
        final result = event.formattedDateTime;

        // Assert
        expect(result, '31 Dic 2025 alle 23:59');
      });

      test('pads single digit hours and minutes', () {
        // Arrange
        final eventDate = DateTime(2025, 3, 8, 8, 5);
        final event = createTestEvent(eventDate: eventDate);

        // Act
        final result = event.formattedDateTime;

        // Assert
        expect(result, '8 Mar 2025 alle 08:05');
      });

      test('handles all 12 months correctly', () {
        // Arrange & Act & Assert
        final months = [
          'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
          'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'
        ];

        for (var i = 0; i < 12; i++) {
          final eventDate = DateTime(2025, i + 1, 15, 12, 0);
          final event = createTestEvent(eventDate: eventDate);
          final result = event.formattedDateTime;
          expect(result, '15 ${months[i]} 2025 alle 12:00');
        }
      });
    });

    // =================================================================
    // Equality Tests
    // =================================================================

    group('equality', () {
      test('two identical events are equal', () {
        // Arrange
        final eventDate = DateTime(2025, 3, 15, 14, 30);
        final createdAt = DateTime(2025, 3, 1, 10, 0);
        final updatedAt = DateTime(2025, 3, 1, 10, 0);

        final event1 = Event(
          id: 'same-id',
          title: 'Same Event',
          description: 'Same description',
          eventDate: eventDate,
          creatorId: 'creator-1',
          status: EventStatus.approved,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        final event2 = Event(
          id: 'same-id',
          title: 'Same Event',
          description: 'Same description',
          eventDate: eventDate,
          creatorId: 'creator-1',
          status: EventStatus.approved,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        // Act & Assert
        expect(event1, equals(event2));
      });

      test('two events with different titles are not equal', () {
        // Arrange
        final eventDate = DateTime(2025, 3, 15, 14, 30);
        final createdAt = DateTime(2025, 3, 1, 10, 0);

        final event1 = Event(
          id: 'same-id',
          title: 'Event 1',
          description: 'Same description',
          eventDate: eventDate,
          creatorId: 'creator-1',
          status: EventStatus.approved,
          createdAt: createdAt,
          updatedAt: createdAt,
        );

        final event2 = Event(
          id: 'same-id',
          title: 'Event 2',
          description: 'Same description',
          eventDate: eventDate,
          creatorId: 'creator-1',
          status: EventStatus.approved,
          createdAt: createdAt,
          updatedAt: createdAt,
        );

        // Act & Assert
        expect(event1, isNot(equals(event2)));
      });

      test('identical events have same hashCode', () {
        // Arrange
        final eventDate = DateTime(2025, 3, 15, 14, 30);
        final createdAt = DateTime(2025, 3, 1, 10, 0);

        final event1 = Event(
          id: 'same-id',
          title: 'Same Event',
          description: 'Same description',
          eventDate: eventDate,
          creatorId: 'creator-1',
          status: EventStatus.approved,
          createdAt: createdAt,
          updatedAt: createdAt,
        );

        final event2 = Event(
          id: 'same-id',
          title: 'Same Event',
          description: 'Same description',
          eventDate: eventDate,
          creatorId: 'creator-1',
          status: EventStatus.approved,
          createdAt: createdAt,
          updatedAt: createdAt,
        );

        // Act & Assert
        expect(event1.hashCode, equals(event2.hashCode));
      });

      test('different events have different hashCode', () {
        // Arrange
        final event1 = createTestEvent(id: 'id-1', title: 'Event 1');
        final event2 = createTestEvent(id: 'id-2', title: 'Event 2');

        // Act & Assert
        expect(event1.hashCode, isNot(equals(event2.hashCode)));
      });
    });

    // =================================================================
    // JSON Serialization Tests
    // =================================================================

    group('JSON serialization', () {
      test('fromJson creates Event from valid JSON', () {
        // Arrange
        final json = {
          'id': 'event-123',
          'title': 'Test Event',
          'description': 'Test Description',
          'eventDate': '2025-03-15T14:30:00.000Z',
          'location': 'School Auditorium',
          'imageUrl': 'https://example.com/image.jpg',
          'creatorId': 'creator-456',
          'coOrganizers': ['co-org-1', 'co-org-2'],
          'status': 'approved',
          'rejectionReason': null,
          'moderatedBy': 'moderator-789',
          'moderatedAt': '2025-03-10T10:00:00.000Z',
          'createdAt': '2025-03-09T08:00:00.000Z',
          'updatedAt': '2025-03-09T08:00:00.000Z',
          'submissionCount': 1,
        };

        // Act
        final event = Event.fromJson(json);

        // Assert
        expect(event.id, 'event-123');
        expect(event.title, 'Test Event');
        expect(event.description, 'Test Description');
        expect(event.location, 'School Auditorium');
        expect(event.imageUrl, 'https://example.com/image.jpg');
        expect(event.creatorId, 'creator-456');
        expect(event.coOrganizers, ['co-org-1', 'co-org-2']);
        expect(event.status, EventStatus.approved);
        expect(event.submissionCount, 1);
      });

      test('fromJson handles optional fields as null', () {
        // Arrange
        final json = {
          'id': 'event-123',
          'title': 'Minimal Event',
          'description': 'Minimal Description',
          'eventDate': '2025-03-15T14:30:00.000Z',
          'location': null,
          'imageUrl': null,
          'creatorId': 'creator-456',
          'coOrganizers': [],
          'status': 'pending',
          'rejectionReason': null,
          'moderatedBy': null,
          'moderatedAt': null,
          'createdAt': '2025-03-09T08:00:00.000Z',
          'updatedAt': '2025-03-09T08:00:00.000Z',
          'submissionCount': 1,
        };

        // Act
        final event = Event.fromJson(json);

        // Assert
        expect(event.location, null);
        expect(event.imageUrl, null);
        expect(event.rejectionReason, null);
        expect(event.moderatedBy, null);
        expect(event.moderatedAt, null);
        expect(event.coOrganizers, isEmpty);
      });

      test('toJson creates valid JSON from Event', () {
        // Arrange
        final event = Event(
          id: 'event-123',
          title: 'Test Event',
          description: 'Test Description',
          eventDate: DateTime.parse('2025-03-15T14:30:00.000Z'),
          location: 'School Auditorium',
          imageUrl: 'https://example.com/image.jpg',
          creatorId: 'creator-456',
          coOrganizers: const ['co-org-1', 'co-org-2'],
          status: EventStatus.approved,
          rejectionReason: null,
          moderatedBy: 'moderator-789',
          moderatedAt: DateTime.parse('2025-03-10T10:00:00.000Z'),
          createdAt: DateTime.parse('2025-03-09T08:00:00.000Z'),
          updatedAt: DateTime.parse('2025-03-09T08:00:00.000Z'),
          submissionCount: 1,
        );

        // Act
        final json = event.toJson();

        // Assert
        expect(json['id'], 'event-123');
        expect(json['title'], 'Test Event');
        expect(json['description'], 'Test Description');
        expect(json['eventDate'], '2025-03-15T14:30:00.000Z');
        expect(json['location'], 'School Auditorium');
        expect(json['imageUrl'], 'https://example.com/image.jpg');
        expect(json['creatorId'], 'creator-456');
        expect(json['coOrganizers'], ['co-org-1', 'co-org-2']);
        expect(json['status'], 'approved');
        expect(json['submissionCount'], 1);
      });

      test('fromJson then toJson preserves data', () {
        // Arrange
        final originalJson = {
          'id': 'event-123',
          'title': 'Test Event',
          'description': 'Test Description',
          'eventDate': '2025-03-15T14:30:00.000Z',
          'location': 'School Auditorium',
          'imageUrl': 'https://example.com/image.jpg',
          'creatorId': 'creator-456',
          'coOrganizers': ['co-org-1'],
          'status': 'approved',
          'rejectionReason': null,
          'moderatedBy': 'moderator-789',
          'moderatedAt': '2025-03-10T10:00:00.000Z',
          'createdAt': '2025-03-09T08:00:00.000Z',
          'updatedAt': '2025-03-09T08:00:00.000Z',
          'submissionCount': 1,
        };

        // Act
        final event = Event.fromJson(originalJson);
        final resultJson = event.toJson();

        // Assert
        expect(resultJson['id'], originalJson['id']);
        expect(resultJson['title'], originalJson['title']);
        expect(resultJson['description'], originalJson['description']);
        expect(resultJson['status'], originalJson['status']);
      });

      test('fromJson handles all three event statuses', () {
        // Arrange & Act & Assert
        final statuses = ['pending', 'approved', 'rejected'];
        final expectedStatuses = [
          EventStatus.pending,
          EventStatus.approved,
          EventStatus.rejected
        ];

        for (var i = 0; i < statuses.length; i++) {
          final json = {
            'id': 'event-$i',
            'title': 'Test',
            'description': 'Test',
            'eventDate': '2025-03-15T14:30:00.000Z',
            'creatorId': 'creator',
            'coOrganizers': [],
            'status': statuses[i],
            'createdAt': '2025-03-09T08:00:00.000Z',
            'updatedAt': '2025-03-09T08:00:00.000Z',
            'submissionCount': 1,
          };

          final event = Event.fromJson(json);
          expect(event.status, expectedStatuses[i]);
        }
      });
    });

    // =================================================================
    // Freezed copyWith Tests
    // =================================================================

    group('copyWith', () {
      test('copyWith creates new instance with updated fields', () {
        // Arrange
        final original = createTestEvent(
          id: 'event-1',
          title: 'Original Title',
          status: EventStatus.pending,
        );

        // Act
        final updated = original.copyWith(
          title: 'Updated Title',
          status: EventStatus.approved,
        );

        // Assert
        expect(updated.id, 'event-1'); // Unchanged
        expect(updated.title, 'Updated Title'); // Changed
        expect(updated.status, EventStatus.approved); // Changed
      });

      test('copyWith preserves unchanged fields', () {
        // Arrange
        final original = createTestEvent(
          id: 'event-1',
          title: 'Original Title',
          description: 'Original Description',
          creatorId: 'creator-1',
        );

        // Act
        final updated = original.copyWith(title: 'New Title');

        // Assert
        expect(updated.id, 'event-1');
        expect(updated.title, 'New Title');
        expect(updated.description, 'Original Description');
        expect(updated.creatorId, 'creator-1');
      });
    });

    // =================================================================
    // Edge Cases and Integration Tests
    // =================================================================

    group('edge cases', () {
      test('event with empty co-organizers list', () {
        // Arrange & Act
        final event = createTestEvent(coOrganizers: []);

        // Assert
        expect(event.coOrganizers, isEmpty);
      });

      test('event with maximum co-organizers (3)', () {
        // Arrange & Act
        final event = createTestEvent(
          coOrganizers: ['co-org-1', 'co-org-2', 'co-org-3'],
        );

        // Assert
        expect(event.coOrganizers.length, 3);
      });

      test('rejected event has rejection reason', () {
        // Arrange & Act
        final event = createTestEvent(
          status: EventStatus.rejected,
          rejectionReason: 'Inappropriate content',
        );

        // Assert
        expect(event.status, EventStatus.rejected);
        expect(event.rejectionReason, 'Inappropriate content');
        expect(event.isApproved, false);
      });

      test('event with submission count greater than 1', () {
        // Arrange & Act
        final event = createTestEvent(submissionCount: 3);

        // Assert
        expect(event.submissionCount, 3);
      });

      test('event date at midnight is considered today', () {
        // Arrange
        final today = DateTime.now();
        final midnight = DateTime(today.year, today.month, today.day, 0, 0);
        final event = createTestEvent(eventDate: midnight);

        // Act
        final result = event.isUpcoming;

        // Assert
        expect(result, true);
      });

      test('event date one second before midnight yesterday is past', () {
        // Arrange
        final yesterday = DateTime.now().subtract(const Duration(days: 1));
        final almostMidnight =
            DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
        final event = createTestEvent(eventDate: almostMidnight);

        // Act
        final result = event.isUpcoming;

        // Assert
        expect(result, false);
      });
    });
  });
}
