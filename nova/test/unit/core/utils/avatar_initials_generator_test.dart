/// Tests for AvatarInitialsGenerator utility class
///
/// Covers initials extraction, deterministic color assignment, and edge cases.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:nova/core/utils/avatar_initials_generator.dart';

void main() {
  group('AvatarInitialsGenerator', () {
    // =========================================================================
    // getInitials
    // =========================================================================

    group('getInitials', () {
      test('two-word name returns first and last initials (happy)', () {
        expect(AvatarInitialsGenerator.getInitials('Giovanni Rossi'), equals('GR'));
        expect(AvatarInitialsGenerator.getInitials('Maria Bianchi'), equals('MB'));
      });

      test('single-word name returns first character (happy)', () {
        expect(AvatarInitialsGenerator.getInitials('Mario'), equals('M'));
      });

      test('empty name returns question mark (edge)', () {
        expect(AvatarInitialsGenerator.getInitials(''), equals('?'));
        expect(AvatarInitialsGenerator.getInitials('   '), equals('?'));
      });

      test('three-word name uses first and last (edge)', () {
        expect(
          AvatarInitialsGenerator.getInitials('Anna Maria Rossi'),
          equals('AR'),
        );
      });

      test('initials are uppercased (edge)', () {
        expect(
          AvatarInitialsGenerator.getInitials('mario rossi'),
          equals('MR'),
        );
      });
    });

    // =========================================================================
    // getColor
    // =========================================================================

    group('getColor', () {
      test('same name always returns same color (happy)', () {
        final color1 = AvatarInitialsGenerator.getColor('Giovanni Rossi');
        final color2 = AvatarInitialsGenerator.getColor('Giovanni Rossi');
        expect(color1, equals(color2));
      });

      test('different first letters return different colors (happy)', () {
        final colorA = AvatarInitialsGenerator.getColor('Anna');
        final colorB = AvatarInitialsGenerator.getColor('Bruno');
        // A and B map to different indices (0 and 1)
        expect(colorA, isNot(equals(colorB)));
      });

      test('empty name returns default color (edge)', () {
        final color = AvatarInitialsGenerator.getColor('');
        expect(color, isA<Color>());
      });

      test('non-alphabetic first character returns default (edge)', () {
        final color = AvatarInitialsGenerator.getColor('123');
        final defaultColor = AvatarInitialsGenerator.materialColors500[0];
        expect(color, equals(defaultColor));
      });

      test('color index wraps around for later letters (edge)', () {
        // There are 17 colors, so R (index 17) wraps to index 0
        final colorIndex = AvatarInitialsGenerator.getColorIndex('Roberto');
        expect(colorIndex, lessThan(AvatarInitialsGenerator.materialColors500.length));
      });
    });

    // =========================================================================
    // generate
    // =========================================================================

    group('generate', () {
      test('returns map with initials and color (happy)', () {
        final result = AvatarInitialsGenerator.generate('Mario Rossi');

        expect(result['initials'], equals('MR'));
        expect(result['color'], isA<Color>());
      });

      test('empty name returns question mark and default color (edge)', () {
        final result = AvatarInitialsGenerator.generate('');

        expect(result['initials'], equals('?'));
        expect(result['color'], isA<Color>());
      });
    });

    // =========================================================================
    // getColorIndex
    // =========================================================================

    group('getColorIndex', () {
      test('A maps to 0 (edge)', () {
        expect(AvatarInitialsGenerator.getColorIndex('Anna'), equals(0));
      });

      test('empty string returns 0 (edge)', () {
        expect(AvatarInitialsGenerator.getColorIndex(''), equals(0));
      });
    });
  });
}
