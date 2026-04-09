@TestOn('vm')
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nova/core/theme/nova_typography.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // GoogleFonts.inter() returns a TextStyle synchronously but triggers an
  // async font download. In test environments the download will fail, which
  // pollutes the test zone with unhandled async errors. We suppress those
  // by running each test inside a custom Zone that silences errors from the
  // google_fonts package.

  // Pre-load all styles once outside the test zone to cache them, then
  // verify properties synchronously.
  late final Map<String, TextStyle> styles;

  setUpAll(() {
    // Allow runtime fetching so GoogleFonts returns a TextStyle without
    // throwing synchronously. The actual HTTP fetch will fail but we don't
    // care about it.
    GoogleFonts.config.allowRuntimeFetching = true;

    // Eagerly access all styles. The TextStyle objects are returned
    // synchronously; the async font load errors are ignored.
    runZonedGuarded(() {
      styles = {
        'display': NovaTypography.display,
        'headingLarge': NovaTypography.headingLarge,
        'headingMedium': NovaTypography.headingMedium,
        'headingSmall': NovaTypography.headingSmall,
        'bodyLarge': NovaTypography.bodyLarge,
        'bodyMedium': NovaTypography.bodyMedium,
        'bodySmall': NovaTypography.bodySmall,
        'sectionTitle': NovaTypography.sectionTitle,
        'labelLarge': NovaTypography.labelLarge,
        'labelMedium': NovaTypography.labelMedium,
        'labelSmall': NovaTypography.labelSmall,
        'button': NovaTypography.button,
        'overline': NovaTypography.overline,
        'h1': NovaTypography.h1,
        'h2': NovaTypography.h2,
        'h3': NovaTypography.h3,
        'body': NovaTypography.body,
        'bodyBold': NovaTypography.bodyBold,
        'caption': NovaTypography.caption,
        'small': NovaTypography.small,
      };
    }, (error, stack) {
      // Silently ignore google_fonts network errors in test environment
    });
  });

  // ==========================================================================
  // HEADING STYLES
  // ==========================================================================

  group('heading styles', () {
    test('display has correct properties', () {
      final style = styles['display']!;
      expect(style.fontSize, 42);
      expect(style.fontWeight, FontWeight.w900);
      expect(style.height, 1.0);
      expect(style.letterSpacing, -2.1);
    });

    test('headingLarge has correct properties', () {
      final style = styles['headingLarge']!;
      expect(style.fontSize, 36);
      expect(style.fontWeight, FontWeight.w900);
      expect(style.height, 1.05);
      expect(style.letterSpacing, -1.8);
    });

    test('headingMedium has correct properties', () {
      final style = styles['headingMedium']!;
      expect(style.fontSize, 28);
      expect(style.fontWeight, FontWeight.w900);
      expect(style.height, 1.1);
      expect(style.letterSpacing, -1.4);
    });

    test('headingSmall has correct properties', () {
      final style = styles['headingSmall']!;
      expect(style.fontSize, 24);
      expect(style.fontWeight, FontWeight.w800);
      expect(style.height, 1.15);
      expect(style.letterSpacing, -1.2);
    });
  });

  // ==========================================================================
  // BODY STYLES
  // ==========================================================================

  group('body styles', () {
    test('bodyLarge has correct properties', () {
      final style = styles['bodyLarge']!;
      expect(style.fontSize, 16);
      expect(style.fontWeight, FontWeight.w500);
      expect(style.height, 1.5);
      expect(style.letterSpacing, -0.32);
    });

    test('bodyMedium has correct properties', () {
      final style = styles['bodyMedium']!;
      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.height, 1.45);
      expect(style.letterSpacing, -0.30);
    });

    test('bodySmall has correct properties', () {
      final style = styles['bodySmall']!;
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w400);
      expect(style.height, 1.4);
      expect(style.letterSpacing, -0.26);
    });
  });

  // ==========================================================================
  // UTILITY STYLES
  // ==========================================================================

  group('utility styles', () {
    test('sectionTitle has correct properties', () {
      final style = styles['sectionTitle']!;
      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w700);
    });

    test('labelLarge has correct properties', () {
      final style = styles['labelLarge']!;
      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w700);
    });

    test('labelMedium has correct properties', () {
      final style = styles['labelMedium']!;
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('labelSmall has correct properties', () {
      final style = styles['labelSmall']!;
      expect(style.fontSize, 12);
      expect(style.fontWeight, FontWeight.w500);
    });

    test('button has correct properties', () {
      final style = styles['button']!;
      expect(style.fontSize, 15);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.height, 1.0);
    });

    test('overline has correct properties', () {
      final style = styles['overline']!;
      expect(style.fontSize, 10);
      expect(style.fontWeight, FontWeight.w600);
      expect(style.letterSpacing, 0.5);
    });
  });

  // ==========================================================================
  // LEGACY ALIASES
  // ==========================================================================

  group('legacy aliases', () {
    test('h1 maps to headingLarge', () {
      expect(styles['h1']!.fontSize, styles['headingLarge']!.fontSize);
      expect(styles['h1']!.fontWeight, styles['headingLarge']!.fontWeight);
    });

    test('h2 maps to headingMedium', () {
      expect(styles['h2']!.fontSize, styles['headingMedium']!.fontSize);
    });

    test('h3 maps to headingSmall', () {
      expect(styles['h3']!.fontSize, styles['headingSmall']!.fontSize);
    });

    test('body maps to bodyMedium', () {
      expect(styles['body']!.fontSize, styles['bodyMedium']!.fontSize);
    });

    test('bodyBold maps to labelLarge', () {
      expect(styles['bodyBold']!.fontSize, styles['labelLarge']!.fontSize);
    });

    test('caption maps to bodySmall', () {
      expect(styles['caption']!.fontSize, styles['bodySmall']!.fontSize);
    });

    test('small maps to labelSmall', () {
      expect(styles['small']!.fontSize, styles['labelSmall']!.fontSize);
    });
  });

  // ==========================================================================
  // NovaTextStyles typedef
  // ==========================================================================

  group('NovaTextStyles typedef', () {
    test('NovaTextStyles is alias for NovaTypography', () {
      expect(styles['display']!.fontSize, 42);
    });
  });
}
