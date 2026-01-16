// lib/core/theme/nova_typography.dart

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Nova typography system with consistent text styles.
///
/// All text in Nova MUST use these constants to ensure:
/// - Visual consistency across the app
/// - Proper hierarchy and readability
/// - Easy maintenance and updates
///
/// Uses SF Pro on iOS (system font) and Inter on Android for platform-native feel.
///
/// Never use hardcoded TextStyle values - always use NovaTypography.
class NovaTypography {
  // Prevent instantiation
  NovaTypography._();

  /// Check if running on iOS
  static bool get _isIOS {
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// Create a TextStyle with the appropriate font for the platform.
  /// iOS: SF Pro (system font via .AppleSystemUIFont)
  /// Android: Inter (via Google Fonts)
  static TextStyle _style({
    required double fontSize,
    required FontWeight fontWeight,
    required double height,
    required double letterSpacing,
  }) {
    if (_isIOS) {
      // Use SF Pro system font on iOS
      // .AppleSystemUIFont triggers the proper SF Pro variant
      return TextStyle(
        fontFamily: '.SF Pro Text',
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
      );
    } else {
      // Use Inter on Android
      return GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: height,
        letterSpacing: letterSpacing,
      );
    }
  }

  // ============================================
  // HEADING STYLES
  // ============================================

  /// Display text style (42px, black, -0.05em tracking)
  /// Usage: Hero headlines, splash screen titles
  /// Maximum visual impact with aggressive sizing
  static TextStyle get display => _style(
    fontSize: 42,
    fontWeight: FontWeight.w900, // Black weight for maximum impact
    height: 1.0,
    letterSpacing: -2.1, // -0.05em for ultra-compact look
  );

  /// Heading Large / H1 text style (36px, black, -0.05em tracking)
  /// Usage: Screen titles
  /// Maximum visual impact with aggressive sizing
  static TextStyle get headingLarge => _style(
    fontSize: 36,
    fontWeight: FontWeight.w900, // Black weight for maximum impact
    height: 1.05,
    letterSpacing: -1.8, // -0.05em for ultra-compact look
  );

  /// Heading Medium / H2 text style (28px, black, -0.04em)
  /// Usage: Section headers
  /// Strong visual presence with tight tracking
  static TextStyle get headingMedium => _style(
    fontSize: 28,
    fontWeight: FontWeight.w900, // Black for maximum impact
    height: 1.1,
    letterSpacing: -1.4, // -0.05em for ultra-compact look
  );

  /// Heading Small / H3 text style (24px, extra-bold, -0.04em)
  /// Usage: Subsection headers, card titles
  /// Strong visual presence with tight tracking
  static TextStyle get headingSmall => _style(
    fontSize: 24,
    fontWeight: FontWeight.w800, // Extra-bold for emphasis
    height: 1.15,
    letterSpacing: -1.2, // -0.05em for ultra-compact look
  );

  // ============================================
  // BODY STYLES
  // ============================================

  /// Body Large text style (16px, medium)
  /// Usage: Emphasized paragraphs, important body text
  /// Medium weight for readable emphasis
  static TextStyle get bodyLarge => _style(
    fontSize: 16,
    fontWeight: FontWeight.w500, // Medium for readable emphasis
    height: 1.5,
    letterSpacing: -0.32, // -0.02em for readability
  );

  /// Body Medium text style (15px, regular)
  /// Usage: Primary body text, descriptions, comments, chat messages
  /// Regular weight for comfortable reading
  static TextStyle get bodyMedium => _style(
    fontSize: 15,
    fontWeight: FontWeight.w400, // Regular for easy reading
    height: 1.45,
    letterSpacing: -0.30, // -0.02em for readability
  );

  /// Body Small text style (13px, regular)
  /// Usage: Timestamps, metadata, secondary labels, placeholders
  /// Light weight for subtle secondary information
  static TextStyle get bodySmall => _style(
    fontSize: 13,
    fontWeight: FontWeight.w400, // Regular for subtle presence
    height: 1.4,
    letterSpacing: -0.26, // -0.02em for readability
  );

  // ============================================
  // UTILITY STYLES
  // ============================================

  /// Section Title text style (15px, bold)
  /// Usage: Section headers in lists, settings, feeds
  /// Title Case format (e.g., "Eventi In Arrivo")
  static TextStyle get sectionTitle => _style(
    fontSize: 15,
    fontWeight: FontWeight.w700, // Bold for section emphasis
    height: 1.4,
    letterSpacing: -0.30, // -0.02em for readability
  );

  /// Label Large text style (15px, bold)
  /// Usage: Usernames, inline emphasis
  static TextStyle get labelLarge => _style(
    fontSize: 15,
    fontWeight: FontWeight.w700, // Bold for emphasis
    height: 1.4,
    letterSpacing: -0.30, // -0.02em for readability
  );

  /// Label Medium text style (14px, semibold)
  /// Usage: Buttons, chips, badges
  static TextStyle get labelMedium => _style(
    fontSize: 14,
    fontWeight: FontWeight.w600, // SemiBold for buttons
    height: 1.35,
    letterSpacing: -0.28, // -0.02em for readability
  );

  /// Label Small text style (12px, medium)
  /// Usage: Legal text, micro labels, hints (use sparingly)
  static TextStyle get labelSmall => _style(
    fontSize: 12,
    fontWeight: FontWeight.w500, // Medium for subtle presence
    height: 1.3,
    letterSpacing: -0.24, // -0.02em for readability
  );

  /// Button text style (15px, semibold, tight line height)
  /// Usage: All buttons and CTAs
  static TextStyle get button => _style(
    fontSize: 15,
    fontWeight: FontWeight.w600, // SemiBold for buttons
    height: 1.0, // Tight for vertical centering
    letterSpacing: -0.30, // -0.02em for readability
  );

  /// Overline text style (10px, semibold, uppercase, tracked)
  /// Usage: Category labels, badges, eyebrows
  static TextStyle get overline => _style(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.5, // 0.05em = 0.5px at 10px
  );

  // ============================================
  // LEGACY ALIASES (for backward compatibility)
  // ============================================

  /// @deprecated Use [headingLarge] instead
  static TextStyle get h1 => headingLarge;

  /// @deprecated Use [headingMedium] instead
  static TextStyle get h2 => headingMedium;

  /// @deprecated Use [headingSmall] instead
  static TextStyle get h3 => headingSmall;

  /// @deprecated Use [bodyMedium] instead
  static TextStyle get body => bodyMedium;

  /// @deprecated Use [labelLarge] instead
  static TextStyle get bodyBold => labelLarge;

  /// @deprecated Use [bodySmall] instead
  static TextStyle get caption => bodySmall;

  /// @deprecated Use [labelSmall] instead
  static TextStyle get small => labelSmall;
}

/// Legacy alias for backward compatibility
/// @deprecated Use [NovaTypography] directly
typedef NovaTextStyles = NovaTypography;
