import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/comments/domain/entities/comment_like.dart';

void main() {
  group('CommentLike Entity', () {
    final now = DateTime(2025, 6, 1, 12, 0);

    CommentLike createLike({
      String commentId = 'comment-001',
      String userId = 'user-001',
      DateTime? createdAt,
      DateTime? deletedAt,
    }) {
      return CommentLike(
        commentId: commentId,
        userId: userId,
        createdAt: createdAt ?? now,
        deletedAt: deletedAt,
      );
    }

    // ========================================================================
    // HAPPY PATH
    // ========================================================================

    group('creation and properties', () {
      test('creates like with required fields', () {
        final like = createLike();

        expect(like.commentId, 'comment-001');
        expect(like.userId, 'user-001');
        expect(like.createdAt, now);
        expect(like.deletedAt, isNull);
        expect(like.isDeleted, isFalse);
      });

      test('isDeleted returns true when deletedAt is set', () {
        final like = createLike(deletedAt: now);
        expect(like.isDeleted, isTrue);
      });
    });

    group('copyWith and equality', () {
      test('copyWith returns new instance with updated fields', () {
        final like = createLike();
        final updated = like.copyWith(userId: 'user-002');

        expect(updated.userId, 'user-002');
        expect(updated.commentId, 'comment-001'); // unchanged
      });

      test('equality is based on commentId and userId', () {
        final a = createLike(commentId: 'c1', userId: 'u1');
        final b = createLike(
          commentId: 'c1',
          userId: 'u1',
          createdAt: now.add(const Duration(hours: 1)),
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different commentId or userId means not equal', () {
        final a = createLike(commentId: 'c1', userId: 'u1');
        final b = createLike(commentId: 'c1', userId: 'u2');
        final c = createLike(commentId: 'c2', userId: 'u1');

        expect(a, isNot(equals(b)));
        expect(a, isNot(equals(c)));
      });
    });

    // ========================================================================
    // EDGE CASES
    // ========================================================================

    group('edge cases', () {
      test('copyWith preserves all fields when no arguments given', () {
        final like = createLike(deletedAt: now);
        final copy = like.copyWith();

        expect(copy.commentId, like.commentId);
        expect(copy.userId, like.userId);
        expect(copy.createdAt, like.createdAt);
        expect(copy.deletedAt, like.deletedAt);
      });

      test('toString contains key fields', () {
        final like = createLike();
        final str = like.toString();

        expect(str, contains('comment-001'));
        expect(str, contains('user-001'));
      });
    });
  });
}
