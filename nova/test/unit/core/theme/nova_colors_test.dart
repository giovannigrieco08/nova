/// Tests for NovaColors static color constants
///
/// Verifies that key color constants exist, have expected values,
/// and that color lists are properly defined.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nova/core/theme/nova_colors.dart';

void main() {
  group('NovaColors', () {
    // =========================================================================
    // Light mode colors - verify exact hex values
    // =========================================================================

    group('light mode constants', () {
      test('backgroundLight is pure white', () {
        expect(NovaColors.backgroundLight, equals(const Color(0xFFFFFFFF)));
      });

      test('primaryLight is vibrant purple', () {
        expect(NovaColors.primaryLight, equals(const Color(0xFF8B5CF6)));
      });

      test('errorLight is red', () {
        expect(NovaColors.errorLight, equals(const Color(0xFFEF4444)));
      });

      test('successLight is green', () {
        expect(NovaColors.successLight, equals(const Color(0xFF10B981)));
      });

      test('textPrimaryLight is near black', () {
        expect(NovaColors.textPrimaryLight, equals(const Color(0xFF111827)));
      });
    });

    // =========================================================================
    // Dark mode colors - verify exact hex values
    // =========================================================================

    group('dark mode constants', () {
      test('backgroundDark is pure black (OLED optimized)', () {
        expect(NovaColors.backgroundDark, equals(const Color(0xFF000000)));
      });

      test('primaryDark is lighter purple for dark mode contrast', () {
        expect(NovaColors.primaryDark, equals(const Color(0xFFA78BFA)));
      });

      test('textPrimaryDark is off-white', () {
        expect(NovaColors.textPrimaryDark, equals(const Color(0xFFF9FAFB)));
      });
    });

    // =========================================================================
    // Brand and gradient colors
    // =========================================================================

    group('brand colors', () {
      test('brandGradient has correct start and end colors', () {
        expect(NovaColors.brandGradient.colors, hasLength(2));
        expect(NovaColors.brandGradient.colors[0], equals(NovaColors.gradientStart));
        expect(NovaColors.brandGradient.colors[1], equals(NovaColors.gradientEnd));
      });

      test('likeActive is Instagram red', () {
        expect(NovaColors.likeActive, equals(const Color(0xFFED4956)));
      });

      test('whatsappGreen has correct brand color', () {
        expect(NovaColors.whatsappGreen, equals(const Color(0xFF25D366)));
      });
    });

    // =========================================================================
    // Avatar colors
    // =========================================================================

    group('avatar colors', () {
      test('avatarColors has 17 Material Design 500 colors', () {
        expect(NovaColors.avatarColors, hasLength(17));
      });

      test('avatarColorsQuick has 5 quick-access colors', () {
        expect(NovaColors.avatarColorsQuick, hasLength(5));
      });

      test('all avatar colors are opaque', () {
        for (final color in NovaColors.avatarColors) {
          expect(color.a, equals(1.0),
              reason: 'Avatar color $color should be fully opaque');
        }
      });
    });

    // =========================================================================
    // Static aliases match light mode
    // =========================================================================

    group('static aliases', () {
      test('primaryStatic matches primaryLight', () {
        expect(NovaColors.primaryStatic, equals(NovaColors.primaryLight));
      });

      test('errorStatic matches errorLight', () {
        expect(NovaColors.errorStatic, equals(NovaColors.errorLight));
      });

      test('backgroundStatic matches backgroundLight', () {
        expect(NovaColors.backgroundStatic, equals(NovaColors.backgroundLight));
      });
    });

    // =========================================================================
    // Glass tint colors have transparency
    // =========================================================================

    group('glass tint colors', () {
      test('glass tints have increasing opacity (subtle < medium < strong)', () {
        expect(NovaColors.glassTintSubtle.a, lessThan(NovaColors.glassTintMedium.a));
        expect(NovaColors.glassTintMedium.a, lessThan(NovaColors.glassTintStrong.a));
      });
    });
  });
}
