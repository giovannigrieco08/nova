import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/data/models/event_draft.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 0);
  final futureDate = DateTime.now().add(const Duration(days: 30));

  group('EventDraft', () {
    // =====================================================================
    // Happy Path Tests (H:3)
    // =====================================================================

    test('should create EventDraft with required fields and defaults', () {
      final draft = EventDraft(
        title: 'Torneo Calcetto',
        description: 'Torneo organizzato dalla classe 4A al campetto della scuola',
        lastSaved: now,
      );

      expect(draft.title, 'Torneo Calcetto');
      expect(draft.description, contains('4A'));
      expect(draft.eventDate, isNull);
      expect(draft.location, isNull);
      expect(draft.imagePath, isNull);
      expect(draft.pendingInvites, isEmpty);
      expect(draft.needsHelp, isFalse);
      expect(draft.helpRequests, isEmpty);
    });

    test('isValid returns true for complete valid draft', () {
      final draft = EventDraft(
        title: 'Valid Title Here',
        description: 'This description is long enough to pass the twenty character minimum validation.',
        eventDate: futureDate,
        lastSaved: now,
        pendingInvites: ['user-001', 'user-002'],
      );

      expect(draft.isValid, isTrue);
    });

    test('isEmpty returns true for blank draft', () {
      final empty = EventDraft(
        title: '',
        description: '',
        lastSaved: now,
      );

      expect(empty.isEmpty, isTrue);

      final nonEmpty = EventDraft(
        title: 'Something',
        description: '',
        lastSaved: now,
      );

      expect(nonEmpty.isEmpty, isFalse);
    });

    // =====================================================================
    // Edge Case Tests (E:3)
    // =====================================================================

    test('isValid returns false when title is too short or too long', () {
      final tooShort = EventDraft(
        title: 'Hi',
        description: 'This description meets the minimum length requirement easily.',
        eventDate: futureDate,
        lastSaved: now,
      );
      expect(tooShort.isValid, isFalse);

      final tooLong = EventDraft(
        title: 'A' * 101,
        description: 'This description meets the minimum length requirement easily.',
        eventDate: futureDate,
        lastSaved: now,
      );
      expect(tooLong.isValid, isFalse);
    });

    test('isValid returns false when description is too short or too long', () {
      final shortDesc = EventDraft(
        title: 'Valid Title',
        description: 'Too short',
        eventDate: futureDate,
        lastSaved: now,
      );
      expect(shortDesc.isValid, isFalse);

      final longDesc = EventDraft(
        title: 'Valid Title',
        description: 'A' * 501,
        eventDate: futureDate,
        lastSaved: now,
      );
      expect(longDesc.isValid, isFalse);
    });

    test('isValid returns false with too many pendingInvites or no eventDate', () {
      final tooManyInvites = EventDraft(
        title: 'Valid Title',
        description: 'This description meets the minimum length requirement easily.',
        eventDate: futureDate,
        lastSaved: now,
        pendingInvites: ['u1', 'u2', 'u3', 'u4'],
      );
      expect(tooManyInvites.isValid, isFalse);

      final noDate = EventDraft(
        title: 'Valid Title',
        description: 'This description meets the minimum length requirement easily.',
        lastSaved: now,
      );
      expect(noDate.isValid, isFalse);
    });
  });
}
