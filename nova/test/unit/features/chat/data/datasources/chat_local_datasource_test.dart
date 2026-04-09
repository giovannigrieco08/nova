import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive/hive.dart';

import 'package:nova/features/chat/data/datasources/chat_local_datasource.dart';

// ==========================================================================
// MOCK CLASSES
// ==========================================================================

class MockBox extends Mock implements Box<Map> {}

void main() {
  late ChatLocalDataSource dataSource;
  late MockBox mockBox;

  setUp(() {
    mockBox = MockBox();
    dataSource = ChatLocalDataSource();
    // Inject mock box using internal access
    // Since init() opens Hive box, we need to test with a pre-initialized state.
    // We'll use a workaround by testing at the public API level.
  });

  // ==========================================================================
  // Note: ChatLocalDataSource uses Hive.openBox internally, which makes unit
  // testing with mocks difficult. We test the PendingMessage model and the
  // logic that doesn't require a live Hive box.
  // ==========================================================================

  group('PendingMessage', () {
    test('happy: fromMap parses correctly', () {
      final map = {
        'local_id': 'local_123',
        'content': 'Hello world',
        'user_id': 'user-1',
        'reply_to_id': null,
        'mentions': <dynamic>[],
        'status': 'pending',
        'created_at': '2025-06-01T12:00:00.000Z',
        'retry_count': 0,
        'last_error': null,
        'server_id': null,
      };

      final message = PendingMessage.fromMap(map);

      expect(message.localId, 'local_123');
      expect(message.content, 'Hello world');
      expect(message.userId, 'user-1');
      expect(message.status, PendingMessageStatus.pending);
      expect(message.retryCount, 0);
      expect(message.isPending, isTrue);
      expect(message.canRetry, isTrue);
    });

    test('happy: fromMap handles all statuses', () {
      for (final status in PendingMessageStatus.values) {
        final map = {
          'local_id': 'local_1',
          'content': 'test',
          'user_id': 'user-1',
          'status': status.name,
          'created_at': DateTime.now().toIso8601String(),
        };

        final message = PendingMessage.fromMap(map);
        expect(message.status, status);
      }
    });

    test('happy: toMap roundtrips correctly', () {
      final original = PendingMessage(
        localId: 'local_abc',
        content: 'Test message',
        userId: 'user-1',
        replyToId: 'reply-to-1',
        mentions: const [
          {'user_id': 'u2', 'username': 'lucia'}
        ],
        status: PendingMessageStatus.pending,
        createdAt: DateTime(2025, 6, 1, 12, 0),
        retryCount: 2,
        lastError: 'timeout',
        serverId: null,
      );

      final map = original.toMap();
      final restored = PendingMessage.fromMap(map);

      expect(restored.localId, original.localId);
      expect(restored.content, original.content);
      expect(restored.replyToId, original.replyToId);
      expect(restored.retryCount, original.retryCount);
      expect(restored.lastError, original.lastError);
    });

    test('happy: copyWith creates new instance', () {
      final original = PendingMessage(
        localId: 'local_1',
        content: 'Hello',
        userId: 'user-1',
        mentions: const [],
        status: PendingMessageStatus.pending,
        createdAt: DateTime.now(),
        retryCount: 0,
      );

      final copy = original.copyWith(
        retryCount: 3,
        status: PendingMessageStatus.failed,
        lastError: 'Connection refused',
      );

      expect(copy.retryCount, 3);
      expect(copy.status, PendingMessageStatus.failed);
      expect(copy.lastError, 'Connection refused');
      expect(copy.content, original.content); // unchanged
    });

    test('edge: isPending returns true for pending and rateLimited', () {
      final pending = PendingMessage(
        localId: 'local_1',
        content: 'test',
        userId: 'user-1',
        mentions: const [],
        status: PendingMessageStatus.pending,
        createdAt: DateTime.now(),
        retryCount: 0,
      );

      final rateLimited = pending.copyWith(
        status: PendingMessageStatus.rateLimited,
      );

      final synced = pending.copyWith(
        status: PendingMessageStatus.synced,
      );

      expect(pending.isPending, isTrue);
      expect(rateLimited.isPending, isTrue);
      expect(synced.isPending, isFalse);
    });

    test('edge: canRetry returns false when retryCount >= 3', () {
      final message = PendingMessage(
        localId: 'local_1',
        content: 'test',
        userId: 'user-1',
        mentions: const [],
        status: PendingMessageStatus.pending,
        createdAt: DateTime.now(),
        retryCount: 3,
      );

      expect(message.canRetry, isFalse);
    });

    test('edge: canRetry returns false when not pending', () {
      final message = PendingMessage(
        localId: 'local_1',
        content: 'test',
        userId: 'user-1',
        mentions: const [],
        status: PendingMessageStatus.failed,
        createdAt: DateTime.now(),
        retryCount: 0,
      );

      expect(message.canRetry, isFalse);
    });

    test('edge: fromMap defaults missing fields', () {
      final minimal = {
        'local_id': 'local_1',
        'content': 'test',
        'user_id': 'user-1',
        'created_at': DateTime.now().toIso8601String(),
      };

      final message = PendingMessage.fromMap(minimal);

      expect(message.status, PendingMessageStatus.pending);
      expect(message.retryCount, 0);
      expect(message.mentions, isEmpty);
      expect(message.replyToId, isNull);
    });
  });

  // ==========================================================================
  // PendingMessageStatus
  // ==========================================================================

  group('PendingMessageStatus', () {
    test('happy: has all expected values', () {
      expect(PendingMessageStatus.values, hasLength(5));
      expect(PendingMessageStatus.values, contains(PendingMessageStatus.pending));
      expect(PendingMessageStatus.values, contains(PendingMessageStatus.sending));
      expect(PendingMessageStatus.values, contains(PendingMessageStatus.synced));
      expect(PendingMessageStatus.values, contains(PendingMessageStatus.failed));
      expect(
          PendingMessageStatus.values, contains(PendingMessageStatus.rateLimited));
    });
  });

  // ==========================================================================
  // _ensureInitialized (indirectly tested)
  // ==========================================================================

  group('ensureInitialized', () {
    test('edge: throws StateError if not initialized', () {
      final uninitializedDS = ChatLocalDataSource();

      expect(
        () => uninitializedDS.getPendingMessages(),
        throwsA(isA<StateError>()),
      );
    });

    test('edge: hasPendingMessages throws if not initialized', () {
      final uninitializedDS = ChatLocalDataSource();

      expect(
        () => uninitializedDS.hasPendingMessages(),
        throwsA(isA<StateError>()),
      );
    });

    test('edge: getPendingCount throws if not initialized', () {
      final uninitializedDS = ChatLocalDataSource();

      expect(
        () => uninitializedDS.getPendingCount(),
        throwsA(isA<StateError>()),
      );
    });
  });

  // ==========================================================================
  // ChatLocalDataSource methods (with injected mock box)
  // ==========================================================================

  group('addPendingMessage', () {
    late ChatLocalDataSource ds;
    late MockBox mockBox;

    setUp(() {
      mockBox = MockBox();
      ds = ChatLocalDataSource.withBox(mockBox);
    });

    test('happy: stores message and returns local ID', () async {
      when(() => mockBox.put(any(), any())).thenAnswer((_) async {});

      final localId = await ds.addPendingMessage(
        content: 'Hello',
        userId: 'user-1',
      );

      expect(localId, startsWith('local_'));
      verify(() => mockBox.put(localId, any())).called(1);
    });

    test('happy: stores message with replyToId and mentions', () async {
      Map? storedMessage;
      when(() => mockBox.put(any(), any())).thenAnswer((invocation) async {
        storedMessage = invocation.positionalArguments[1] as Map;
      });

      await ds.addPendingMessage(
        content: 'Reply!',
        userId: 'user-1',
        replyToId: 'msg-123',
        mentions: [
          {'user_id': 'u2', 'username': 'lucia'},
        ],
      );

      expect(storedMessage, isNotNull);
      expect(storedMessage!['reply_to_id'], 'msg-123');
      expect(storedMessage!['mentions'], hasLength(1));
      expect(storedMessage!['status'], 'pending');
      expect(storedMessage!['retry_count'], 0);
    });
  });

  group('getPendingMessages', () {
    late ChatLocalDataSource ds;
    late MockBox mockBox;

    setUp(() {
      mockBox = MockBox();
      ds = ChatLocalDataSource.withBox(mockBox);
    });

    test('happy: returns messages sorted by createdAt', () {
      final older = {
        'local_id': 'local_1',
        'content': 'first',
        'user_id': 'user-1',
        'status': 'pending',
        'created_at': '2025-06-01T10:00:00.000Z',
        'retry_count': 0,
      };
      final newer = {
        'local_id': 'local_2',
        'content': 'second',
        'user_id': 'user-1',
        'status': 'pending',
        'created_at': '2025-06-01T12:00:00.000Z',
        'retry_count': 0,
      };

      // Return in reverse order to verify sorting
      when(() => mockBox.values).thenReturn([newer, older]);

      final messages = ds.getPendingMessages();

      expect(messages.length, 2);
      expect(messages[0].localId, 'local_1');
      expect(messages[1].localId, 'local_2');
    });

    test('edge: returns empty list when box is empty', () {
      when(() => mockBox.values).thenReturn([]);

      final messages = ds.getPendingMessages();

      expect(messages, isEmpty);
    });
  });

  group('updateMessageStatus', () {
    late ChatLocalDataSource ds;
    late MockBox mockBox;

    setUp(() {
      mockBox = MockBox();
      ds = ChatLocalDataSource.withBox(mockBox);
    });

    test('happy: updates status of existing message', () async {
      final existing = {
        'local_id': 'local_1',
        'content': 'test',
        'user_id': 'user-1',
        'status': 'pending',
        'created_at': '2025-06-01T12:00:00.000Z',
        'retry_count': 0,
      };
      when(() => mockBox.get('local_1')).thenReturn(existing);
      when(() => mockBox.put(any(), any())).thenAnswer((_) async {});

      await ds.updateMessageStatus('local_1', PendingMessageStatus.sending);

      final captured = verify(() => mockBox.put('local_1', captureAny()))
          .captured
          .last as Map;
      expect(captured['status'], 'sending');
    });

    test('happy: increments retry_count when error is provided', () async {
      final existing = {
        'local_id': 'local_1',
        'content': 'test',
        'user_id': 'user-1',
        'status': 'pending',
        'created_at': '2025-06-01T12:00:00.000Z',
        'retry_count': 1,
      };
      when(() => mockBox.get('local_1')).thenReturn(existing);
      when(() => mockBox.put(any(), any())).thenAnswer((_) async {});

      await ds.updateMessageStatus(
        'local_1',
        PendingMessageStatus.pending,
        error: 'timeout',
      );

      final captured = verify(() => mockBox.put('local_1', captureAny()))
          .captured
          .last as Map;
      expect(captured['retry_count'], 2);
      expect(captured['last_error'], 'timeout');
    });

    test('happy: sets serverId when provided', () async {
      final existing = {
        'local_id': 'local_1',
        'content': 'test',
        'user_id': 'user-1',
        'status': 'pending',
        'created_at': '2025-06-01T12:00:00.000Z',
        'retry_count': 0,
      };
      when(() => mockBox.get('local_1')).thenReturn(existing);
      when(() => mockBox.put(any(), any())).thenAnswer((_) async {});

      await ds.updateMessageStatus(
        'local_1',
        PendingMessageStatus.synced,
        serverId: 'server-abc',
      );

      final captured = verify(() => mockBox.put('local_1', captureAny()))
          .captured
          .last as Map;
      expect(captured['server_id'], 'server-abc');
      expect(captured['status'], 'synced');
    });

    test('edge: does nothing when message not found', () async {
      when(() => mockBox.get('nonexistent')).thenReturn(null);

      await ds.updateMessageStatus(
          'nonexistent', PendingMessageStatus.sending);

      verifyNever(() => mockBox.put(any(), any()));
    });
  });

  group('removePendingMessage', () {
    late ChatLocalDataSource ds;
    late MockBox mockBox;

    setUp(() {
      mockBox = MockBox();
      ds = ChatLocalDataSource.withBox(mockBox);
    });

    test('happy: deletes message from box', () async {
      when(() => mockBox.delete('local_1')).thenAnswer((_) async {});

      await ds.removePendingMessage('local_1');

      verify(() => mockBox.delete('local_1')).called(1);
    });
  });

  group('clearAll', () {
    late ChatLocalDataSource ds;
    late MockBox mockBox;

    setUp(() {
      mockBox = MockBox();
      ds = ChatLocalDataSource.withBox(mockBox);
    });

    test('happy: clears the entire box', () async {
      when(() => mockBox.clear()).thenAnswer((_) async => 0);

      await ds.clearAll();

      verify(() => mockBox.clear()).called(1);
    });
  });

  group('hasPendingMessages', () {
    late ChatLocalDataSource ds;
    late MockBox mockBox;

    setUp(() {
      mockBox = MockBox();
      ds = ChatLocalDataSource.withBox(mockBox);
    });

    test('happy: returns true when box is not empty', () {
      when(() => mockBox.isNotEmpty).thenReturn(true);

      expect(ds.hasPendingMessages(), isTrue);
    });

    test('happy: returns false when box is empty', () {
      when(() => mockBox.isNotEmpty).thenReturn(false);

      expect(ds.hasPendingMessages(), isFalse);
    });
  });

  group('getPendingCount', () {
    late ChatLocalDataSource ds;
    late MockBox mockBox;

    setUp(() {
      mockBox = MockBox();
      ds = ChatLocalDataSource.withBox(mockBox);
    });

    test('happy: returns box length', () {
      when(() => mockBox.length).thenReturn(5);

      expect(ds.getPendingCount(), 5);
    });
  });

  group('getMessagesForRetry', () {
    late ChatLocalDataSource ds;
    late MockBox mockBox;

    setUp(() {
      mockBox = MockBox();
      ds = ChatLocalDataSource.withBox(mockBox);
    });

    test('happy: returns only pending messages under max retries', () {
      final messages = [
        {
          'local_id': 'local_1',
          'content': 'retryable',
          'user_id': 'user-1',
          'status': 'pending',
          'created_at': '2025-06-01T10:00:00.000Z',
          'retry_count': 1,
        },
        {
          'local_id': 'local_2',
          'content': 'too many retries',
          'user_id': 'user-1',
          'status': 'pending',
          'created_at': '2025-06-01T11:00:00.000Z',
          'retry_count': 3,
        },
        {
          'local_id': 'local_3',
          'content': 'already synced',
          'user_id': 'user-1',
          'status': 'synced',
          'created_at': '2025-06-01T12:00:00.000Z',
          'retry_count': 0,
        },
      ];
      when(() => mockBox.values).thenReturn(messages);

      final result = ds.getMessagesForRetry();

      expect(result.length, 1);
      expect(result.first.localId, 'local_1');
    });

    test('edge: custom maxRetries parameter', () {
      final messages = [
        {
          'local_id': 'local_1',
          'content': 'test',
          'user_id': 'user-1',
          'status': 'pending',
          'created_at': '2025-06-01T10:00:00.000Z',
          'retry_count': 4,
        },
      ];
      when(() => mockBox.values).thenReturn(messages);

      final withDefault = ds.getMessagesForRetry();
      expect(withDefault, isEmpty);

      final withHighMax = ds.getMessagesForRetry(maxRetries: 5);
      expect(withHighMax.length, 1);
    });
  });

  group('markAsFailed', () {
    late ChatLocalDataSource ds;
    late MockBox mockBox;

    setUp(() {
      mockBox = MockBox();
      ds = ChatLocalDataSource.withBox(mockBox);
    });

    test('happy: updates status to failed with reason', () async {
      final existing = {
        'local_id': 'local_1',
        'content': 'test',
        'user_id': 'user-1',
        'status': 'pending',
        'created_at': '2025-06-01T12:00:00.000Z',
        'retry_count': 2,
      };
      when(() => mockBox.get('local_1')).thenReturn(existing);
      when(() => mockBox.put(any(), any())).thenAnswer((_) async {});

      await ds.markAsFailed('local_1', 'Connection refused');

      final captured = verify(() => mockBox.put('local_1', captureAny()))
          .captured
          .last as Map;
      expect(captured['status'], 'failed');
      expect(captured['last_error'], 'Connection refused');
      expect(captured['retry_count'], 3);
    });
  });

  group('cleanupOldMessages', () {
    late ChatLocalDataSource ds;
    late MockBox mockBox;

    setUp(() {
      mockBox = MockBox();
      ds = ChatLocalDataSource.withBox(mockBox);
    });

    test('happy: deletes messages older than 24 hours', () async {
      final oldTime =
          DateTime.now().subtract(const Duration(hours: 25)).toIso8601String();
      final recentTime =
          DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();

      when(() => mockBox.toMap()).thenReturn({
        'local_old': {
          'local_id': 'local_old',
          'content': 'old',
          'user_id': 'user-1',
          'status': 'failed',
          'created_at': oldTime,
          'retry_count': 3,
        },
        'local_recent': {
          'local_id': 'local_recent',
          'content': 'recent',
          'user_id': 'user-1',
          'status': 'pending',
          'created_at': recentTime,
          'retry_count': 0,
        },
      });
      when(() => mockBox.delete(any())).thenAnswer((_) async {});

      await ds.cleanupOldMessages();

      verify(() => mockBox.delete('local_old')).called(1);
      verifyNever(() => mockBox.delete('local_recent'));
    });

    test('edge: does nothing when no messages are old', () async {
      final recentTime =
          DateTime.now().subtract(const Duration(hours: 1)).toIso8601String();

      when(() => mockBox.toMap()).thenReturn({
        'local_1': {
          'local_id': 'local_1',
          'content': 'recent',
          'user_id': 'user-1',
          'status': 'pending',
          'created_at': recentTime,
          'retry_count': 0,
        },
      });

      await ds.cleanupOldMessages();

      verifyNever(() => mockBox.delete(any()));
    });
  });
}
