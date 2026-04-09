/// Tests for UserRole enum
///
/// Covers fromString parsing, toString serialization, and permission checks.

import 'package:flutter_test/flutter_test.dart';

import 'package:nova/core/enums/user_role.dart';

void main() {
  group('UserRole', () {
    // =========================================================================
    // HAPPY PATH
    // =========================================================================

    group('fromString', () {
      test('parses all valid role strings (happy)', () {
        expect(UserRole.fromString('student'), equals(UserRole.student));
        expect(UserRole.fromString('moderator'), equals(UserRole.moderator));
        expect(UserRole.fromString('admin'), equals(UserRole.admin));
      });

      test('is case insensitive (happy)', () {
        expect(UserRole.fromString('STUDENT'), equals(UserRole.student));
        expect(UserRole.fromString('Moderator'), equals(UserRole.moderator));
        expect(UserRole.fromString('ADMIN'), equals(UserRole.admin));
      });
    });

    // =========================================================================
    // EDGE CASES
    // =========================================================================

    group('fromString edge cases', () {
      test('invalid string throws ArgumentError (edge)', () {
        expect(
          () => UserRole.fromString('invalid'),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('empty string throws ArgumentError (edge)', () {
        expect(
          () => UserRole.fromString(''),
          throwsA(isA<ArgumentError>()),
        );
      });
    });

    group('toString', () {
      test('returns lowercase string for all roles (happy)', () {
        expect(UserRole.student.toString(), equals('student'));
        expect(UserRole.moderator.toString(), equals('moderator'));
        expect(UserRole.admin.toString(), equals('admin'));
      });

      test('roundtrip fromString/toString is consistent (edge)', () {
        for (final role in UserRole.values) {
          expect(UserRole.fromString(role.toString()), equals(role));
        }
      });
    });

    group('canModerate', () {
      test('student cannot moderate (happy)', () {
        expect(UserRole.student.canModerate, isFalse);
      });

      test('moderator can moderate (happy)', () {
        expect(UserRole.moderator.canModerate, isTrue);
      });

      test('admin can moderate (edge)', () {
        expect(UserRole.admin.canModerate, isTrue);
      });
    });

    group('isAdmin', () {
      test('only admin returns true (edge)', () {
        expect(UserRole.student.isAdmin, isFalse);
        expect(UserRole.moderator.isAdmin, isFalse);
        expect(UserRole.admin.isAdmin, isTrue);
      });
    });
  });
}
