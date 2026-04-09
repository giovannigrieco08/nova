/// Tests for EmailValidator utility class
///
/// Covers isValid, validate, and normalize methods.

import 'package:flutter_test/flutter_test.dart';

import 'package:nova/core/utils/email_validator.dart';

void main() {
  group('EmailValidator', () {
    // =========================================================================
    // isValid
    // =========================================================================

    group('isValid', () {
      test('standard email is valid (happy)', () {
        expect(EmailValidator.isValid('user@example.com'), isTrue);
        expect(EmailValidator.isValid('test@gmail.com'), isTrue);
        expect(EmailValidator.isValid('student@galileimoro.edu.it'), isTrue);
      });

      test('email with dots and plus in local part is valid (happy)', () {
        expect(EmailValidator.isValid('mario.rossi@example.com'), isTrue);
        expect(EmailValidator.isValid('user+tag@example.com'), isTrue);
      });

      test('email with subdomains is valid (happy)', () {
        expect(EmailValidator.isValid('user@sub.domain.com'), isTrue);
      });

      test('null returns false (edge)', () {
        expect(EmailValidator.isValid(null), isFalse);
      });

      test('empty string returns false (edge)', () {
        expect(EmailValidator.isValid(''), isFalse);
      });

      test('missing @ returns false (edge)', () {
        expect(EmailValidator.isValid('userexample.com'), isFalse);
      });

      test('missing domain returns false (edge)', () {
        expect(EmailValidator.isValid('user@'), isFalse);
      });

      test('missing TLD returns false (edge)', () {
        expect(EmailValidator.isValid('user@domain'), isFalse);
      });

      test('single char TLD returns false (edge)', () {
        expect(EmailValidator.isValid('user@domain.x'), isFalse);
      });

      test('case insensitive validation (edge)', () {
        expect(EmailValidator.isValid('USER@EXAMPLE.COM'), isTrue);
        expect(EmailValidator.isValid('User@Example.Com'), isTrue);
      });

      test('email with spaces returns false (edge)', () {
        // Trimming happens inside isValid, but inner spaces should fail
        expect(EmailValidator.isValid('user @example.com'), isFalse);
      });
    });

    // =========================================================================
    // validate
    // =========================================================================

    group('validate', () {
      test('valid email returns null (happy)', () {
        expect(EmailValidator.validate('user@example.com'), isNull);
      });

      test('null returns error message (happy)', () {
        final error = EmailValidator.validate(null);
        expect(error, isNotNull);
        expect(error, contains('required'));
      });

      test('empty returns error message (happy)', () {
        final error = EmailValidator.validate('');
        expect(error, isNotNull);
        expect(error, contains('required'));
      });

      test('missing @ returns specific error (edge)', () {
        final error = EmailValidator.validate('userexample.com');
        expect(error, isNotNull);
        expect(error, contains('valid email'));
      });

      test('invalid format returns error (edge)', () {
        final error = EmailValidator.validate('user@');
        expect(error, isNotNull);
      });
    });

    // =========================================================================
    // normalize
    // =========================================================================

    group('normalize', () {
      test('lowercases email (happy)', () {
        expect(
          EmailValidator.normalize('USER@EXAMPLE.COM'),
          equals('user@example.com'),
        );
      });

      test('trims whitespace (happy)', () {
        expect(
          EmailValidator.normalize('  user@example.com  '),
          equals('user@example.com'),
        );
      });

      test('combined trim and lowercase (edge)', () {
        expect(
          EmailValidator.normalize('  Student@GALILEIMORO.edu.it  '),
          equals('student@galileimoro.edu.it'),
        );
      });

      test('already normalized email unchanged (edge)', () {
        expect(
          EmailValidator.normalize('user@example.com'),
          equals('user@example.com'),
        );
      });
    });
  });
}
