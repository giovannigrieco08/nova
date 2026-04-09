import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:nova/features/events/data/repositories/offline_queue_repository.dart';
import 'package:nova/features/events/data/data_sources/events_local_data_source.dart';
import 'package:nova/features/events/data/data_sources/events_remote_data_source.dart';
import 'package:nova/features/events/domain/entities/offline_action.dart';

// ==========================================================================
// MOCK CLASSES
// ==========================================================================

class MockEventsLocalDataSource extends Mock implements EventsLocalDataSource {}

class MockEventsRemoteDataSource extends Mock
    implements EventsRemoteDataSource {}

class FakeOfflineAction extends Fake implements OfflineAction {}

void main() {
  late OfflineQueueRepository repository;
  late MockEventsLocalDataSource mockLocalDataSource;
  late MockEventsRemoteDataSource mockRemoteDataSource;

  setUpAll(() {
    registerFallbackValue(FakeOfflineAction());
  });

  setUp(() {
    mockLocalDataSource = MockEventsLocalDataSource();
    mockRemoteDataSource = MockEventsRemoteDataSource();

    repository = OfflineQueueRepository(
      localDataSource: mockLocalDataSource,
      remoteDataSource: mockRemoteDataSource,
    );
  });

  tearDown(() {
    repository.dispose();
  });

  // ==========================================================================
  // Helper
  // ==========================================================================

  OfflineAction _createAction({
    String id = 'action-1',
    String type = 'like_event',
    int retryCount = 0,
  }) {
    return OfflineAction(
      id: id,
      type: type,
      payload: {'event_id': 'evt-1', 'user_id': 'user-1'},
      queuedAt: DateTime.now(),
      retryCount: retryCount,
    );
  }

  // ==========================================================================
  // queueAction
  // ==========================================================================

  group('queueAction', () {
    test('happy: queues action and processes queue', () async {
      final action = _createAction();
      when(() => mockLocalDataSource.queueOfflineAction(any()))
          .thenAnswer((_) async {});
      when(() => mockLocalDataSource.getRetryableActions())
          .thenAnswer((_) async => [action]);
      when(() => mockRemoteDataSource.likeEvent(
            eventId: any(named: 'eventId'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {});
      when(() => mockLocalDataSource.removeOfflineAction(any()))
          .thenAnswer((_) async {});

      await repository.queueAction(action);

      verify(() => mockLocalDataSource.queueOfflineAction(action)).called(1);
    });

    test('happy: processes like_event action', () async {
      final action = _createAction(type: 'like_event');
      when(() => mockLocalDataSource.getRetryableActions())
          .thenAnswer((_) async => [action]);
      when(() => mockRemoteDataSource.likeEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).thenAnswer((_) async {});
      when(() => mockLocalDataSource.removeOfflineAction('action-1'))
          .thenAnswer((_) async {});

      await repository.processQueue();

      verify(() => mockRemoteDataSource.likeEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).called(1);
      verify(() => mockLocalDataSource.removeOfflineAction('action-1'))
          .called(1);
    });

    test('happy: processes unlike_event action', () async {
      final action = _createAction(type: 'unlike_event');
      when(() => mockLocalDataSource.getRetryableActions())
          .thenAnswer((_) async => [action]);
      when(() => mockRemoteDataSource.unlikeEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).thenAnswer((_) async {});
      when(() => mockLocalDataSource.removeOfflineAction(any()))
          .thenAnswer((_) async {});

      await repository.processQueue();

      verify(() => mockRemoteDataSource.unlikeEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).called(1);
    });

    test('happy: processes participate_event action', () async {
      final action = OfflineAction(
        id: 'action-p',
        type: 'participate_event',
        payload: {'event_id': 'evt-1', 'user_id': 'user-1'},
        queuedAt: DateTime.now(),
      );
      when(() => mockLocalDataSource.getRetryableActions())
          .thenAnswer((_) async => [action]);
      when(() => mockRemoteDataSource.participateInEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).thenAnswer((_) async {});
      when(() => mockLocalDataSource.removeOfflineAction(any()))
          .thenAnswer((_) async {});

      await repository.processQueue();

      verify(() => mockRemoteDataSource.participateInEvent(
            eventId: 'evt-1',
            userId: 'user-1',
          )).called(1);
    });
  });

  // ==========================================================================
  // processQueue - error handling
  // ==========================================================================

  group('processQueue error handling', () {
    test('edge: increments retry count on failure', () async {
      final action = _createAction(retryCount: 0);
      when(() => mockLocalDataSource.getRetryableActions())
          .thenAnswer((_) async => [action]);
      when(() => mockRemoteDataSource.likeEvent(
            eventId: any(named: 'eventId'),
            userId: any(named: 'userId'),
          )).thenThrow(Exception('Network error'));
      when(() => mockLocalDataSource.updateOfflineAction(any()))
          .thenAnswer((_) async {});

      await repository.processQueue();

      verify(() => mockLocalDataSource.updateOfflineAction(any())).called(1);
    });

    test('edge: notifies on exceeded max retries', () async {
      final action = _createAction(retryCount: 2); // Will become 3
      List<OfflineAction>? failedActions;
      repository.onFailedActionsExceedRetries = (actions) {
        failedActions = actions;
      };

      when(() => mockLocalDataSource.getRetryableActions())
          .thenAnswer((_) async => [action]);
      when(() => mockRemoteDataSource.likeEvent(
            eventId: any(named: 'eventId'),
            userId: any(named: 'userId'),
          )).thenThrow(Exception('Still failing'));
      when(() => mockLocalDataSource.updateOfflineAction(any()))
          .thenAnswer((_) async {});
      when(() => mockLocalDataSource.getFailedActions())
          .thenAnswer((_) async => [action]);

      await repository.processQueue();

      verify(() => mockLocalDataSource.getFailedActions()).called(1);
    });

    test('edge: empty queue processes without errors', () async {
      when(() => mockLocalDataSource.getRetryableActions())
          .thenAnswer((_) async => []);

      await repository.processQueue();

      verifyNever(() => mockRemoteDataSource.likeEvent(
            eventId: any(named: 'eventId'),
            userId: any(named: 'userId'),
          ));
    });

    test('edge: unknown action type throws exception', () async {
      final action = _createAction(type: 'unknown_type');
      when(() => mockLocalDataSource.getRetryableActions())
          .thenAnswer((_) async => [action]);
      when(() => mockLocalDataSource.updateOfflineAction(any()))
          .thenAnswer((_) async {});

      // Should not throw - error is caught inside processQueue
      await repository.processQueue();

      verify(() => mockLocalDataSource.updateOfflineAction(any())).called(1);
    });
  });

  // ==========================================================================
  // retryFailedActions
  // ==========================================================================

  group('retryFailedActions', () {
    test('race: retry during active sync', () async {
      final failedAction = _createAction(retryCount: 3);
      when(() => mockLocalDataSource.getFailedActions())
          .thenAnswer((_) async => [failedAction]);
      when(() => mockLocalDataSource.updateOfflineAction(any()))
          .thenAnswer((_) async {});
      when(() => mockLocalDataSource.getRetryableActions())
          .thenAnswer((_) async => [failedAction.copyWith(retryCount: 0)]);
      when(() => mockRemoteDataSource.likeEvent(
            eventId: any(named: 'eventId'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {});
      when(() => mockLocalDataSource.removeOfflineAction(any()))
          .thenAnswer((_) async {});

      await repository.retryFailedActions();

      verify(() => mockLocalDataSource.updateOfflineAction(any())).called(1);
    });

    test('race: concurrent retry and queue processing', () async {
      final action = _createAction(retryCount: 3);
      when(() => mockLocalDataSource.getFailedActions())
          .thenAnswer((_) async => [action]);
      when(() => mockLocalDataSource.updateOfflineAction(any()))
          .thenAnswer((_) async {});
      when(() => mockLocalDataSource.getRetryableActions())
          .thenAnswer((_) async => []);

      final futures = [
        repository.retryFailedActions(),
        repository.processQueue(),
      ];

      await Future.wait(futures);

      // Both should complete without error
    });

    test('race: retry single action during queue processing', () async {
      final action = _createAction(retryCount: 3);
      when(() => mockLocalDataSource.getQueuedActions())
          .thenAnswer((_) async => [action]);
      when(() => mockLocalDataSource.updateOfflineAction(any()))
          .thenAnswer((_) async {});
      when(() => mockRemoteDataSource.likeEvent(
            eventId: any(named: 'eventId'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {});
      when(() => mockLocalDataSource.removeOfflineAction(any()))
          .thenAnswer((_) async {});

      await repository.retryAction('action-1');

      verify(() => mockLocalDataSource.removeOfflineAction('action-1'))
          .called(1);
    });

    test('race: retryAction fails and re-queues', () async {
      final action = _createAction(retryCount: 3);
      when(() => mockLocalDataSource.getQueuedActions())
          .thenAnswer((_) async => [action]);
      when(() => mockLocalDataSource.updateOfflineAction(any()))
          .thenAnswer((_) async {});
      when(() => mockRemoteDataSource.likeEvent(
            eventId: any(named: 'eventId'),
            userId: any(named: 'userId'),
          )).thenThrow(Exception('Still offline'));

      await repository.retryAction('action-1');

      // Two calls: once to reset, once after failure to re-queue
      verify(() => mockLocalDataSource.updateOfflineAction(any())).called(2);
    });
  });

  // ==========================================================================
  // Queue status methods
  // ==========================================================================

  group('queue status', () {
    test('happy: getQueuedActions delegates to local', () async {
      when(() => mockLocalDataSource.getQueuedActions())
          .thenAnswer((_) async => []);

      final result = await repository.getQueuedActions();

      expect(result, isEmpty);
    });

    test('happy: getPendingActionsCount delegates to local', () async {
      when(() => mockLocalDataSource.getQueueSize())
          .thenAnswer((_) async => 5);

      final count = await repository.getPendingActionsCount();

      expect(count, 5);
    });

    test('happy: hasPendingActions delegates to local', () async {
      when(() => mockLocalDataSource.hasPendingActions())
          .thenAnswer((_) async => true);

      final result = await repository.hasPendingActions();

      expect(result, isTrue);
    });

    test('happy: clearQueue delegates to local', () async {
      when(() => mockLocalDataSource.clearOfflineQueue())
          .thenAnswer((_) async {});

      await repository.clearQueue();

      verify(() => mockLocalDataSource.clearOfflineQueue()).called(1);
    });
  });
}
