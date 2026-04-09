import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/comments/data/models/comment_model.dart';
import 'package:nova/features/comments/domain/entities/comment.dart';

void main() {
  group('CommentModel', () {
    final now = DateTime(2025, 6, 1, 12, 0);
    final nowIso = now.toIso8601String();

    Map<String, dynamic> validJson({
      String id = 'comment-001',
      String? parentCommentId,
      int? depth,
      Map<String, dynamic>? profiles,
      List<Map<String, dynamic>>? replies,
      bool? isLiked,
    }) {
      return {
        'id': id,
        'event_id': 'event-001',
        'user_id': 'user-001',
        'parent_comment_id': parentCommentId,
        'depth': depth ?? 0,
        'text': 'Test comment',
        'like_count': 5,
        'reply_count': 2,
        'report_count': 0,
        'deleted_at': null,
        'deleted_by_user_id': null,
        'hidden_at': null,
        'hidden_reason': null,
        'moderator_id': null,
        'created_at': nowIso,
        'updated_at': null,
        if (profiles != null) 'profiles': profiles,
        if (profiles == null) 'author_name': 'Mario Rossi',
        if (profiles == null) 'author_avatar_url': 'https://example.com/a.jpg',
        if (profiles == null) 'author_class': '4A',
        if (profiles == null) 'author_role': 'student',
        'is_liked_by_current_user': isLiked ?? false,
        if (replies != null) 'replies': replies,
      };
    }

    // ========================================================================
    // HAPPY PATH
    // ========================================================================

    group('fromJson', () {
      test('deserializes all fields from flat JSON', () {
        final model = CommentModel.fromJson(validJson());

        expect(model.id, 'comment-001');
        expect(model.eventId, 'event-001');
        expect(model.userId, 'user-001');
        expect(model.depth, 0);
        expect(model.text, 'Test comment');
        expect(model.likeCount, 5);
        expect(model.replyCount, 2);
        expect(model.authorName, 'Mario Rossi');
        expect(model.authorAvatarUrl, 'https://example.com/a.jpg');
        expect(model.authorClass, '4A');
        expect(model.authorRole, 'student');
        expect(model.isLikedByCurrentUser, isFalse);
        expect(model.createdAt, now);
        expect(model.deletedAt, isNull);
      });

      test('deserializes author data from nested profiles object', () {
        final model = CommentModel.fromJson(validJson(
          profiles: {
            'full_name': 'Lucia Bianchi',
            'avatar_url': 'https://example.com/lucia.jpg',
            'class': '3B',
            'role': 'student',
          },
        ));

        expect(model.authorName, 'Lucia Bianchi');
        expect(model.authorAvatarUrl, 'https://example.com/lucia.jpg');
        expect(model.authorClass, '3B');
        expect(model.authorRole, 'student');
      });

      test('deserializes replies recursively', () {
        final model = CommentModel.fromJson(validJson(
          replies: [
            validJson(id: 'reply-001', parentCommentId: 'comment-001', depth: 1),
          ],
        ));

        expect(model.replies, hasLength(1));
        expect(model.replies!.first.id, 'reply-001');
        expect(model.replies!.first.depth, 1);
      });

      test('deserializes datetime fields correctly', () {
        final json = validJson();
        json['deleted_at'] = '2025-06-01T15:00:00.000';
        json['hidden_at'] = '2025-06-01T16:00:00.000';
        json['updated_at'] = '2025-06-01T13:00:00.000';

        final model = CommentModel.fromJson(json);
        expect(model.deletedAt, DateTime(2025, 6, 1, 15, 0));
        expect(model.hiddenAt, DateTime(2025, 6, 1, 16, 0));
        expect(model.updatedAt, DateTime(2025, 6, 1, 13, 0));
      });
    });

    group('toJson', () {
      test('serializes all fields to snake_case JSON', () {
        final model = CommentModel.fromJson(validJson());
        final json = model.toJson();

        expect(json['id'], 'comment-001');
        expect(json['event_id'], 'event-001');
        expect(json['user_id'], 'user-001');
        expect(json['depth'], 0);
        expect(json['text'], 'Test comment');
        expect(json['like_count'], 5);
        expect(json['reply_count'], 2);
        expect(json['created_at'], nowIso);
        expect(json['author_name'], 'Mario Rossi');
        expect(json['is_liked_by_current_user'], isFalse);
      });

      test('serializes null datetime fields as null', () {
        final model = CommentModel.fromJson(validJson());
        final json = model.toJson();

        expect(json['deleted_at'], isNull);
        expect(json['hidden_at'], isNull);
        expect(json['updated_at'], isNull);
      });
    });

    group('toEntity', () {
      test('converts model to Comment entity with all fields', () {
        final model = CommentModel.fromJson(validJson());
        final entity = model.toEntity();

        expect(entity, isA<Comment>());
        expect(entity.id, model.id);
        expect(entity.eventId, model.eventId);
        expect(entity.userId, model.userId);
        expect(entity.text, model.text);
        expect(entity.likeCount, model.likeCount);
        expect(entity.authorName, model.authorName);
      });

      test('toEntity converts replies recursively', () {
        final model = CommentModel.fromJson(validJson(
          replies: [
            validJson(id: 'reply-001', parentCommentId: 'comment-001', depth: 1),
          ],
        ));

        final entity = model.toEntity();
        expect(entity.replies, hasLength(1));
        expect(entity.replies!.first.id, 'reply-001');
        expect(entity.replies!.first, isA<Comment>());
      });
    });

    group('fromEntity', () {
      test('creates model from Comment entity', () {
        final entity = Comment(
          id: 'c-1',
          eventId: 'e-1',
          userId: 'u-1',
          text: 'Hello',
          createdAt: now,
          likeCount: 3,
          authorName: 'Test',
        );

        final model = CommentModel.fromEntity(entity);
        expect(model.id, entity.id);
        expect(model.text, entity.text);
        expect(model.likeCount, entity.likeCount);
        expect(model.authorName, entity.authorName);
      });
    });

    // ========================================================================
    // EDGE CASES
    // ========================================================================

    group('edge cases', () {
      test('fromJson defaults depth from parentCommentId when depth is null', () {
        final json = validJson();
        json.remove('depth');
        json['parent_comment_id'] = 'parent-001';

        final model = CommentModel.fromJson(json);
        expect(model.depth, 1); // fallback: has parent -> 1
      });

      test('fromJson defaults depth to 0 when both depth and parent are null', () {
        final json = validJson();
        json.remove('depth');
        json['parent_comment_id'] = null;

        final model = CommentModel.fromJson(json);
        expect(model.depth, 0);
      });

      test('fromJson defaults counters to 0 when missing', () {
        final json = validJson();
        json.remove('like_count');
        json.remove('reply_count');
        json.remove('report_count');

        final model = CommentModel.fromJson(json);
        expect(model.likeCount, 0);
        expect(model.replyCount, 0);
        expect(model.reportCount, 0);
      });

      test('fromJson defaults isLikedByCurrentUser to false when missing', () {
        final json = validJson();
        json.remove('is_liked_by_current_user');

        final model = CommentModel.fromJson(json);
        expect(model.isLikedByCurrentUser, isFalse);
      });

      test('fromJson handles null replies', () {
        final model = CommentModel.fromJson(validJson());
        expect(model.replies, isNull);
      });

      test('toJson does not include replies key', () {
        final model = CommentModel.fromJson(validJson(
          replies: [
            validJson(id: 'r-1', parentCommentId: 'comment-001', depth: 1),
          ],
        ));

        final json = model.toJson();
        expect(json.containsKey('replies'), isFalse);
      });

      test('equality is based on id only', () {
        final a = CommentModel.fromJson(validJson(id: 'same'));
        final b = CommentModel.fromJson(validJson(id: 'same'));

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different ids are not equal', () {
        final a = CommentModel.fromJson(validJson(id: 'id-1'));
        final b = CommentModel.fromJson(validJson(id: 'id-2'));
        expect(a, isNot(equals(b)));
      });

      test('roundtrip: fromJson -> toJson -> fromJson preserves data', () {
        final original = CommentModel.fromJson(validJson());
        final json = original.toJson();
        final restored = CommentModel.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.text, original.text);
        expect(restored.likeCount, original.likeCount);
        expect(restored.authorName, original.authorName);
        expect(restored.createdAt, original.createdAt);
      });

      test('toString truncates long text', () {
        final json = validJson();
        json['text'] = 'A' * 100;
        final model = CommentModel.fromJson(json);
        final str = model.toString();
        expect(str, contains('A' * 50));
      });
    });
  });
}
