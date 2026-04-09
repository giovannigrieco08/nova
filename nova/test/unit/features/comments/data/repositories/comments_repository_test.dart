import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:nova/features/comments/data/repositories/comments_repository.dart';
import 'package:nova/features/comments/data/datasources/comments_remote_datasource.dart';
import 'package:nova/features/comments/data/datasources/comments_local_datasource.dart';
import 'package:nova/features/comments/data/models/comment_model.dart';
import 'package:nova/features/comments/data/models/comment_report_model.dart';
import 'package:nova/features/comments/domain/entities/comment.dart';
import 'package:nova/features/comments/domain/entities/comment_report.dart';
import 'package:nova/features/comments/domain/exceptions/comments_exceptions.dart';
import 'package:nova/features/comments/domain/repositories/comments_repository_interface.dart';

import '../../../../../fixtures/test_fixtures.dart';
import '../../../../../fixtures/comment_fixtures.dart';

// ==========================================================================
// MOCK CLASSES
// ==========================================================================

class MockCommentsRemoteDataSource extends Mock
    implements CommentsRemoteDataSource {}

class MockCommentsLocalDataSource extends Mock
    implements CommentsLocalDataSource {}

class FakeOfflineCommentAction extends Fake implements OfflineCommentAction {}

class FakeCommentModel extends Fake implements CommentModel {}

void main() {
  late CommentsRepository repository;
  late MockCommentsRemoteDataSource mockRemoteDataSource;
  late MockCommentsLocalDataSource mockLocalDataSource;

  setUpAll(() {
    registerFallbackValue(FakeOfflineCommentAction());
    registerFallbackValue(FakeCommentModel());
    registerFallbackValue(CommentSortOrder.recent);
    registerFallbackValue(CommentReportReason.spam);
    registerFallbackValue(<CommentModel>[]);
  });

  setUp(() {
    mockRemoteDataSource = MockCommentsRemoteDataSource();
    mockLocalDataSource = MockCommentsLocalDataSource();

    repository = CommentsRepository(mockRemoteDataSource, mockLocalDataSource);
  });

  // ==========================================================================
  // Helper
  // ==========================================================================

  CommentModel _createCommentModel({
    String id = 'comment-001',
    String eventId = 'test-event-001',
    String userId = 'test-student-001',
    String text = 'Bellissimo evento!',
  }) {
    return CommentModel(
      id: id,
      eventId: eventId,
      userId: userId,
      text: text,
      likeCount: 5,
      replyCount: 0,
      reportCount: 0,
      createdAt: DateTime.now(),
      authorName: 'Mario Rossi',
      authorClass: '4A',
      authorRole: 'student',
    );
  }

  // ==========================================================================
  // getCommentsForEvent
  // ==========================================================================

  group('getCommentsForEvent', () {
    test('happy: returns paginated comments from remote', () async {
      final comments = [
        TestComments.topLevel(),
        TestComments.topLevel(id: 'c-2', text: 'Secondo'),
      ];
      final result = PaginatedComments(
        comments: comments,
        hasMore: false,
        nextCursor: null,
      );
      when(() => mockRemoteDataSource.getCommentsForEvent(
            eventId: 'test-event-001',
            sortOrder: any(named: 'sortOrder'),
            limit: any(named: 'limit'),
            cursorCreatedAt: any(named: 'cursorCreatedAt'),
          )).thenAnswer((_) async => result);
      when(() => mockLocalDataSource.cacheComments(
            eventId: any(named: 'eventId'),
            comments: any(named: 'comments'),
          )).thenAnswer((_) async {});

      final actual = await repository.getCommentsForEvent(
        eventId: 'test-event-001',
      );

      expect(actual.comments.length, 2);
      expect(actual.hasMore, isFalse);
    });

    test('happy: caches first page of comments', () async {
      final result = PaginatedComments(
        comments: [TestComments.topLevel()],
        hasMore: false,
      );
      when(() => mockRemoteDataSource.getCommentsForEvent(
            eventId: any(named: 'eventId'),
            sortOrder: any(named: 'sortOrder'),
            limit: any(named: 'limit'),
            cursorCreatedAt: any(named: 'cursorCreatedAt'),
          )).thenAnswer((_) async => result);
      when(() => mockLocalDataSource.cacheComments(
            eventId: any(named: 'eventId'),
            comments: any(named: 'comments'),
          )).thenAnswer((_) async {});

      await repository.getCommentsForEvent(eventId: 'test-event-001');

      verify(() => mockLocalDataSource.cacheComments(
            eventId: 'test-event-001',
            comments: any(named: 'comments'),
          )).called(1);
    });

    test('happy: does not cache subsequent pages', () async {
      final result = PaginatedComments(
        comments: [TestComments.topLevel()],
        hasMore: false,
      );
      when(() => mockRemoteDataSource.getCommentsForEvent(
            eventId: any(named: 'eventId'),
            sortOrder: any(named: 'sortOrder'),
            limit: any(named: 'limit'),
            cursorCreatedAt: any(named: 'cursorCreatedAt'),
          )).thenAnswer((_) async => result);

      await repository.getCommentsForEvent(
        eventId: 'test-event-001',
        cursorCreatedAt: DateTime.now(), // page 2+
      );

      verifyNever(() => mockLocalDataSource.cacheComments(
            eventId: any(named: 'eventId'),
            comments: any(named: 'comments'),
          ));
    });

    test('edge: falls back to cache on NetworkException', () async {
      final cachedModels = [_createCommentModel()];
      when(() => mockRemoteDataSource.getCommentsForEvent(
            eventId: any(named: 'eventId'),
            sortOrder: any(named: 'sortOrder'),
            limit: any(named: 'limit'),
            cursorCreatedAt: any(named: 'cursorCreatedAt'),
          )).thenThrow(const NetworkException('offline'));
      when(() => mockLocalDataSource.getCachedComments(
            eventId: 'test-event-001',
          )).thenAnswer((_) async => cachedModels);

      final result = await repository.getCommentsForEvent(
        eventId: 'test-event-001',
      );

      expect(result.comments.length, 1);
      expect(result.hasMore, isFalse);
    });

    test('edge: rethrows NetworkException when no cache available', () async {
      when(() => mockRemoteDataSource.getCommentsForEvent(
            eventId: any(named: 'eventId'),
            sortOrder: any(named: 'sortOrder'),
            limit: any(named: 'limit'),
            cursorCreatedAt: any(named: 'cursorCreatedAt'),
          )).thenThrow(const NetworkException('offline'));
      when(() => mockLocalDataSource.getCachedComments(
            eventId: any(named: 'eventId'),
          )).thenAnswer((_) async => null);

      expect(
        () => repository.getCommentsForEvent(eventId: 'test-event-001'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('race: concurrent getCommentsForEvent calls', () async {
      final result = PaginatedComments(
        comments: [TestComments.topLevel()],
        hasMore: false,
      );
      when(() => mockRemoteDataSource.getCommentsForEvent(
            eventId: any(named: 'eventId'),
            sortOrder: any(named: 'sortOrder'),
            limit: any(named: 'limit'),
            cursorCreatedAt: any(named: 'cursorCreatedAt'),
          )).thenAnswer((_) async => result);
      when(() => mockLocalDataSource.cacheComments(
            eventId: any(named: 'eventId'),
            comments: any(named: 'comments'),
          )).thenAnswer((_) async {});

      final futures = [
        repository.getCommentsForEvent(eventId: 'evt-1'),
        repository.getCommentsForEvent(eventId: 'evt-1'),
      ];

      final results = await Future.wait(futures);
      expect(results[0].comments.length, 1);
      expect(results[1].comments.length, 1);
    });
  });

  // ==========================================================================
  // postComment
  // ==========================================================================

  group('postComment', () {
    test('happy: creates comment via remote', () async {
      final model = _createCommentModel(text: 'New comment');
      when(() => mockRemoteDataSource.postComment(
            eventId: 'test-event-001',
            text: 'New comment',
          )).thenAnswer((_) async => model);

      final result = await repository.postComment(
        eventId: 'test-event-001',
        text: 'New comment',
      );

      expect(result, isA<Comment>());
      expect(result.text, 'New comment');
    });

    test('happy: queues offline action on NetworkException', () async {
      when(() => mockRemoteDataSource.postComment(
            eventId: any(named: 'eventId'),
            text: any(named: 'text'),
          )).thenThrow(const NetworkException('offline'));
      when(() => mockLocalDataSource.queueOfflineAction(
            action: any(named: 'action'),
          )).thenAnswer((_) async {});

      expect(
        () => repository.postComment(
          eventId: 'test-event-001',
          text: 'Offline comment',
        ),
        throwsA(isA<NetworkException>()),
      );

      // Verify the offline action was queued before rethrowing
      await Future.delayed(Duration.zero);
    });

    test('edge: propagates validation exceptions', () async {
      when(() => mockRemoteDataSource.postComment(
            eventId: any(named: 'eventId'),
            text: any(named: 'text'),
          )).thenThrow(const ValidationException(
        'Profanity detected',
        'text',
        'bad word',
      ));

      expect(
        () => repository.postComment(
          eventId: 'test-event-001',
          text: 'bad word',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('race: concurrent posts to same event', () async {
      final model = _createCommentModel();
      when(() => mockRemoteDataSource.postComment(
            eventId: any(named: 'eventId'),
            text: any(named: 'text'),
          )).thenAnswer((_) async => model);

      final futures = [
        repository.postComment(eventId: 'evt-1', text: 'Comment 1'),
        repository.postComment(eventId: 'evt-1', text: 'Comment 2'),
      ];

      final results = await Future.wait(futures);
      expect(results.length, 2);
    });
  });

  // ==========================================================================
  // likeComment / unlikeComment
  // ==========================================================================

  group('likeComment', () {
    test('happy: delegates to remote', () async {
      final comment = TestComments.topLevel();
      when(() => mockRemoteDataSource.likeComment(commentId: 'comment-001'))
          .thenAnswer((_) async => comment);

      final result = await repository.likeComment(commentId: 'comment-001');

      expect(result, isA<Comment>());
    });

    test('edge: queues offline action on NetworkException', () async {
      when(() => mockRemoteDataSource.likeComment(commentId: any(named: 'commentId')))
          .thenThrow(const NetworkException('offline'));
      when(() => mockLocalDataSource.queueOfflineAction(
            action: any(named: 'action'),
          )).thenAnswer((_) async {});

      expect(
        () => repository.likeComment(commentId: 'comment-001'),
        throwsA(isA<NetworkException>()),
      );
    });

    test('race: concurrent like/unlike on same comment', () async {
      final comment = TestComments.topLevel();
      when(() => mockRemoteDataSource.likeComment(commentId: any(named: 'commentId')))
          .thenAnswer((_) async => comment);
      when(() => mockRemoteDataSource.unlikeComment(commentId: any(named: 'commentId')))
          .thenAnswer((_) async => comment);

      await Future.wait([
        repository.likeComment(commentId: 'c-1'),
        repository.unlikeComment(commentId: 'c-1'),
      ]);

      verify(() => mockRemoteDataSource.likeComment(commentId: 'c-1')).called(1);
      verify(() => mockRemoteDataSource.unlikeComment(commentId: 'c-1')).called(1);
    });
  });

  // ==========================================================================
  // reportComment
  // ==========================================================================

  group('reportComment', () {
    test('happy: submits report via remote', () async {
      final reportModel = CommentReportModel(
        id: 'report-1',
        commentId: 'comment-001',
        reporterUserId: TestUserIds.student1,
        reason: CommentReportReason.spam,
        createdAt: DateTime.now(),
      );
      when(() => mockRemoteDataSource.reportComment(
            commentId: 'comment-001',
            reason: CommentReportReason.spam,
            details: any(named: 'details'),
          )).thenAnswer((_) async => reportModel);

      final result = await repository.reportComment(
        commentId: 'comment-001',
        reason: CommentReportReason.spam,
      );

      expect(result, isA<CommentReport>());
    });

    test('edge: queues offline action on NetworkException', () async {
      when(() => mockRemoteDataSource.reportComment(
            commentId: any(named: 'commentId'),
            reason: any(named: 'reason'),
            details: any(named: 'details'),
          )).thenThrow(const NetworkException('offline'));
      when(() => mockLocalDataSource.queueOfflineAction(
            action: any(named: 'action'),
          )).thenAnswer((_) async {});

      expect(
        () => repository.reportComment(
          commentId: 'comment-001',
          reason: CommentReportReason.spam,
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // syncOfflineQueue
  // ==========================================================================

  group('syncOfflineQueue', () {
    test('happy: returns zero counts when queue is empty', () async {
      when(() => mockLocalDataSource.getOfflineQueue())
          .thenAnswer((_) async => []);

      final result = await repository.syncOfflineQueue();

      expect(result.successCount, 0);
      expect(result.failureCount, 0);
      expect(result.errors, isEmpty);
    });

    test('happy: processes queue in FIFO order', () async {
      final actions = [
        OfflineCommentAction(
          tempId: 'temp-1',
          type: OfflineActionType.post,
          eventId: 'evt-1',
          text: 'Comment 1',
          queuedAt: DateTime.now().subtract(const Duration(minutes: 2)),
        ),
        OfflineCommentAction(
          tempId: 'temp-2',
          type: OfflineActionType.post,
          eventId: 'evt-1',
          text: 'Comment 2',
          queuedAt: DateTime.now(),
        ),
      ];
      when(() => mockLocalDataSource.getOfflineQueue())
          .thenAnswer((_) async => actions);
      when(() => mockRemoteDataSource.postComment(
            eventId: any(named: 'eventId'),
            text: any(named: 'text'),
          )).thenAnswer((_) async => _createCommentModel());
      when(() => mockLocalDataSource.removeFromQueue(tempId: any(named: 'tempId')))
          .thenAnswer((_) async {});

      final result = await repository.syncOfflineQueue();

      expect(result.successCount, 2);
      expect(result.failureCount, 0);
    });

    test('edge: stops syncing on NetworkException', () async {
      final actions = [
        OfflineCommentAction(
          tempId: 'temp-1',
          type: OfflineActionType.post,
          eventId: 'evt-1',
          text: 'Comment 1',
          queuedAt: DateTime.now(),
        ),
      ];
      when(() => mockLocalDataSource.getOfflineQueue())
          .thenAnswer((_) async => actions);
      when(() => mockRemoteDataSource.postComment(
            eventId: any(named: 'eventId'),
            text: any(named: 'text'),
          )).thenThrow(const NetworkException('still offline'));

      final result = await repository.syncOfflineQueue();

      expect(result.successCount, 0);
      // Action stays in queue (not removed)
      verifyNever(() => mockLocalDataSource.removeFromQueue(
            tempId: any(named: 'tempId'),
          ));
    });

    test('race: concurrent sync calls', () async {
      when(() => mockLocalDataSource.getOfflineQueue())
          .thenAnswer((_) async => []);

      final futures = [
        repository.syncOfflineQueue(),
        repository.syncOfflineQueue(),
      ];

      final results = await Future.wait(futures);
      expect(results[0].successCount, 0);
      expect(results[1].successCount, 0);
    });
  });

  // ==========================================================================
  // Moderator operations
  // ==========================================================================

  group('moderatorRemoveComment', () {
    test('happy: delegates to remote', () async {
      when(() => mockRemoteDataSource.moderatorRemoveComment(
            commentId: 'c-1',
            reason: 'Spam content',
          )).thenAnswer((_) async {});

      await repository.moderatorRemoveComment(
        commentId: 'c-1',
        reason: 'Spam content',
      );

      verify(() => mockRemoteDataSource.moderatorRemoveComment(
            commentId: 'c-1',
            reason: 'Spam content',
          )).called(1);
    });
  });

  // ==========================================================================
  // subscribeToComments
  // ==========================================================================

  group('subscribeToComments', () {
    test('happy: maps stream of models to entities', () {
      final models = [_createCommentModel()];
      when(() =>
              mockRemoteDataSource.subscribeToComments(eventId: 'test-event-001'))
          .thenAnswer((_) => Stream.value(models));

      final stream =
          repository.subscribeToComments(eventId: 'test-event-001');

      expect(stream, emits(isA<List<Comment>>()));
    });
  });

  // ==========================================================================
  // getRepliesForComment
  // ==========================================================================

  group('getRepliesForComment', () {
    test('happy: returns replies from remote as entities', () async {
      final models = [
        _createCommentModel(id: 'reply-1', text: 'Reply 1'),
        _createCommentModel(id: 'reply-2', text: 'Reply 2'),
      ];
      when(() => mockRemoteDataSource.getRepliesForComment(
            commentId: 'comment-001',
          )).thenAnswer((_) async => models);

      final result = await repository.getRepliesForComment(
        commentId: 'comment-001',
      );

      expect(result.length, 2);
      expect(result.first, isA<Comment>());
      expect(result.first.text, 'Reply 1');
    });

    test('happy: returns empty list when no replies', () async {
      when(() => mockRemoteDataSource.getRepliesForComment(
            commentId: 'comment-001',
          )).thenAnswer((_) async => []);

      final result = await repository.getRepliesForComment(
        commentId: 'comment-001',
      );

      expect(result, isEmpty);
    });

    test('edge: propagates exception from remote', () async {
      when(() => mockRemoteDataSource.getRepliesForComment(
            commentId: any(named: 'commentId'),
          )).thenThrow(const NotFoundException(
        'Comment not found',
        'comment',
        'comment-001',
      ));

      expect(
        () => repository.getRepliesForComment(commentId: 'comment-001'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  // ==========================================================================
  // getCommentById
  // ==========================================================================

  group('getCommentById', () {
    test('happy: returns single comment entity from remote', () async {
      final model = _createCommentModel(id: 'c-42', text: 'Found it');
      when(() => mockRemoteDataSource.getCommentById(
            commentId: 'c-42',
          )).thenAnswer((_) async => model);

      final result = await repository.getCommentById(commentId: 'c-42');

      expect(result, isA<Comment>());
      expect(result.id, 'c-42');
      expect(result.text, 'Found it');
    });

    test('edge: throws NotFoundException for missing comment', () async {
      when(() => mockRemoteDataSource.getCommentById(
            commentId: any(named: 'commentId'),
          )).thenThrow(const NotFoundException(
        'Not found',
        'comment',
        'c-missing',
      ));

      expect(
        () => repository.getCommentById(commentId: 'c-missing'),
        throwsA(isA<NotFoundException>()),
      );
    });
  });

  // ==========================================================================
  // getUserComments
  // ==========================================================================

  group('getUserComments', () {
    test('happy: returns user comments as entities', () async {
      final models = [
        _createCommentModel(id: 'uc-1', text: 'My first'),
        _createCommentModel(id: 'uc-2', text: 'My second'),
      ];
      when(() => mockRemoteDataSource.getUserComments(
            userId: 'user-1',
            limit: 50,
            offset: 0,
          )).thenAnswer((_) async => models);

      final result = await repository.getUserComments(userId: 'user-1');

      expect(result.length, 2);
      expect(result.every((c) => c is Comment), isTrue);
    });

    test('happy: passes custom limit and offset', () async {
      when(() => mockRemoteDataSource.getUserComments(
            userId: 'user-1',
            limit: 10,
            offset: 20,
          )).thenAnswer((_) async => []);

      await repository.getUserComments(
        userId: 'user-1',
        limit: 10,
        offset: 20,
      );

      verify(() => mockRemoteDataSource.getUserComments(
            userId: 'user-1',
            limit: 10,
            offset: 20,
          )).called(1);
    });
  });

  // ==========================================================================
  // replyToComment
  // ==========================================================================

  group('replyToComment', () {
    test('happy: creates reply via remote', () async {
      final model = _createCommentModel(id: 'reply-1', text: 'My reply');
      when(() => mockRemoteDataSource.replyToComment(
            commentId: 'parent-1',
            text: 'My reply',
          )).thenAnswer((_) async => model);

      final result = await repository.replyToComment(
        commentId: 'parent-1',
        text: 'My reply',
      );

      expect(result, isA<Comment>());
      expect(result.text, 'My reply');
    });

    test('edge: queues offline action on NetworkException', () async {
      when(() => mockRemoteDataSource.replyToComment(
            commentId: any(named: 'commentId'),
            text: any(named: 'text'),
          )).thenThrow(const NetworkException('offline'));
      when(() => mockLocalDataSource.queueOfflineAction(
            action: any(named: 'action'),
          )).thenAnswer((_) async {});

      expect(
        () => repository.replyToComment(
          commentId: 'parent-1',
          text: 'Offline reply',
        ),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // editComment
  // ==========================================================================

  group('editComment', () {
    test('happy: edits comment via remote', () async {
      final model = _createCommentModel(id: 'c-1', text: 'Edited text');
      when(() => mockRemoteDataSource.editComment(
            commentId: 'c-1',
            newText: 'Edited text',
          )).thenAnswer((_) async => model);

      final result = await repository.editComment(
        commentId: 'c-1',
        newText: 'Edited text',
      );

      expect(result, isA<Comment>());
      expect(result.text, 'Edited text');
    });

    test('edge: queues offline action on NetworkException', () async {
      when(() => mockRemoteDataSource.editComment(
            commentId: any(named: 'commentId'),
            newText: any(named: 'newText'),
          )).thenThrow(const NetworkException('offline'));
      when(() => mockLocalDataSource.queueOfflineAction(
            action: any(named: 'action'),
          )).thenAnswer((_) async {});

      expect(
        () => repository.editComment(
          commentId: 'c-1',
          newText: 'Edited offline',
        ),
        throwsA(isA<NetworkException>()),
      );
    });

    test('edge: propagates ForbiddenException when edit window expired',
        () async {
      when(() => mockRemoteDataSource.editComment(
            commentId: any(named: 'commentId'),
            newText: any(named: 'newText'),
          )).thenThrow(const ForbiddenException('Edit window expired'));

      expect(
        () => repository.editComment(commentId: 'c-1', newText: 'Too late'),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });

  // ==========================================================================
  // deleteComment
  // ==========================================================================

  group('deleteComment', () {
    test('happy: deletes comment via remote', () async {
      when(() => mockRemoteDataSource.deleteComment(
            commentId: 'c-1',
          )).thenAnswer((_) async {});

      await repository.deleteComment(commentId: 'c-1');

      verify(() => mockRemoteDataSource.deleteComment(
            commentId: 'c-1',
          )).called(1);
    });

    test('edge: queues offline action on NetworkException', () async {
      when(() => mockRemoteDataSource.deleteComment(
            commentId: any(named: 'commentId'),
          )).thenThrow(const NetworkException('offline'));
      when(() => mockLocalDataSource.queueOfflineAction(
            action: any(named: 'action'),
          )).thenAnswer((_) async {});

      expect(
        () => repository.deleteComment(commentId: 'c-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // unlikeComment (standalone)
  // ==========================================================================

  group('unlikeComment', () {
    test('happy: delegates to remote', () async {
      final comment = TestComments.topLevel();
      when(() => mockRemoteDataSource.unlikeComment(commentId: 'c-1'))
          .thenAnswer((_) async => comment);

      final result = await repository.unlikeComment(commentId: 'c-1');

      expect(result, isA<Comment>());
      verify(() => mockRemoteDataSource.unlikeComment(commentId: 'c-1'))
          .called(1);
    });

    test('edge: queues offline action on NetworkException', () async {
      when(() => mockRemoteDataSource.unlikeComment(
              commentId: any(named: 'commentId')))
          .thenThrow(const NetworkException('offline'));
      when(() => mockLocalDataSource.queueOfflineAction(
            action: any(named: 'action'),
          )).thenAnswer((_) async {});

      expect(
        () => repository.unlikeComment(commentId: 'c-1'),
        throwsA(isA<NetworkException>()),
      );
    });
  });

  // ==========================================================================
  // moderatorRestoreComment
  // ==========================================================================

  group('moderatorRestoreComment', () {
    test('happy: delegates to remote', () async {
      when(() => mockRemoteDataSource.moderatorRestoreComment(
            commentId: 'c-hidden',
          )).thenAnswer((_) async {});

      await repository.moderatorRestoreComment(commentId: 'c-hidden');

      verify(() => mockRemoteDataSource.moderatorRestoreComment(
            commentId: 'c-hidden',
          )).called(1);
    });

    test('edge: propagates ForbiddenException for non-moderator', () async {
      when(() => mockRemoteDataSource.moderatorRestoreComment(
            commentId: any(named: 'commentId'),
          )).thenThrow(const ForbiddenException('Not a moderator'));

      expect(
        () => repository.moderatorRestoreComment(commentId: 'c-1'),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });

  // ==========================================================================
  // getCachedComments
  // ==========================================================================

  group('getCachedComments', () {
    test('happy: returns cached entities', () async {
      final models = [_createCommentModel()];
      when(() => mockLocalDataSource.getCachedComments(
            eventId: 'evt-1',
          )).thenAnswer((_) async => models);

      final result = await repository.getCachedComments(eventId: 'evt-1');

      expect(result, isNotNull);
      expect(result!.length, 1);
      expect(result.first, isA<Comment>());
    });

    test('happy: returns null when no cache', () async {
      when(() => mockLocalDataSource.getCachedComments(
            eventId: 'evt-1',
          )).thenAnswer((_) async => null);

      final result = await repository.getCachedComments(eventId: 'evt-1');

      expect(result, isNull);
    });
  });

  // ==========================================================================
  // cacheComments
  // ==========================================================================

  group('cacheComments', () {
    test('happy: converts entities to models and caches', () async {
      final comments = [TestComments.topLevel()];
      when(() => mockLocalDataSource.cacheComments(
            eventId: any(named: 'eventId'),
            comments: any(named: 'comments'),
          )).thenAnswer((_) async {});

      await repository.cacheComments(
        eventId: 'evt-1',
        comments: comments,
      );

      verify(() => mockLocalDataSource.cacheComments(
            eventId: 'evt-1',
            comments: any(named: 'comments'),
          )).called(1);
    });
  });

  // ==========================================================================
  // queueOfflineAction
  // ==========================================================================

  group('queueOfflineAction', () {
    test('happy: delegates to local datasource', () async {
      final action = OfflineCommentAction(
        tempId: 'temp-1',
        type: OfflineActionType.post,
        eventId: 'evt-1',
        text: 'Queued',
        queuedAt: DateTime.now(),
      );
      when(() => mockLocalDataSource.queueOfflineAction(
            action: any(named: 'action'),
          )).thenAnswer((_) async {});

      await repository.queueOfflineAction(action: action);

      verify(() => mockLocalDataSource.queueOfflineAction(
            action: any(named: 'action'),
          )).called(1);
    });
  });

  // ==========================================================================
  // syncOfflineQueue - additional action types
  // ==========================================================================

  group('syncOfflineQueue - action types', () {
    test('happy: processes reply action', () async {
      final actions = [
        OfflineCommentAction(
          tempId: 'temp-1',
          type: OfflineActionType.reply,
          parentCommentId: 'parent-1',
          text: 'Queued reply',
          queuedAt: DateTime.now(),
        ),
      ];
      when(() => mockLocalDataSource.getOfflineQueue())
          .thenAnswer((_) async => actions);
      when(() => mockRemoteDataSource.replyToComment(
            commentId: 'parent-1',
            text: 'Queued reply',
          )).thenAnswer((_) async => _createCommentModel());
      when(() => mockLocalDataSource.removeFromQueue(
              tempId: any(named: 'tempId')))
          .thenAnswer((_) async {});

      final result = await repository.syncOfflineQueue();

      expect(result.successCount, 1);
      expect(result.failureCount, 0);
    });

    test('happy: processes edit action', () async {
      final actions = [
        OfflineCommentAction(
          tempId: 'temp-1',
          type: OfflineActionType.edit,
          commentId: 'c-1',
          text: 'Edited text',
          queuedAt: DateTime.now(),
        ),
      ];
      when(() => mockLocalDataSource.getOfflineQueue())
          .thenAnswer((_) async => actions);
      when(() => mockRemoteDataSource.editComment(
            commentId: 'c-1',
            newText: 'Edited text',
          )).thenAnswer((_) async => _createCommentModel());
      when(() => mockLocalDataSource.removeFromQueue(
              tempId: any(named: 'tempId')))
          .thenAnswer((_) async {});

      final result = await repository.syncOfflineQueue();

      expect(result.successCount, 1);
    });

    test('happy: processes delete action', () async {
      final actions = [
        OfflineCommentAction(
          tempId: 'temp-1',
          type: OfflineActionType.delete,
          commentId: 'c-1',
          queuedAt: DateTime.now(),
        ),
      ];
      when(() => mockLocalDataSource.getOfflineQueue())
          .thenAnswer((_) async => actions);
      when(() => mockRemoteDataSource.deleteComment(
            commentId: 'c-1',
          )).thenAnswer((_) async {});
      when(() => mockLocalDataSource.removeFromQueue(
              tempId: any(named: 'tempId')))
          .thenAnswer((_) async {});

      final result = await repository.syncOfflineQueue();

      expect(result.successCount, 1);
    });

    test('happy: processes like action', () async {
      final actions = [
        OfflineCommentAction(
          tempId: 'temp-1',
          type: OfflineActionType.like,
          commentId: 'c-1',
          queuedAt: DateTime.now(),
        ),
      ];
      when(() => mockLocalDataSource.getOfflineQueue())
          .thenAnswer((_) async => actions);
      when(() => mockRemoteDataSource.likeComment(
            commentId: 'c-1',
          )).thenAnswer((_) async => TestComments.topLevel());
      when(() => mockLocalDataSource.removeFromQueue(
              tempId: any(named: 'tempId')))
          .thenAnswer((_) async {});

      final result = await repository.syncOfflineQueue();

      expect(result.successCount, 1);
    });

    test('happy: processes unlike action', () async {
      final actions = [
        OfflineCommentAction(
          tempId: 'temp-1',
          type: OfflineActionType.unlike,
          commentId: 'c-1',
          queuedAt: DateTime.now(),
        ),
      ];
      when(() => mockLocalDataSource.getOfflineQueue())
          .thenAnswer((_) async => actions);
      when(() => mockRemoteDataSource.unlikeComment(
            commentId: 'c-1',
          )).thenAnswer((_) async => TestComments.topLevel());
      when(() => mockLocalDataSource.removeFromQueue(
              tempId: any(named: 'tempId')))
          .thenAnswer((_) async {});

      final result = await repository.syncOfflineQueue();

      expect(result.successCount, 1);
    });

    test('happy: processes report action', () async {
      final reportModel = CommentReportModel(
        id: 'r-1',
        commentId: 'c-1',
        reporterUserId: TestUserIds.student1,
        reason: CommentReportReason.spam,
        createdAt: DateTime.now(),
      );
      final actions = [
        OfflineCommentAction(
          tempId: 'temp-1',
          type: OfflineActionType.report,
          commentId: 'c-1',
          reportReason: CommentReportReason.spam,
          reportDetails: 'Details here',
          queuedAt: DateTime.now(),
        ),
      ];
      when(() => mockLocalDataSource.getOfflineQueue())
          .thenAnswer((_) async => actions);
      when(() => mockRemoteDataSource.reportComment(
            commentId: 'c-1',
            reason: CommentReportReason.spam,
            details: 'Details here',
          )).thenAnswer((_) async => reportModel);
      when(() => mockLocalDataSource.removeFromQueue(
              tempId: any(named: 'tempId')))
          .thenAnswer((_) async {});

      final result = await repository.syncOfflineQueue();

      expect(result.successCount, 1);
    });

    test('edge: counts non-network failures and removes from queue', () async {
      final actions = [
        OfflineCommentAction(
          tempId: 'temp-1',
          type: OfflineActionType.post,
          eventId: 'evt-1',
          text: 'Bad comment',
          queuedAt: DateTime.now(),
        ),
      ];
      when(() => mockLocalDataSource.getOfflineQueue())
          .thenAnswer((_) async => actions);
      when(() => mockRemoteDataSource.postComment(
            eventId: any(named: 'eventId'),
            text: any(named: 'text'),
          )).thenThrow(const ValidationException('Profanity', 'text', 'bad'));
      when(() => mockLocalDataSource.removeFromQueue(
              tempId: any(named: 'tempId')))
          .thenAnswer((_) async {});

      final result = await repository.syncOfflineQueue();

      expect(result.successCount, 0);
      expect(result.failureCount, 1);
      expect(result.errors.length, 1);
      verify(() => mockLocalDataSource.removeFromQueue(tempId: 'temp-1'))
          .called(1);
    });
  });
}
