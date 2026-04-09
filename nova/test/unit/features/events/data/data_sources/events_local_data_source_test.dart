import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nova/features/events/data/data_sources/events_local_data_source.dart';
import 'package:nova/features/events/data/models/event_model.dart';
import 'package:nova/features/events/domain/entities/offline_action.dart';

class MockEventsBox extends Mock implements Box<EventModel> {}

class MockOfflineActionsBox extends Mock implements Box<OfflineAction> {}

/// Helper to create a minimal EventModel for testing.
EventModel _makeEvent(String id, {DateTime? createdAt}) {
  final now = createdAt ?? DateTime(2025, 1, 1);
  return EventModel(
    id: id,
    title: 'Event $id',
    description: 'Description $id',
    eventDate: now,
    creatorId: 'creator-1',
    coOrganizers: const [],
    status: 'approved',
    createdAt: now,
    updatedAt: now,
  );
}

/// Helper to create a minimal OfflineAction for testing.
OfflineAction _makeAction(
  String id, {
  DateTime? queuedAt,
  int retryCount = 0,
}) {
  return OfflineAction(
    id: id,
    type: 'like_event',
    payload: const {'event_id': 'e1'},
    queuedAt: queuedAt ?? DateTime(2025, 1, 1),
    retryCount: retryCount,
  );
}

void main() {
  late MockEventsBox eventsBox;
  late MockOfflineActionsBox offlineActionsBox;
  late EventsLocalDataSource dataSource;

  setUpAll(() {
    registerFallbackValue(_makeEvent('fallback'));
    registerFallbackValue(_makeAction('fallback'));
  });

  setUp(() {
    eventsBox = MockEventsBox();
    offlineActionsBox = MockOfflineActionsBox();
    dataSource = EventsLocalDataSource(
      eventsBox: eventsBox,
      offlineActionsBox: offlineActionsBox,
    );
  });

  // ==========================================================================
  // EVENTS CACHE OPERATIONS
  // ==========================================================================

  group('getCachedEvents', () {
    test('returns events sorted by createdAt descending', () async {
      final older = _makeEvent('1', createdAt: DateTime(2025, 1, 1));
      final newer = _makeEvent('2', createdAt: DateTime(2025, 6, 1));
      when(() => eventsBox.values).thenReturn([older, newer]);

      final result = await dataSource.getCachedEvents();

      expect(result, [newer, older]);
    });

    test('returns empty list when no cached events', () async {
      when(() => eventsBox.values).thenReturn([]);

      final result = await dataSource.getCachedEvents();

      expect(result, isEmpty);
    });
  });

  group('getCachedEventsPaginated', () {
    test('returns correct page slice', () async {
      final events = List.generate(
        5,
        (i) => _makeEvent('$i', createdAt: DateTime(2025, 1, 5 - i)),
      );
      when(() => eventsBox.values).thenReturn(events);

      // events are sorted newest first: indices 0,1,2,3,4
      final page1 = await dataSource.getCachedEventsPaginated(page: 1, limit: 2);
      final page2 = await dataSource.getCachedEventsPaginated(page: 2, limit: 2);
      final page3 = await dataSource.getCachedEventsPaginated(page: 3, limit: 2);

      expect(page1.length, 2);
      expect(page2.length, 2);
      expect(page3.length, 1); // last page partial
    });

    test('returns empty list when page exceeds cache size', () async {
      when(() => eventsBox.values).thenReturn([_makeEvent('1')]);

      final result =
          await dataSource.getCachedEventsPaginated(page: 5, limit: 10);

      expect(result, isEmpty);
    });
  });

  group('saveEventsToCache', () {
    test('clears box and saves events', () async {
      final events = [_makeEvent('1'), _makeEvent('2')];
      when(() => eventsBox.clear()).thenAnswer((_) async => 0);
      when(() => eventsBox.put(any<dynamic>(), any<EventModel>()))
          .thenAnswer((_) async {});

      await dataSource.saveEventsToCache(events);

      verify(() => eventsBox.clear()).called(1);
      verify(() => eventsBox.put('1', events[0])).called(1);
      verify(() => eventsBox.put('2', events[1])).called(1);
    });

    test('limits cache to 100 events', () async {
      final events = List.generate(
        120,
        (i) => _makeEvent('$i'),
      );
      when(() => eventsBox.clear()).thenAnswer((_) async => 0);
      when(() => eventsBox.put(any<dynamic>(), any<EventModel>()))
          .thenAnswer((_) async {});

      await dataSource.saveEventsToCache(events);

      // Should call put exactly 100 times, not 120
      verify(() => eventsBox.put(any<dynamic>(), any<EventModel>()))
          .called(100);
    });
  });

  group('updateEventInCache', () {
    test('puts event with its id as key', () async {
      final event = _makeEvent('e1');
      when(() => eventsBox.put('e1', event)).thenAnswer((_) async {});

      await dataSource.updateEventInCache(event);

      verify(() => eventsBox.put('e1', event)).called(1);
    });
  });

  group('removeEventFromCache', () {
    test('deletes event by id', () async {
      when(() => eventsBox.delete('e1')).thenAnswer((_) async {});

      await dataSource.removeEventFromCache('e1');

      verify(() => eventsBox.delete('e1')).called(1);
    });
  });

  group('getCachedEventById', () {
    test('returns event when found', () async {
      final event = _makeEvent('e1');
      when(() => eventsBox.get('e1')).thenReturn(event);

      final result = await dataSource.getCachedEventById('e1');

      expect(result, event);
    });

    test('returns null when not found', () async {
      when(() => eventsBox.get('missing')).thenReturn(null);

      final result = await dataSource.getCachedEventById('missing');

      expect(result, isNull);
    });
  });

  group('isEventCached', () {
    test('returns true when key exists', () async {
      when(() => eventsBox.containsKey('e1')).thenReturn(true);

      expect(await dataSource.isEventCached('e1'), isTrue);
    });

    test('returns false when key does not exist', () async {
      when(() => eventsBox.containsKey('e1')).thenReturn(false);

      expect(await dataSource.isEventCached('e1'), isFalse);
    });
  });

  group('getCacheSize', () {
    test('returns box length', () async {
      when(() => eventsBox.length).thenReturn(42);

      expect(await dataSource.getCacheSize(), 42);
    });
  });

  group('clearEventsCache', () {
    test('clears the events box', () async {
      when(() => eventsBox.clear()).thenAnswer((_) async => 0);

      await dataSource.clearEventsCache();

      verify(() => eventsBox.clear()).called(1);
    });
  });

  // ==========================================================================
  // OFFLINE ACTIONS QUEUE OPERATIONS
  // ==========================================================================

  group('queueOfflineAction', () {
    test('puts action with its id as key', () async {
      final action = _makeAction('a1');
      when(() => offlineActionsBox.put('a1', action))
          .thenAnswer((_) async {});

      await dataSource.queueOfflineAction(action);

      verify(() => offlineActionsBox.put('a1', action)).called(1);
    });
  });

  group('getQueuedActions', () {
    test('returns actions sorted by queuedAt ascending', () async {
      final newer = _makeAction('a1', queuedAt: DateTime(2025, 6, 1));
      final older = _makeAction('a2', queuedAt: DateTime(2025, 1, 1));
      when(() => offlineActionsBox.values).thenReturn([newer, older]);

      final result = await dataSource.getQueuedActions();

      expect(result.first.id, 'a2'); // older first
      expect(result.last.id, 'a1');
    });
  });

  group('getRetryableActions', () {
    test('filters out actions that exceeded max retries', () async {
      final retryable = _makeAction('a1', retryCount: 2);
      final failed = _makeAction('a2', retryCount: 3);
      when(() => offlineActionsBox.values).thenReturn([retryable, failed]);

      final result = await dataSource.getRetryableActions();

      expect(result.length, 1);
      expect(result.first.id, 'a1');
    });
  });

  group('getFailedActions', () {
    test('returns only actions that exceeded max retries', () async {
      final retryable = _makeAction('a1', retryCount: 1);
      final failed = _makeAction('a2', retryCount: 3);
      final alsoFailed = _makeAction('a3', retryCount: 5);
      when(() => offlineActionsBox.values)
          .thenReturn([retryable, failed, alsoFailed]);

      final result = await dataSource.getFailedActions();

      expect(result.length, 2);
      expect(result.map((a) => a.id), containsAll(['a2', 'a3']));
    });
  });

  group('updateOfflineAction', () {
    test('puts updated action', () async {
      final action = _makeAction('a1', retryCount: 2);
      when(() => offlineActionsBox.put('a1', action))
          .thenAnswer((_) async {});

      await dataSource.updateOfflineAction(action);

      verify(() => offlineActionsBox.put('a1', action)).called(1);
    });
  });

  group('removeOfflineAction', () {
    test('deletes action by id', () async {
      when(() => offlineActionsBox.delete('a1')).thenAnswer((_) async {});

      await dataSource.removeOfflineAction('a1');

      verify(() => offlineActionsBox.delete('a1')).called(1);
    });
  });

  group('getQueueSize', () {
    test('returns offline actions box length', () async {
      when(() => offlineActionsBox.length).thenReturn(7);

      expect(await dataSource.getQueueSize(), 7);
    });
  });

  group('clearOfflineQueue', () {
    test('clears the offline actions box', () async {
      when(() => offlineActionsBox.clear()).thenAnswer((_) async => 0);

      await dataSource.clearOfflineQueue();

      verify(() => offlineActionsBox.clear()).called(1);
    });
  });

  group('hasPendingActions', () {
    test('returns true when box is not empty', () async {
      when(() => offlineActionsBox.isNotEmpty).thenReturn(true);

      expect(await dataSource.hasPendingActions(), isTrue);
    });

    test('returns false when box is empty', () async {
      when(() => offlineActionsBox.isNotEmpty).thenReturn(false);

      expect(await dataSource.hasPendingActions(), isFalse);
    });
  });

  // ==========================================================================
  // OPTIMISTIC UI HELPERS
  // ==========================================================================

  group('like state (optimistic cache)', () {
    test('setLikeState true then isEventLiked returns true', () {
      dataSource.setLikeState('e1', 'u1', liked: true);

      expect(dataSource.isEventLiked('e1', 'u1'), isTrue);
    });

    test('setLikeState false removes like', () {
      dataSource.setLikeState('e1', 'u1', liked: true);
      dataSource.setLikeState('e1', 'u1', liked: false);

      expect(dataSource.isEventLiked('e1', 'u1'), isFalse);
    });

    test('isEventLiked returns false for unknown event', () {
      expect(dataSource.isEventLiked('unknown', 'u1'), isFalse);
    });

    test('unlike last user removes event key from cache', () {
      dataSource.setLikeState('e1', 'u1', liked: true);
      dataSource.setLikeState('e1', 'u1', liked: false);

      // Verify a second unlike does not throw
      dataSource.setLikeState('e1', 'u1', liked: false);
      expect(dataSource.isEventLiked('e1', 'u1'), isFalse);
    });
  });

  group('participation state (optimistic cache)', () {
    test('setParticipationState true then isEventParticipating returns true',
        () {
      dataSource.setParticipationState('e1', 'u1', participating: true);

      expect(dataSource.isEventParticipating('e1', 'u1'), isTrue);
    });

    test('setParticipationState false removes participation', () {
      dataSource.setParticipationState('e1', 'u1', participating: true);
      dataSource.setParticipationState('e1', 'u1', participating: false);

      expect(dataSource.isEventParticipating('e1', 'u1'), isFalse);
    });

    test('isEventParticipating returns false for unknown event', () {
      expect(dataSource.isEventParticipating('unknown', 'u1'), isFalse);
    });
  });

  group('clearOptimisticCaches', () {
    test('clears both like and participation caches', () {
      dataSource.setLikeState('e1', 'u1', liked: true);
      dataSource.setParticipationState('e2', 'u1', participating: true);

      dataSource.clearOptimisticCaches();

      expect(dataSource.isEventLiked('e1', 'u1'), isFalse);
      expect(dataSource.isEventParticipating('e2', 'u1'), isFalse);
    });
  });
}
