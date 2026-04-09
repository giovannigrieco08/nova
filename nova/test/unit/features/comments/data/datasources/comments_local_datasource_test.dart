import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:nova/features/comments/data/datasources/comments_local_datasource.dart';
import 'package:nova/features/comments/data/models/comment_model.dart';
import 'package:nova/features/comments/domain/entities/comment.dart';
import 'package:nova/features/comments/domain/entities/comment_report.dart';
import 'package:nova/features/comments/domain/repositories/comments_repository_interface.dart';

// ==========================================================================
// MOCK CLASSES
// ==========================================================================

class MockHiveBox extends Mock implements Box<Map<dynamic, dynamic>> {}

void main() {
  // Note: CommentsLocalDataSource uses Hive.openBox internally via init().
  // For unit tests, we test the data model logic and verify behavior via
  // the public API where possible. The OfflineCommentAction parsing logic
  // is tested here since it's critical for offline sync.

  // ==========================================================================
  // OfflineCommentAction
  // ==========================================================================

  group('OfflineCommentAction', () {
    test('happy: creates post action with all fields', () {
      final action = OfflineCommentAction(
        tempId: 'temp-uuid-1',
        type: OfflineActionType.post,
        eventId: 'evt-1',
        text: 'New comment',
        queuedAt: DateTime(2025, 6, 1),
      );

      expect(action.tempId, 'temp-uuid-1');
      expect(action.type, OfflineActionType.post);
      expect(action.eventId, 'evt-1');
      expect(action.text, 'New comment');
      expect(action.commentId, isNull);
    });

    test('happy: creates reply action with parentCommentId', () {
      final action = OfflineCommentAction(
        tempId: 'temp-uuid-2',
        type: OfflineActionType.reply,
        parentCommentId: 'parent-1',
        text: 'Reply text',
        queuedAt: DateTime(2025, 6, 1),
      );

      expect(action.type, OfflineActionType.reply);
      expect(action.parentCommentId, 'parent-1');
    });

    test('happy: creates report action with reason and details', () {
      final action = OfflineCommentAction(
        tempId: 'temp-uuid-3',
        type: OfflineActionType.report,
        commentId: 'c-1',
        reportReason: CommentReportReason.spam,
        reportDetails: 'Clearly spam content',
        queuedAt: DateTime(2025, 6, 1),
      );

      expect(action.type, OfflineActionType.report);
      expect(action.reportReason, CommentReportReason.spam);
      expect(action.reportDetails, 'Clearly spam content');
    });

    test('happy: creates like/unlike actions', () {
      final like = OfflineCommentAction(
        tempId: 'temp-like',
        type: OfflineActionType.like,
        commentId: 'c-1',
        queuedAt: DateTime(2025, 6, 1),
      );

      final unlike = OfflineCommentAction(
        tempId: 'temp-unlike',
        type: OfflineActionType.unlike,
        commentId: 'c-1',
        queuedAt: DateTime(2025, 6, 1),
      );

      expect(like.type, OfflineActionType.like);
      expect(unlike.type, OfflineActionType.unlike);
    });
  });

  // ==========================================================================
  // OfflineActionType
  // ==========================================================================

  group('OfflineActionType', () {
    test('happy: has all expected values', () {
      expect(OfflineActionType.values, hasLength(7));
      expect(OfflineActionType.values, containsAll([
        OfflineActionType.post,
        OfflineActionType.reply,
        OfflineActionType.edit,
        OfflineActionType.delete,
        OfflineActionType.like,
        OfflineActionType.unlike,
        OfflineActionType.report,
      ]));
    });
  });

  // ==========================================================================
  // OfflineSyncResult
  // ==========================================================================

  group('OfflineSyncResult', () {
    test('happy: represents successful sync', () {
      const result = OfflineSyncResult(
        successCount: 5,
        failureCount: 0,
        errors: [],
      );

      expect(result.successCount, 5);
      expect(result.failureCount, 0);
      expect(result.errors, isEmpty);
    });

    test('happy: represents partial sync with errors', () {
      final action = OfflineCommentAction(
        tempId: 'temp-1',
        type: OfflineActionType.post,
        eventId: 'evt-1',
        text: 'text',
        queuedAt: DateTime.now(),
      );
      final error = OfflineActionError(action, Exception('Server error'));

      final result = OfflineSyncResult(
        successCount: 3,
        failureCount: 2,
        errors: [error],
      );

      expect(result.successCount, 3);
      expect(result.failureCount, 2);
      expect(result.errors.length, 1);
    });

    test('edge: represents empty queue result', () {
      const result = OfflineSyncResult(
        successCount: 0,
        failureCount: 0,
        errors: [],
      );

      expect(result.successCount, 0);
      expect(result.failureCount, 0);
    });
  });

  // ==========================================================================
  // PaginatedComments
  // ==========================================================================

  group('PaginatedComments', () {
    test('happy: represents a full page with more results', () {
      final result = PaginatedComments(
        comments: List.generate(
          20,
          (i) => Comment(
            id: 'c-$i',
            eventId: 'evt-1',
            userId: 'user-1',
            text: 'Comment $i',
            createdAt: DateTime.now(),
            authorName: 'User',
            authorRole: 'student',
          ),
        ),
        hasMore: true,
        nextCursor: DateTime.now(),
      );

      expect(result.comments.length, 20);
      expect(result.hasMore, isTrue);
      expect(result.nextCursor, isNotNull);
    });

    test('happy: represents last page', () {
      const result = PaginatedComments(
        comments: [],
        hasMore: false,
        nextCursor: null,
      );

      expect(result.comments, isEmpty);
      expect(result.hasMore, isFalse);
      expect(result.nextCursor, isNull);
    });
  });

  // ==========================================================================
  // CommentModel serialization for cache
  // ==========================================================================

  group('CommentModel cache serialization', () {
    test('happy: fromJson/toJson roundtrip for caching', () {
      final json = {
        'id': 'c-1',
        'event_id': 'evt-1',
        'user_id': 'user-1',
        'text': 'Hello',
        'like_count': 3,
        'reply_count': 1,
        'report_count': 0,
        'created_at': '2025-06-01T12:00:00.000Z',
        'author_name': 'Mario Rossi',
        'author_class': '4A',
        'author_role': 'student',
      };

      final model = CommentModel.fromJson(json);
      final serialized = model.toJson();
      final restored = CommentModel.fromJson(serialized);

      expect(restored.id, model.id);
      expect(restored.text, model.text);
      expect(restored.likeCount, model.likeCount);
      expect(restored.authorName, model.authorName);
    });

    test('edge: handles null optional fields in cache', () {
      final json = {
        'id': 'c-2',
        'event_id': 'evt-1',
        'user_id': 'user-1',
        'text': 'Minimal comment',
        'created_at': '2025-06-01T12:00:00.000Z',
      };

      final model = CommentModel.fromJson(json);

      expect(model.parentCommentId, isNull);
      expect(model.deletedAt, isNull);
      expect(model.hiddenAt, isNull);
      expect(model.authorName, isNull);
      expect(model.authorAvatarUrl, isNull);
    });

    test('edge: handles fromEntity and back to entity for cache path', () {
      final entity = Comment(
        id: 'c-3',
        eventId: 'evt-1',
        userId: 'user-1',
        text: 'From entity',
        likeCount: 10,
        replyCount: 2,
        reportCount: 0,
        createdAt: DateTime(2025, 6, 1),
        authorName: 'Lucia Bianchi',
        authorClass: '3B',
        authorRole: 'student',
      );

      final model = CommentModel.fromEntity(entity);
      final backToEntity = model.toEntity();

      expect(backToEntity.id, entity.id);
      expect(backToEntity.text, entity.text);
      expect(backToEntity.likeCount, entity.likeCount);
      expect(backToEntity.authorName, entity.authorName);
    });
  });
}
