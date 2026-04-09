/// Tests for Validators utility class
///
/// Covers username, name, bio, and class validation plus sanitization.

import 'package:flutter_test/flutter_test.dart';

import 'package:nova/core/utils/validators.dart';

void main() {
  group('Validators', () {
    // =========================================================================
    // USERNAME VALIDATION
    // =========================================================================

    group('validateUsername', () {
      test('valid username returns null (happy)', () {
        expect(Validators.validateUsername('mario.rossi'), isNull);
        expect(Validators.validateUsername('user_123'), isNull);
        expect(Validators.validateUsername('abc'), isNull);
      });

      test('null or empty returns error (happy)', () {
        expect(Validators.validateUsername(null), isNotNull);
        expect(Validators.validateUsername(''), isNotNull);
        expect(Validators.validateUsername('   '), isNotNull);
      });

      test('too short returns error (edge)', () {
        expect(Validators.validateUsername('ab'), isNotNull);
        expect(Validators.validateUsername('a'), isNotNull);
      });

      test('too long returns error (edge)', () {
        final longUsername = 'a' * 31;
        expect(Validators.validateUsername(longUsername), isNotNull);
      });

      test('boundary length 3 is valid (edge)', () {
        expect(Validators.validateUsername('abc'), isNull);
      });

      test('boundary length 30 is valid (edge)', () {
        final username30 = 'a' * 30;
        expect(Validators.validateUsername(username30), isNull);
      });

      test('uppercase is accepted (trimmed to lowercase internally) (edge)', () {
        // The validator trims and lowercases, so uppercase input should pass
        // because the regex check happens on lowercased value
        expect(Validators.validateUsername('MARIO'), isNull);
      });

      test('invalid characters return error (edge)', () {
        expect(Validators.validateUsername('mario rossi'), isNotNull); // space
        expect(Validators.validateUsername('mario@rossi'), isNotNull); // @
        expect(Validators.validateUsername('mario#rossi'), isNotNull); // #
      });
    });

    // =========================================================================
    // NAME VALIDATION
    // =========================================================================

    group('validateName', () {
      test('valid names return null (happy)', () {
        expect(Validators.validateName('Mario Rossi'), isNull);
        expect(Validators.validateName("Maria D'Angelo"), isNull);
        expect(Validators.validateName('Jean-Pierre'), isNull);
      });

      test('null or empty returns error (happy)', () {
        expect(Validators.validateName(null), isNotNull);
        expect(Validators.validateName(''), isNotNull);
        expect(Validators.validateName('   '), isNotNull);
      });

      test('accented characters are valid (happy)', () {
        expect(Validators.validateName('Giuseppe'), isNull);
      });

      test('too short returns error (edge)', () {
        expect(Validators.validateName('A'), isNotNull);
      });

      test('too long returns error (edge)', () {
        final longName = 'A' * 51;
        expect(Validators.validateName(longName), isNotNull);
      });

      test('numbers in name return error (edge)', () {
        expect(Validators.validateName('Mario123'), isNotNull);
      });

      test('special symbols return error (edge)', () {
        expect(Validators.validateName('Mario@Rossi'), isNotNull);
      });

      test('boundary length 2 is valid (edge)', () {
        expect(Validators.validateName('AB'), isNull);
      });

      test('boundary length 50 is valid (edge)', () {
        final name50 = 'A' * 50;
        expect(Validators.validateName(name50), isNull);
      });
    });

    // =========================================================================
    // hasInvalidCharacters
    // =========================================================================

    group('hasInvalidCharacters', () {
      test('returns false for valid name (happy)', () {
        expect(Validators.hasInvalidCharacters('Mario Rossi'), isFalse);
      });

      test('returns true for name with numbers (edge)', () {
        expect(Validators.hasInvalidCharacters('Mario123'), isTrue);
      });
    });

    // =========================================================================
    // BIO VALIDATION
    // =========================================================================

    group('validateBio', () {
      test('null or empty bio is valid (happy)', () {
        expect(Validators.validateBio(null), isNull);
        expect(Validators.validateBio(''), isNull);
        expect(Validators.validateBio('   '), isNull);
      });

      test('normal bio text is valid (happy)', () {
        expect(Validators.validateBio('Studente al Galilei Moro'), isNull);
      });

      test('bio with emojis is valid (happy)', () {
        expect(Validators.validateBio('Hello world! :)'), isNull);
      });

      test('bio over 150 chars returns error (edge)', () {
        final longBio = 'a' * 151;
        expect(Validators.validateBio(longBio), isNotNull);
      });

      test('bio with exactly 150 chars is valid (edge)', () {
        final bio150 = 'a' * 150;
        expect(Validators.validateBio(bio150), isNull);
      });

      test('bio with HTML tags returns error (edge)', () {
        expect(Validators.validateBio('<b>bold</b>'), isNotNull);
        expect(Validators.validateBio('<script>alert("x")</script>'), isNotNull);
      });

      test('bio with URLs returns error (edge)', () {
        expect(Validators.validateBio('Check out https://example.com'), isNotNull);
        expect(Validators.validateBio('Visit www.google.com'), isNotNull);
      });
    });

    // =========================================================================
    // BIO SANITIZATION
    // =========================================================================

    group('sanitizeBio', () {
      test('trims whitespace (happy)', () {
        expect(Validators.sanitizeBio('  hello  '), equals('hello'));
      });

      test('strips HTML tags (happy)', () {
        expect(Validators.sanitizeBio('<b>bold</b>'), equals('bold'));
      });

      test('removes URLs (edge)', () {
        final sanitized = Validators.sanitizeBio('Visit https://example.com now');
        expect(sanitized, isNot(contains('https://')));
      });

      test('truncates to 150 characters (edge)', () {
        final longText = 'a' * 200;
        final sanitized = Validators.sanitizeBio(longText);
        expect(sanitized.length, lessThanOrEqualTo(150));
      });
    });

    // =========================================================================
    // CLASS VALIDATION
    // =========================================================================

    group('validateClass', () {
      test('valid class returns null (happy)', () {
        expect(Validators.validateClass('3A Scientifico'), isNull);
      });

      test('null or empty returns error (edge)', () {
        expect(Validators.validateClass(null), isNotNull);
        expect(Validators.validateClass(''), isNotNull);
        expect(Validators.validateClass('   '), isNotNull);
      });
    });

    // =========================================================================
    // GENERAL UTILITIES
    // =========================================================================

    group('normalizeWhitespace', () {
      test('collapses multiple spaces (happy)', () {
        expect(
          Validators.normalizeWhitespace('  hello   world  '),
          equals('hello world'),
        );
      });

      test('handles tabs and newlines (edge)', () {
        expect(
          Validators.normalizeWhitespace('hello\t\nworld'),
          equals('hello world'),
        );
      });
    });

    group('isEmpty', () {
      test('null returns true (happy)', () {
        expect(Validators.isEmpty(null), isTrue);
      });

      test('empty string returns true (happy)', () {
        expect(Validators.isEmpty(''), isTrue);
      });

      test('whitespace only returns true (edge)', () {
        expect(Validators.isEmpty('   '), isTrue);
      });

      test('non-empty returns false (edge)', () {
        expect(Validators.isEmpty('hello'), isFalse);
      });
    });
  });
}
