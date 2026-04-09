import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:nova/features/comments/data/datasources/comments_local_datasource.dart';
import 'package:nova/features/comments/data/models/comment_model.dart';
import 'package:nova/features/comments/domain/entities/comment_report.dart';
import 'package:nova/features/comments/domain/repositories/comments_repository_interface.dart';

void main() {
  late CommentsLocalDataSource datasource;
  late Directory tempDir;
  late Box<Map<dynamic, dynamic>> cacheBox;
  late Box<Map<dynamic, dynamic>> queueBox;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_cls_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() async {
    cacheBox = await Hive.openBox<Map<dynamic, dynamic>>('cls_cache_test');
    queueBox = await Hive.openBox<Map<dynamic, dynamic>>('cls_queue_test');
    datasource = CommentsLocalDataSource.withBoxes(
      commentsCache: cacheBox,
      offlineQueue: queueBox,
    );
  });

  tearDown(() async {
    await cacheBox.clear();
    await queueBox.clear();
  });

  CommentModel makeComment({
    String id = 'c-1',
    String eventId = 'evt-1',
    String text = 'Test',
  }) {
    return CommentModel(
      id: id,
      eventId: eventId,
      userId: 'user-1',
      text: text,
      createdAt: DateTime(2025, 6, 1),
    );
  }

  // ==========================================================================
  // CACHE: getCachedComments
  // ==========================================================================

  group('getCachedComments', () {
    test('returns comments when cache is fresh', () async {
      await datasource.cacheComments(
        eventId: 'evt-1',
        comments: [makeComment(), makeComment(id: 'c-2')],
      );

      final result = await datasource.getCachedComments(eventId: 'evt-1');

      expect(result, isNotNull);
      expect(result!.length, 2);
      expect(result[0].id, 'c-1');
    });

    test('returns null for cache miss', () async {
      final result = await datasource.getCachedComments(eventId: 'nonexistent');
      expect(result, isNull);
    });

    test('returns null for expired cache (>15 min)', () async {
      // Manually insert expired entry
      await cacheBox.put('event_evt-old', {
        'timestamp': DateTime.now()
            .subtract(const Duration(minutes: 20))
            .toIso8601String(),
        'comments': [makeComment().toJson()],
      });

      final result = await datasource.getCachedComments(eventId: 'evt-old');
      expect(result, isNull);
    });

    test('returns null for corrupted entry (no timestamp)', () async {
      await cacheBox.put('event_evt-bad', {
        'comments': [makeComment().toJson()],
      });

      final result = await datasource.getCachedComments(eventId: 'evt-bad');
      expect(result, isNull);
    });

    test('returns null for corrupted entry (no comments)', () async {
      await cacheBox.put('event_evt-bad2', {
        'timestamp': DateTime.now().toIso8601String(),
      });

      final result = await datasource.getCachedComments(eventId: 'evt-bad2');
      expect(result, isNull);
    });
  });

  // ==========================================================================
  // CACHE: cacheComments
  // ==========================================================================

  group('cacheComments', () {
    test('stores comments with timestamp', () async {
      await datasource.cacheComments(
        eventId: 'evt-1',
        comments: [makeComment()],
      );

      final stored = cacheBox.get('event_evt-1');
      expect(stored, isNotNull);
      expect(stored!['timestamp'], isA<String>());
      expect((stored['comments'] as List).length, 1);
    });

    test('overwrites existing cache for same event', () async {
      await datasource.cacheComments(
        eventId: 'evt-1',
        comments: [makeComment(text: 'first')],
      );
      await datasource.cacheComments(
        eventId: 'evt-1',
        comments: [makeComment(text: 'second'), makeComment(id: 'c-2')],
      );

      final result = await datasource.getCachedComments(eventId: 'evt-1');
      expect(result!.length, 2);
    });
  });

  // ==========================================================================
  // CACHE: clearCache
  // ==========================================================================

  group('clearCache', () {
    test('removes all cached comments', () async {
      await datasource.cacheComments(eventId: 'e1', comments: [makeComment()]);
      await datasource.cacheComments(
          eventId: 'e2', comments: [makeComment(eventId: 'e2')]);

      await datasource.clearCache();

      expect(await datasource.getCachedComments(eventId: 'e1'), isNull);
      expect(await datasource.getCachedComments(eventId: 'e2'), isNull);
    });
  });

  // ==========================================================================
  // CACHE: cleanupExpiredCache
  // ==========================================================================

  group('cleanupExpiredCache', () {
    test('removes only expired entries', () async {
      // Fresh entry
      await datasource.cacheComments(
          eventId: 'fresh', comments: [makeComment()]);

      // Expired entry (manually inserted)
      await cacheBox.put('event_expired', {
        'timestamp': DateTime.now()
            .subtract(const Duration(minutes: 20))
            .toIso8601String(),
        'comments': [],
      });

      await datasource.cleanupExpiredCache();

      expect(await datasource.getCachedComments(eventId: 'fresh'), isNotNull);
      expect(cacheBox.get('event_expired'), isNull);
    });

    test('removes entries with no timestamp', () async {
      await cacheBox.put('event_corrupt', {'comments': []});

      await datasource.cleanupExpiredCache();

      expect(cacheBox.get('event_corrupt'), isNull);
    });
  });

  // ==========================================================================
  // QUEUE: queueOfflineAction
  // ==========================================================================

  group('queueOfflineAction', () {
    test('stores action with tempId as key', () async {
      final action = OfflineCommentAction(
        tempId: 'temp-1',
        type: OfflineActionType.post,
        eventId: 'evt-1',
        text: 'New comment',
        queuedAt: DateTime(2025, 6, 1),
      );

      await datasource.queueOfflineAction(action: action);

      expect(queueBox.get('temp-1'), isNotNull);
      expect(queueBox.get('temp-1')!['type'], 'post');
      expect(queueBox.get('temp-1')!['text'], 'New comment');
    });

    test('stores report action with reason', () async {
      final action = OfflineCommentAction(
        tempId: 'temp-report',
        type: OfflineActionType.report,
        commentId: 'c-1',
        reportReason: CommentReportReason.spam,
        reportDetails: 'Clearly spam',
        queuedAt: DateTime(2025, 6, 1),
      );

      await datasource.queueOfflineAction(action: action);

      final stored = queueBox.get('temp-report')!;
      expect(stored['report_reason'], 'spam');
      expect(stored['report_details'], 'Clearly spam');
    });
  });

  // ==========================================================================
  // QUEUE: getOfflineQueue
  // ==========================================================================

  group('getOfflineQueue', () {
    test('returns actions sorted by queuedAt FIFO', () async {
      await datasource.queueOfflineAction(
        action: OfflineCommentAction(
          tempId: 'late',
          type: OfflineActionType.post,
          queuedAt: DateTime(2025, 6, 1, 14, 0),
        ),
      );
      await datasource.queueOfflineAction(
        action: OfflineCommentAction(
          tempId: 'early',
          type: OfflineActionType.post,
          queuedAt: DateTime(2025, 6, 1, 10, 0),
        ),
      );

      final queue = await datasource.getOfflineQueue();

      expect(queue.length, 2);
      expect(queue[0].tempId, 'early');
      expect(queue[1].tempId, 'late');
    });

    test('returns empty list when queue is empty', () async {
      final queue = await datasource.getOfflineQueue();
      expect(queue, isEmpty);
    });

    test('skips corrupted entries', () async {
      await queueBox.put('bad', {'no_type': true});
      await datasource.queueOfflineAction(
        action: OfflineCommentAction(
          tempId: 'good',
          type: OfflineActionType.like,
          commentId: 'c-1',
          queuedAt: DateTime(2025, 6, 1),
        ),
      );

      final queue = await datasource.getOfflineQueue();
      expect(queue.length, 1);
      expect(queue[0].tempId, 'good');
    });
  });

  // ==========================================================================
  // QUEUE: removeFromQueue
  // ==========================================================================

  group('removeFromQueue', () {
    test('removes action by tempId', () async {
      await datasource.queueOfflineAction(
        action: OfflineCommentAction(
          tempId: 'temp-1',
          type: OfflineActionType.post,
          queuedAt: DateTime.now(),
        ),
      );

      await datasource.removeFromQueue(tempId: 'temp-1');

      expect(queueBox.get('temp-1'), isNull);
    });
  });

  // ==========================================================================
  // QUEUE: clearOfflineQueue + getQueueSize
  // ==========================================================================

  group('clearOfflineQueue', () {
    test('removes all queued actions', () async {
      await datasource.queueOfflineAction(
        action: OfflineCommentAction(
            tempId: 'a', type: OfflineActionType.post, queuedAt: DateTime.now()),
      );
      await datasource.queueOfflineAction(
        action: OfflineCommentAction(
            tempId: 'b', type: OfflineActionType.like, queuedAt: DateTime.now()),
      );

      await datasource.clearOfflineQueue();

      expect(datasource.getQueueSize(), 0);
    });
  });

  group('getQueueSize', () {
    test('returns correct count', () async {
      expect(datasource.getQueueSize(), 0);

      await datasource.queueOfflineAction(
        action: OfflineCommentAction(
            tempId: 'a', type: OfflineActionType.post, queuedAt: DateTime.now()),
      );
      expect(datasource.getQueueSize(), 1);

      await datasource.queueOfflineAction(
        action: OfflineCommentAction(
            tempId: 'b', type: OfflineActionType.like, queuedAt: DateTime.now()),
      );
      expect(datasource.getQueueSize(), 2);
    });

    test('returns 0 on uninitialized datasource', () {
      final fresh = CommentsLocalDataSource();
      expect(fresh.getQueueSize(), 0);
    });
  });

  // ==========================================================================
  // dispose
  // ==========================================================================

  group('dispose', () {
    test('completes without error', () async {
      // Create isolated boxes for dispose test
      final dispCacheBox =
          await Hive.openBox<Map<dynamic, dynamic>>('dispose_cache');
      final dispQueueBox =
          await Hive.openBox<Map<dynamic, dynamic>>('dispose_queue');
      final ds = CommentsLocalDataSource.withBoxes(
        commentsCache: dispCacheBox,
        offlineQueue: dispQueueBox,
      );

      await ds.dispose();

      expect(dispCacheBox.isOpen, isFalse);
      expect(dispQueueBox.isOpen, isFalse);
    });
  });
}
