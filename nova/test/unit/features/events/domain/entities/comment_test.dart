import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/events/domain/entities/comment.dart';

void main() {
  // ==========================================================================
  // Helper
  // ==========================================================================

  Comment makeComment({
    String id = 'c-1',
    String eventId = 'evt-1',
    String authorId = 'user-1',
    String content = 'Hello world',
    DateTime? createdAt,
    String? authorName,
    String? authorAvatarUrl,
    String? authorClass,
  }) {
    return Comment(
      id: id,
      eventId: eventId,
      authorId: authorId,
      content: content,
      createdAt: createdAt ?? DateTime.now(),
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      authorClass: authorClass,
    );
  }

  // ==========================================================================
  // exceedsLimit
  // ==========================================================================

  group('exceedsLimit', () {
    test('returns false for short content', () {
      final comment = makeComment(content: 'Short');
      expect(comment.exceedsLimit, isFalse);
    });

    test('returns false for exactly 500 characters', () {
      final comment = makeComment(content: 'a' * 500);
      expect(comment.exceedsLimit, isFalse);
    });

    test('returns true for 501 characters', () {
      final comment = makeComment(content: 'a' * 501);
      expect(comment.exceedsLimit, isTrue);
    });
  });

  // ==========================================================================
  // remainingCharacters
  // ==========================================================================

  group('remainingCharacters', () {
    test('returns 500 for empty content', () {
      final comment = makeComment(content: '');
      expect(comment.remainingCharacters, 500);
    });

    test('returns correct remaining for partial content', () {
      final comment = makeComment(content: 'Hello'); // 5 chars
      expect(comment.remainingCharacters, 495);
    });

    test('returns 0 at exactly 500 characters', () {
      final comment = makeComment(content: 'a' * 500);
      expect(comment.remainingCharacters, 0);
    });

    test('returns negative when exceeding 500', () {
      final comment = makeComment(content: 'a' * 510);
      expect(comment.remainingCharacters, -10);
    });
  });

  // ==========================================================================
  // relativeTime
  // ==========================================================================

  group('relativeTime', () {
    test('returns "Just now" for less than 60 seconds ago', () {
      final comment = makeComment(
        createdAt: DateTime.now().subtract(const Duration(seconds: 30)),
      );
      expect(comment.relativeTime, 'Just now');
    });

    test('returns minutes ago for less than 60 minutes', () {
      final comment = makeComment(
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      );
      expect(comment.relativeTime, '15m ago');
    });

    test('returns hours ago for less than 24 hours', () {
      final comment = makeComment(
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      );
      expect(comment.relativeTime, '5h ago');
    });

    test('returns days ago for less than 7 days', () {
      final comment = makeComment(
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      );
      expect(comment.relativeTime, '3d ago');
    });

    test('returns formatted date for 7+ days ago', () {
      final comment = makeComment(
        createdAt: DateTime(2024, 3, 15),
      );
      expect(comment.relativeTime, '15/3/2024');
    });
  });

  // ==========================================================================
  // isAuthor
  // ==========================================================================

  group('isAuthor', () {
    test('returns true for matching userId', () {
      final comment = makeComment(authorId: 'user-1');
      expect(comment.isAuthor('user-1'), isTrue);
    });

    test('returns false for different userId', () {
      final comment = makeComment(authorId: 'user-1');
      expect(comment.isAuthor('user-2'), isFalse);
    });
  });

  // ==========================================================================
  // copyWith
  // ==========================================================================

  group('copyWith', () {
    test('creates copy with updated content', () {
      final original = makeComment(content: 'Original');
      final copy = original.copyWith(content: 'Updated');

      expect(copy.content, 'Updated');
      expect(copy.id, original.id);
      expect(copy.eventId, original.eventId);
    });

    test('preserves all fields when no changes', () {
      final original = makeComment(
        authorName: 'Mario',
        authorAvatarUrl: 'https://example.com/avatar.png',
        authorClass: '4A',
      );
      final copy = original.copyWith();

      expect(copy.authorName, 'Mario');
      expect(copy.authorAvatarUrl, 'https://example.com/avatar.png');
      expect(copy.authorClass, '4A');
    });
  });

  // ==========================================================================
  // equality and hashCode
  // ==========================================================================

  group('equality', () {
    test('two comments with same id are equal', () {
      final a = makeComment(id: 'same-id', content: 'A');
      final b = makeComment(id: 'same-id', content: 'B');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('two comments with different id are not equal', () {
      final a = makeComment(id: 'id-1');
      final b = makeComment(id: 'id-2');
      expect(a, isNot(equals(b)));
    });
  });

  // ==========================================================================
  // toString
  // ==========================================================================

  group('toString', () {
    test('truncates long content at 30 characters', () {
      final comment = makeComment(
        id: 'c-1',
        authorId: 'user-1',
        content: 'This is a very long comment that should be truncated',
      );
      final str = comment.toString();
      expect(str, contains('c-1'));
      expect(str, contains('user-1'));
      // Should contain truncated content (30 chars)
      expect(str, contains('This is a very long comment th'));
    });

    test('handles short content without truncation', () {
      final comment = makeComment(content: 'Short');
      final str = comment.toString();
      expect(str, contains('Short'));
    });
  });
}
