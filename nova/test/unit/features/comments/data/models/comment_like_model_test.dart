import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/comments/data/models/comment_like_model.dart';
import 'package:nova/features/comments/domain/entities/comment_like.dart';

void main() {
  group('CommentLikeModel', () {
    final now = DateTime(2025, 6, 1, 12, 0);
    final nowIso = now.toIso8601String();

    Map<String, dynamic> validJson({
      String commentId = 'comment-001',
      String userId = 'user-001',
      String? deletedAt,
    }) {
      return {
        'comment_id': commentId,
        'user_id': userId,
        'created_at': nowIso,
        'deleted_at': deletedAt,
      };
    }

    // ========================================================================
    // HAPPY PATH
    // ========================================================================

    group('fromJson and toJson', () {
      test('deserializes all fields from JSON', () {
        final model = CommentLikeModel.fromJson(validJson());

        expect(model.commentId, 'comment-001');
        expect(model.userId, 'user-001');
        expect(model.createdAt, now);
        expect(model.deletedAt, isNull);
      });

      test('serializes all fields to JSON', () {
        final model = CommentLikeModel.fromJson(validJson());
        final json = model.toJson();

        expect(json['comment_id'], 'comment-001');
        expect(json['user_id'], 'user-001');
        expect(json['created_at'], nowIso);
        expect(json['deleted_at'], isNull);
      });
    });

    group('entity conversion', () {
      test('toEntity creates CommentLike entity', () {
        final model = CommentLikeModel.fromJson(validJson());
        final entity = model.toEntity();

        expect(entity, isA<CommentLike>());
        expect(entity.commentId, model.commentId);
        expect(entity.userId, model.userId);
        expect(entity.createdAt, model.createdAt);
      });

      test('fromEntity creates model from entity', () {
        final entity = CommentLike(
          commentId: 'c-1',
          userId: 'u-1',
          createdAt: now,
        );

        final model = CommentLikeModel.fromEntity(entity);
        expect(model.commentId, entity.commentId);
        expect(model.userId, entity.userId);
      });
    });

    // ========================================================================
    // EDGE CASES
    // ========================================================================

    group('edge cases', () {
      test('fromJson with deletedAt parses correctly', () {
        final deletedIso = now.add(const Duration(hours: 1)).toIso8601String();
        final model = CommentLikeModel.fromJson(
          validJson(deletedAt: deletedIso),
        );

        expect(model.deletedAt, now.add(const Duration(hours: 1)));
      });

      test('equality is based on commentId and userId', () {
        final a = CommentLikeModel.fromJson(
          validJson(commentId: 'c1', userId: 'u1'),
        );
        final b = CommentLikeModel.fromJson(
          validJson(commentId: 'c1', userId: 'u1'),
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different keys are not equal', () {
        final a = CommentLikeModel.fromJson(
          validJson(commentId: 'c1', userId: 'u1'),
        );
        final b = CommentLikeModel.fromJson(
          validJson(commentId: 'c1', userId: 'u2'),
        );
        expect(a, isNot(equals(b)));
      });

      test('roundtrip: fromJson -> toJson -> fromJson preserves data', () {
        final original = CommentLikeModel.fromJson(validJson());
        final json = original.toJson();
        final restored = CommentLikeModel.fromJson(json);

        expect(restored.commentId, original.commentId);
        expect(restored.userId, original.userId);
        expect(restored.createdAt, original.createdAt);
      });

      test('toString contains key fields', () {
        final model = CommentLikeModel.fromJson(validJson());
        final str = model.toString();
        expect(str, contains('comment-001'));
        expect(str, contains('user-001'));
      });
    });
  });
}
