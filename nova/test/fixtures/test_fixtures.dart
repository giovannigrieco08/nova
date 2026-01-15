/// Test fixtures for Nova app
///
/// Provides reusable test data for unit, widget, and integration tests.
/// All fixtures use consistent IDs and data to ensure test reproducibility.

import 'package:nova/features/events/domain/entities/event.dart';
import 'package:nova/features/events/domain/entities/event_status.dart';

/// Test user IDs
class TestUserIds {
  static const String student1 = 'test-student-001';
  static const String student2 = 'test-student-002';
  static const String moderator = 'test-moderator-001';
  static const String admin = 'test-admin-001';

  TestUserIds._();
}

/// Test user emails
class TestUserEmails {
  static const String student1 = 'mario.rossi@galileimoro.edu.it';
  static const String student2 = 'lucia.bianchi@galileimoro.edu.it';
  static const String moderator = 'moderatore@galileimoro.edu.it';
  static const String admin = 'admin@galileimoro.edu.it';

  TestUserEmails._();
}

/// Test event fixtures
class TestEvents {
  /// Create a sample approved event
  static Event approvedEvent({
    String? id,
    String? creatorId,
    String? title,
    DateTime? eventDate,
  }) {
    return Event(
      id: id ?? 'test-event-001',
      title: title ?? 'Test Event Title',
      description: 'This is a test event description for testing purposes.',
      creatorId: creatorId ?? TestUserIds.student1,
      creatorName: 'Mario Rossi',
      creatorClass: '4A',
      eventDate: eventDate ?? DateTime.now().add(const Duration(days: 7)),
      location: 'Aula Magna',
      imageUrl: 'https://example.com/test-image.jpg',
      status: EventStatus.approved,
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      updatedAt: DateTime.now(),
    );
  }

  /// Create a sample pending event
  static Event pendingEvent({
    String? id,
    String? creatorId,
  }) {
    return Event(
      id: id ?? 'test-event-pending-001',
      title: 'Pending Event',
      description: 'This event is awaiting moderation approval.',
      creatorId: creatorId ?? TestUserIds.student1,
      creatorName: 'Mario Rossi',
      creatorClass: '4A',
      eventDate: DateTime.now().add(const Duration(days: 14)),
      location: 'Biblioteca',
      status: EventStatus.pending,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Create a sample rejected event
  static Event rejectedEvent({
    String? id,
    String? rejectionReason,
  }) {
    return Event(
      id: id ?? 'test-event-rejected-001',
      title: 'Rejected Event',
      description: 'This event was rejected by moderators.',
      creatorId: TestUserIds.student2,
      creatorName: 'Lucia Bianchi',
      creatorClass: '3B',
      eventDate: DateTime.now().add(const Duration(days: 30)),
      location: 'Cortile',
      status: EventStatus.rejected,
      rejectionReason: rejectionReason ?? 'Contenuto inappropriato',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
    );
  }

  /// Create a list of sample events for feed testing
  static List<Event> sampleFeed({int count = 10}) {
    return List.generate(count, (index) {
      return approvedEvent(
        id: 'test-event-$index',
        title: 'Test Event $index',
        eventDate: DateTime.now().add(Duration(days: index + 1)),
      );
    });
  }

  TestEvents._();
}
