import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/comments/domain/entities/comment.dart';
import '../../../../../fixtures/comment_fixtures.dart';
import '../../../../../fixtures/test_fixtures.dart';

void main() {
  group('Comment Entity', () {
    // ========================================================================
    // HAPPY PATH
    // ========================================================================

    group('creation', () {
      test('creates top-level comment with required fields', () {
        final comment = TestComments.topLevel();

        expect(comment.id, 'comment-001');
        expect(comment.eventId, 'test-event-001');
        expect(comment.userId, TestUserIds.student1);
        expect(comment.text, 'Bellissimo evento!');
        expect(comment.depth, 0);
        expect(comment.parentCommentId, isNull);
        expect(comment.likeCount, 5);
        expect(comment.replyCount, 2);
        expect(comment.authorName, 'Mario Rossi');
        expect(comment.authorClass, '4A');
        expect(comment.authorRole, 'student');
      });

      test('creates reply with parent and depth', () {
        final reply = TestComments.reply();

        expect(reply.parentCommentId, 'comment-001');
        expect(reply.depth, 1);
        expect(reply.isReply, isTrue);
        expect(reply.isTopLevel, isFalse);
      });
    });

    group('computed properties', () {
      test('isDeleted returns true when deletedAt is set', () {
        final deleted = TestComments.deleted();
        expect(deleted.isDeleted, isTrue);
      });

      test('isDeleted returns false when deletedAt is null', () {
        final comment = TestComments.topLevel();
        expect(comment.isDeleted, isFalse);
      });

      test('isHidden returns true when hiddenAt is set', () {
        final hidden = TestComments.hidden();
        expect(hidden.isHidden, isTrue);
      });

      test('isHidden returns false when hiddenAt is null', () {
        final comment = TestComments.topLevel();
        expect(comment.isHidden, isFalse);
      });

      test('isReply returns true for reply, false for top-level', () {
        expect(TestComments.reply().isReply, isTrue);
        expect(TestComments.topLevel().isReply, isFalse);
      });

      test('isTopLevel returns true for top-level, false for reply', () {
        expect(TestComments.topLevel().isTopLevel, isTrue);
        expect(TestComments.reply().isTopLevel, isFalse);
      });

      test('canHaveReplies is true when depth < maxDepth', () {
        expect(TestComments.topLevel().canHaveReplies, isTrue);
        expect(TestComments.reply(depth: 1).canHaveReplies, isTrue);
        expect(TestComments.reply(depth: 2).canHaveReplies, isTrue);
      });

      test('isEdited returns true when updatedAt differs from createdAt', () {
        final now = DateTime(2025, 6, 1, 12, 0);
        final comment = TestComments.topLevel().copyWith(
          createdAt: now,
          updatedAt: now.add(const Duration(minutes: 2)),
        );
        expect(comment.isEdited, isTrue);
      });

      test('isEdited returns false when updatedAt is null', () {
        final comment = TestComments.topLevel();
        expect(comment.updatedAt, isNull);
        expect(comment.isEdited, isFalse);
      });

      test('isEdited returns false when updatedAt equals createdAt', () {
        final now = DateTime(2025, 6, 1, 12, 0);
        final comment = TestComments.topLevel().copyWith(
          createdAt: now,
          updatedAt: now,
        );
        expect(comment.isEdited, isFalse);
      });

      test('canEdit returns true within 5-minute window', () {
        final now = DateTime(2025, 6, 1, 12, 0);
        final comment = TestComments.topLevel(
          createdAt: now.subtract(const Duration(minutes: 3)),
        );
        expect(comment.canEdit(now), isTrue);
      });

      test('displayText returns original text for active comment', () {
        final comment = TestComments.topLevel(text: 'Hello world');
        expect(comment.displayText, 'Hello world');
      });

      test('displayText returns placeholder for deleted comment', () {
        final deleted = TestComments.deleted();
        expect(deleted.displayText, '[Commento eliminato]');
      });

      test('isModeratorComment returns true for moderator role', () {
        final mod = TestComments.moderatorComment();
        expect(mod.isModeratorComment, isTrue);
      });

      test('isModeratorComment returns false for student role', () {
        final student = TestComments.topLevel();
        expect(student.isModeratorComment, isFalse);
      });

      test('hasReplies and hasLikes work correctly', () {
        final comment = TestComments.topLevel(); // likeCount=5, replyCount=2
        expect(comment.hasReplies, isTrue);
        expect(comment.hasLikes, isTrue);

        final noLikes = comment.copyWith(likeCount: 0, replyCount: 0);
        expect(noLikes.hasReplies, isFalse);
        expect(noLikes.hasLikes, isFalse);
      });
    });

    group('getRelativeTimestamp', () {
      test('returns "Ora" for less than 60 seconds', () {
        final now = DateTime(2025, 6, 1, 12, 0, 30);
        final comment = TestComments.topLevel(createdAt: now);
        expect(comment.getRelativeTimestamp(now.add(const Duration(seconds: 15))), 'Ora');
      });

      test('returns minutes format for <1 hour', () {
        final now = DateTime(2025, 6, 1, 12, 0);
        final comment = TestComments.topLevel(
          createdAt: now.subtract(const Duration(minutes: 25)),
        );
        expect(comment.getRelativeTimestamp(now), '25m fa');
      });

      test('returns hours format for <24 hours', () {
        final now = DateTime(2025, 6, 1, 12, 0);
        final comment = TestComments.topLevel(
          createdAt: now.subtract(const Duration(hours: 5)),
        );
        expect(comment.getRelativeTimestamp(now), '5h fa');
      });

      test('returns "Ieri" for 1 day ago', () {
        final now = DateTime(2025, 6, 1, 12, 0);
        final comment = TestComments.topLevel(
          createdAt: now.subtract(const Duration(days: 1)),
        );
        expect(comment.getRelativeTimestamp(now), 'Ieri');
      });

      test('returns "X giorni fa" for 2-6 days', () {
        final now = DateTime(2025, 6, 1, 12, 0);
        final comment = TestComments.topLevel(
          createdAt: now.subtract(const Duration(days: 4)),
        );
        expect(comment.getRelativeTimestamp(now), '4 giorni fa');
      });

      test('returns absolute date for >= 7 days', () {
        final now = DateTime(2025, 6, 15, 12, 0);
        final comment = TestComments.topLevel(
          createdAt: DateTime(2025, 1, 15),
        );
        expect(comment.getRelativeTimestamp(now), '15 Gen 2025');
      });
    });

    group('formattedLikeCount', () {
      test('returns raw count for <= 999', () {
        final comment = TestComments.topLevel().copyWith(likeCount: 42);
        expect(comment.formattedLikeCount, '42');
      });

      test('returns raw count for exactly 999', () {
        final comment = TestComments.topLevel().copyWith(likeCount: 999);
        expect(comment.formattedLikeCount, '999');
      });
    });

    group('copyWith', () {
      test('returns new instance with updated fields', () {
        final comment = TestComments.topLevel();
        final updated = comment.copyWith(
          text: 'Aggiornato!',
          likeCount: 10,
        );

        expect(updated.text, 'Aggiornato!');
        expect(updated.likeCount, 10);
        expect(updated.id, comment.id); // unchanged
        expect(updated.eventId, comment.eventId); // unchanged
      });

      test('preserves all fields when no arguments given', () {
        final comment = TestComments.topLevel();
        final copy = comment.copyWith();

        expect(copy.id, comment.id);
        expect(copy.text, comment.text);
        expect(copy.likeCount, comment.likeCount);
        expect(copy.userId, comment.userId);
      });
    });

    group('equality', () {
      test('two comments with same id are equal', () {
        final a = TestComments.topLevel(id: 'same-id');
        final b = TestComments.topLevel(id: 'same-id', text: 'Different text');

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('two comments with different ids are not equal', () {
        final a = TestComments.topLevel(id: 'id-1');
        final b = TestComments.topLevel(id: 'id-2');

        expect(a, isNot(equals(b)));
      });
    });

    // ========================================================================
    // EDGE CASES
    // ========================================================================

    group('edge cases', () {
      test('maxDepth boundary - canHaveReplies is false at maxDepth', () {
        final maxDepthComment = TestComments.maxDepthReply();
        expect(maxDepthComment.depth, Comment.maxDepth);
        expect(maxDepthComment.canHaveReplies, isFalse);
      });

      test('maxDepth boundary - canHaveReplies is true at maxDepth - 1', () {
        final comment = TestComments.reply(depth: Comment.maxDepth - 1);
        expect(comment.canHaveReplies, isTrue);
      });

      test('canEdit returns false after 5-minute window expires', () {
        final now = DateTime(2025, 6, 1, 12, 0);
        final comment = TestComments.topLevel(
          createdAt: now.subtract(const Duration(minutes: 5, seconds: 1)),
        );
        expect(comment.canEdit(now), isFalse);
      });

      test('canEdit returns false for deleted comment within window', () {
        final now = DateTime(2025, 6, 1, 12, 0);
        final deleted = TestComments.deleted().copyWith(
          createdAt: now.subtract(const Duration(minutes: 1)),
        );
        expect(deleted.canEdit(now), isFalse);
      });

      test('canEdit returns false for hidden comment within window', () {
        final now = DateTime(2025, 6, 1, 12, 0);
        final hidden = TestComments.hidden().copyWith(
          createdAt: now.subtract(const Duration(minutes: 1)),
        );
        expect(hidden.canEdit(now), isFalse);
      });

      test('canEdit at exact 5-minute boundary', () {
        final now = DateTime(2025, 6, 1, 12, 5, 0);
        final comment = TestComments.topLevel(
          createdAt: DateTime(2025, 6, 1, 12, 0, 0),
        );
        // createdAt is NOT after fiveMinutesAgo (equal), so canEdit is false
        expect(comment.canEdit(now), isFalse);
      });

      test('formattedLikeCount for > 999 returns K+ format', () {
        final comment = TestComments.topLevel().copyWith(likeCount: 1000);
        expect(comment.formattedLikeCount, '1K+');
      });

      test('formattedLikeCount for large numbers', () {
        final comment = TestComments.topLevel().copyWith(likeCount: 15432);
        expect(comment.formattedLikeCount, '15K+');
      });

      test('formattedLikeCount for zero', () {
        final comment = TestComments.topLevel().copyWith(likeCount: 0);
        expect(comment.formattedLikeCount, '0');
      });

      test('empty text comment displays correctly', () {
        final comment = TestComments.topLevel(text: '');
        expect(comment.displayText, '');
        expect(comment.isDeleted, isFalse);
      });

      test('getFormattedTimestamp appends modified indicator', () {
        final now = DateTime(2025, 6, 1, 12, 0);
        final comment = TestComments.topLevel(
          createdAt: now.subtract(const Duration(minutes: 10)),
        ).copyWith(
          updatedAt: now.subtract(const Duration(minutes: 5)),
        );
        expect(comment.getFormattedTimestamp(now), '10m fa (modificato)');
      });

      test('isOwnedBy returns correct result', () {
        final comment = TestComments.topLevel(userId: 'user-abc');
        expect(comment.isOwnedBy('user-abc'), isTrue);
        expect(comment.isOwnedBy('user-xyz'), isFalse);
      });

      test('toString truncates long text', () {
        final longText = 'A' * 100;
        final comment = TestComments.topLevel(text: longText);
        final str = comment.toString();
        expect(str.contains('A' * 50), isTrue);
        expect(str.contains('A' * 51), isFalse);
      });
    });
  });
}
