import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/domain/entities/event_status.dart';
import 'package:nova/features/moderation/data/models/moderation_event.dart';

void main() {
  ModerationEvent createEvent({
    String id = 'evt-001',
    String title = 'Test Event',
    String description = 'A test event description for testing.',
    String? emojiIcon = '\ud83c\udf89',
    String? coverImageUrl,
    String category = 'sociale',
    DateTime? startDate,
    DateTime? endDate,
    String? location = 'Aula Magna',
    String? organizerName = 'Mario Rossi',
    DateTime? createdAt,
    String creatorId = 'user-001',
    EventStatus status = EventStatus.pending,
    int submissionCount = 1,
    String? rejectionReason,
  }) {
    return ModerationEvent(
      id: id,
      title: title,
      description: description,
      emojiIcon: emojiIcon,
      coverImageUrl: coverImageUrl,
      category: category,
      startDate: startDate ?? DateTime(2025, 7, 15, 10, 0),
      endDate: endDate,
      location: location,
      organizerName: organizerName,
      createdAt: createdAt ?? DateTime(2025, 6, 1, 8, 0),
      creatorId: creatorId,
      status: status,
      submissionCount: submissionCount,
      rejectionReason: rejectionReason,
    );
  }

  group('ModerationEvent', () {
    // ===================== HAPPY PATH =====================

    test('creates with all fields and defaults', () {
      final event = createEvent();

      expect(event.id, 'evt-001');
      expect(event.title, 'Test Event');
      expect(event.emojiIcon, '\ud83c\udf89');
      expect(event.category, 'sociale');
      expect(event.location, 'Aula Magna');
      expect(event.organizerName, 'Mario Rossi');
      expect(event.status, EventStatus.pending);
      expect(event.submissionCount, 1);
      expect(event.isResubmission, false);
    });

    test('isResubmission returns true when submissionCount > 1', () {
      final event = createEvent(submissionCount: 2);
      expect(event.isResubmission, true);
    });

    test('formattedDateRange formats single-time event', () {
      final event = createEvent(
        startDate: DateTime(2025, 7, 15, 10, 30),
        endDate: null,
      );

      expect(event.formattedDateRange, '15 Lug 2025 alle 10:30');
    });

    test('formattedDateRange formats same-day time range', () {
      final event = createEvent(
        startDate: DateTime(2025, 7, 15, 10, 0),
        endDate: DateTime(2025, 7, 15, 18, 0),
      );

      expect(event.formattedDateRange,
          '15 Lug 2025 dalle 10:00 alle 18:00');
    });

    test('formattedDateRange formats multi-day event', () {
      final event = createEvent(
        startDate: DateTime(2025, 7, 15, 10, 0),
        endDate: DateTime(2025, 7, 20, 18, 0),
      );

      expect(event.formattedDateRange, '15 Lug - 20 Lug 2025');
    });

    test('descriptionPreview truncates long descriptions', () {
      final longDesc = 'A' * 200;
      final event = createEvent(description: longDesc);

      expect(event.descriptionPreview.length, 150);
      expect(event.descriptionPreview.endsWith('...'), true);
    });

    test('descriptionPreview returns full text when short', () {
      final event = createEvent(description: 'Short text');
      expect(event.descriptionPreview, 'Short text');
    });

    // ===================== EDGE CASES =====================

    test('defaults status to pending', () {
      final event = ModerationEvent(
        id: 'e1',
        title: 'T',
        description: 'D',
        category: 'sport',
        startDate: DateTime(2025, 7, 1),
        createdAt: DateTime(2025, 6, 1),
        creatorId: 'u1',
      );

      expect(event.status, EventStatus.pending);
      expect(event.submissionCount, 1);
    });

    test('freezed equality compares all fields', () {
      final a = createEvent();
      final b = createEvent();

      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);

      final c = createEvent(title: 'Different');
      expect(a, isNot(equals(c)));
    });

    test('timeSinceSubmission returns human-readable time', () {
      // We test the method exists and returns a string
      // Exact values depend on DateTime.now() so we just verify format
      final event = createEvent(
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      );
      expect(event.timeSinceSubmission, contains('ore fa'));

      final recentEvent = createEvent(
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      expect(recentEvent.timeSinceSubmission, contains('minuti fa'));
    });
  });
}
