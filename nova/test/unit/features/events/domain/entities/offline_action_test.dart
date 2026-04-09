import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/domain/entities/offline_action.dart';

void main() {
  final now = DateTime(2025, 6, 15, 10, 0);

  group('OfflineAction', () {
    // =====================================================================
    // Happy Path Tests (H:3)
    // =====================================================================

    test('should create OfflineAction with required fields and defaults', () {
      final action = OfflineAction(
        id: 'action-001',
        type: 'like_event',
        payload: {'event_id': 'event-001', 'user_id': 'user-001'},
        queuedAt: now,
      );

      expect(action.id, 'action-001');
      expect(action.type, 'like_event');
      expect(action.payload['event_id'], 'event-001');
      expect(action.retryCount, 0);
      expect(action.lastRetryAt, isNull);
    });

    test('incrementRetry increments count and sets lastRetryAt', () {
      final action = OfflineAction(
        id: 'action-001',
        type: 'like_event',
        payload: {'event_id': 'event-001'},
        queuedAt: now,
        retryCount: 0,
      );

      final retried = action.incrementRetry();

      expect(retried.retryCount, 1);
      expect(retried.lastRetryAt, isNotNull);
      expect(retried.id, action.id);
      expect(retried.type, action.type);
    });

    test('backoffDelay returns exponential delays', () {
      final action0 = OfflineAction(
        id: 'a1',
        type: 'like_event',
        payload: {},
        queuedAt: now,
        retryCount: 0,
      );
      final action1 = action0.copyWith(retryCount: 1);
      final action2 = action0.copyWith(retryCount: 2);
      final action3 = action0.copyWith(retryCount: 3);

      expect(action0.backoffDelay, const Duration(seconds: 1));
      expect(action1.backoffDelay, const Duration(seconds: 2));
      expect(action2.backoffDelay, const Duration(seconds: 4));
      expect(action3.backoffDelay, const Duration(seconds: 4)); // capped at 4
    });

    // =====================================================================
    // Edge Case Tests (E:3)
    // =====================================================================

    test('hasExceededMaxRetries returns true at 3 retries', () {
      final action = OfflineAction(
        id: 'a1',
        type: 'post_comment',
        payload: {},
        queuedAt: now,
        retryCount: 2,
      );

      expect(action.hasExceededMaxRetries, isFalse);

      final exceeded = action.copyWith(retryCount: 3);
      expect(exceeded.hasExceededMaxRetries, isTrue);

      final over = action.copyWith(retryCount: 5);
      expect(over.hasExceededMaxRetries, isTrue);
    });

    test('equality is based on id only', () {
      final action1 = OfflineAction(
        id: 'action-001',
        type: 'like_event',
        payload: {'a': 1},
        queuedAt: now,
      );

      final action2 = OfflineAction(
        id: 'action-001',
        type: 'unlike_event',
        payload: {'b': 2},
        queuedAt: now.add(const Duration(hours: 1)),
      );

      final action3 = OfflineAction(
        id: 'action-002',
        type: 'like_event',
        payload: {'a': 1},
        queuedAt: now,
      );

      expect(action1, equals(action2));
      expect(action1, isNot(equals(action3)));
      expect(action1.hashCode, action2.hashCode);
    });

    test('factory create generates unique id and sets defaults', () {
      final action = OfflineAction.create(
        type: 'participate_event',
        payload: {'event_id': 'e1'},
      );

      expect(action.id, isNotEmpty);
      expect(action.type, 'participate_event');
      expect(action.retryCount, 0);
      expect(action.lastRetryAt, isNull);
      expect(action.queuedAt, isNotNull);
    });
  });
}
