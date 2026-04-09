import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/comments/domain/entities/mention.dart';

void main() {
  group('Mention Entity', () {
    // ========================================================================
    // HAPPY PATH
    // ========================================================================

    group('creation and computed properties', () {
      test('creates mention with required fields', () {
        final mention = Mention(
          username: 'Marco',
          start: 5,
          end: 12,
        );

        expect(mention.username, 'Marco');
        expect(mention.start, 5);
        expect(mention.end, 12);
        expect(mention.userId, isNull);
      });

      test('fullText includes @ prefix', () {
        final mention = Mention(username: 'Anna_R', start: 0, end: 7);
        expect(mention.fullText, '@Anna_R');
      });

      test('length returns correct span', () {
        final mention = Mention(username: 'Marco', start: 5, end: 12);
        expect(mention.length, 7);
      });
    });

    group('copyWith and equality', () {
      test('copyWith returns new instance with updated fields', () {
        final mention = Mention(username: 'Marco', start: 0, end: 6);
        final resolved = mention.copyWith(userId: 'user-123');

        expect(resolved.userId, 'user-123');
        expect(resolved.username, 'Marco'); // unchanged
      });

      test('equality is based on username, start, end', () {
        final a = Mention(username: 'Marco', start: 0, end: 6);
        final b = Mention(username: 'Marco', start: 0, end: 6, userId: 'u-1');

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different position means not equal', () {
        final a = Mention(username: 'Marco', start: 0, end: 6);
        final b = Mention(username: 'Marco', start: 10, end: 16);
        expect(a, isNot(equals(b)));
      });
    });

    group('toString', () {
      test('contains username and range', () {
        final mention = Mention(username: 'Anna', start: 5, end: 10);
        expect(mention.toString(), 'Mention(@Anna, 5-10)');
      });
    });
  });

  group('parseMentions()', () {
    // ========================================================================
    // HAPPY PATH
    // ========================================================================

    group('valid mention parsing', () {
      test('parses single mention at start of text', () {
        final mentions = parseMentions('@Marco ciao!');
        expect(mentions, hasLength(1));
        expect(mentions.first.username, 'Marco');
        expect(mentions.first.start, 0);
        expect(mentions.first.end, 6);
      });

      test('parses mention in middle of text', () {
        final mentions = parseMentions('Ciao @Marco come va?');
        expect(mentions, hasLength(1));
        expect(mentions.first.username, 'Marco');
      });

      test('parses multiple mentions', () {
        final mentions = parseMentions('@Anna ciao! @Luca anche');
        expect(mentions, hasLength(2));
        expect(mentions[0].username, 'Anna');
        expect(mentions[1].username, 'Luca');
      });

      test('parses mention with underscores', () {
        final mentions = parseMentions('@Anna_R ciao');
        expect(mentions, hasLength(1));
        expect(mentions.first.username, 'Anna_R');
      });

      test('parses mention followed by punctuation', () {
        final mentions = parseMentions('Bravo @Marco!');
        expect(mentions, hasLength(1));
        expect(mentions.first.username, 'Marco');
      });

      test('parses mention at end of text', () {
        final mentions = parseMentions('Ciao @Marco');
        expect(mentions, hasLength(1));
        expect(mentions.first.username, 'Marco');
      });
    });

    // ========================================================================
    // EDGE CASES
    // ========================================================================

    group('edge cases', () {
      test('returns empty list for empty string', () {
        expect(parseMentions(''), isEmpty);
      });

      test('returns empty list for text without mentions', () {
        expect(parseMentions('No mentions here'), isEmpty);
      });

      test('ignores username shorter than 2 characters', () {
        expect(parseMentions('@A ciao'), isEmpty);
      });

      test('ignores mention without preceding space (inline)', () {
        // "abc@Marco" - @ not preceded by space or start
        expect(parseMentions('abc@Marco ciao'), isEmpty);
      });

      test('handles mention with numbers in username', () {
        final mentions = parseMentions('@User123 hello');
        expect(mentions, hasLength(1));
        expect(mentions.first.username, 'User123');
      });
    });
  });

  group('hasMentions()', () {
    test('returns true when text contains mentions', () {
      expect(hasMentions('@Marco ciao'), isTrue);
    });

    test('returns false when text has no mentions', () {
      expect(hasMentions('No mentions'), isFalse);
    });

    test('returns false for empty string', () {
      expect(hasMentions(''), isFalse);
    });
  });
}
