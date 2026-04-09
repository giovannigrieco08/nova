import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:nova/features/events/data/datasources/event_local_datasource.dart';
import 'package:nova/features/events/data/models/event_draft.dart';

// ==========================================================================
// MOCK CLASSES
// ==========================================================================

class MockBox extends Mock implements Box<EventDraft> {}

class FakeEventDraft extends Fake implements EventDraft {
  @override
  DateTime lastSaved = DateTime.now();
}

void main() {
  late EventLocalDataSource dataSource;
  late MockBox mockBox;

  setUpAll(() {
    registerFallbackValue(FakeEventDraft());
  });

  setUp(() {
    mockBox = MockBox();
    dataSource = EventLocalDataSource(mockBox);
  });

  tearDown(() {
    dataSource.dispose();
  });

  // ==========================================================================
  // Helper
  // ==========================================================================

  EventDraft _createDraft() {
    return EventDraft(
      title: 'Test Event',
      description: 'A test description for the event.',
      eventDate: DateTime.now().add(const Duration(days: 7)),
      location: 'Aula Magna',
      lastSaved: DateTime.now(),
    );
  }

  // ==========================================================================
  // saveDraft
  // ==========================================================================

  group('saveDraft', () {
    test('happy: saves draft with key current_draft', () async {
      when(() => mockBox.put(any(), any<EventDraft>()))
          .thenAnswer((_) async {});

      await dataSource.saveDraft(_createDraft());

      verify(() => mockBox.put('current_draft', any<EventDraft>())).called(1);
    });

    test('happy: updates lastSaved timestamp on save', () async {
      final draft = _createDraft();
      final beforeSave = DateTime.now();
      when(() => mockBox.put(any(), any<EventDraft>()))
          .thenAnswer((_) async {});

      await dataSource.saveDraft(draft);

      expect(draft.lastSaved.isAfter(beforeSave.subtract(const Duration(seconds: 1))), isTrue);
    });

    test('edge: wraps Hive error in LocalDataSourceException', () async {
      when(() => mockBox.put(any(), any<EventDraft>()))
          .thenThrow(HiveError('Disk full'));

      expect(
        () => dataSource.saveDraft(_createDraft()),
        throwsA(isA<LocalDataSourceException>()),
      );
    });
  });

  // ==========================================================================
  // getDraft
  // ==========================================================================

  group('getDraft', () {
    test('happy: returns draft when it exists', () {
      final draft = _createDraft();
      when(() => mockBox.get('current_draft')).thenReturn(draft);

      final result = dataSource.getDraft();

      expect(result, isNotNull);
      expect(result!.title, 'Test Event');
    });

    test('edge: returns null when no draft exists', () {
      when(() => mockBox.get('current_draft')).thenReturn(null);

      final result = dataSource.getDraft();

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // deleteDraft
  // ==========================================================================

  group('deleteDraft', () {
    test('happy: deletes draft and cancels debounce timer', () async {
      when(() => mockBox.delete('current_draft')).thenAnswer((_) async {});

      await dataSource.deleteDraft();

      verify(() => mockBox.delete('current_draft')).called(1);
    });

    test('edge: wraps Hive error in LocalDataSourceException', () async {
      when(() => mockBox.delete(any())).thenThrow(HiveError('Corruption'));

      expect(
        () => dataSource.deleteDraft(),
        throwsA(isA<LocalDataSourceException>()),
      );
    });
  });

  // ==========================================================================
  // hasDraft
  // ==========================================================================

  group('hasDraft', () {
    test('happy: returns true when draft exists', () {
      when(() => mockBox.containsKey('current_draft')).thenReturn(true);

      expect(dataSource.hasDraft(), isTrue);
    });

    test('edge: returns false when no draft', () {
      when(() => mockBox.containsKey('current_draft')).thenReturn(false);

      expect(dataSource.hasDraft(), isFalse);
    });
  });

  // ==========================================================================
  // getDraftAge
  // ==========================================================================

  group('getDraftAge', () {
    test('happy: returns duration since last save', () {
      final draft = _createDraft();
      draft.lastSaved = DateTime.now().subtract(const Duration(minutes: 5));
      when(() => mockBox.get('current_draft')).thenReturn(draft);

      final age = dataSource.getDraftAge();

      expect(age, isNotNull);
      expect(age!.inMinutes, greaterThanOrEqualTo(4));
      expect(age.inMinutes, lessThanOrEqualTo(6));
    });

    test('edge: returns null when no draft', () {
      when(() => mockBox.get('current_draft')).thenReturn(null);

      expect(dataSource.getDraftAge(), isNull);
    });
  });

  // ==========================================================================
  // clearAllDrafts
  // ==========================================================================

  group('clearAllDrafts', () {
    test('happy: clears all drafts from Hive box', () async {
      when(() => mockBox.clear()).thenAnswer((_) async => 0);

      await dataSource.clearAllDrafts();

      verify(() => mockBox.clear()).called(1);
    });
  });
}
