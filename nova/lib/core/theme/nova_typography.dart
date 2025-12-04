// lib/core/theme/nova_typography.dart

import 'package:flutter/material.dart';

/// Nova typography system with consistent text styles.
///
/// All text in Nova MUST use these constants to ensure:
/// - Visual consistency across the app
/// - Proper hierarchy and readability
/// - Easy maintenance and updates
///
/// Never use hardcoded TextStyle values - always use NovaTypography.
class NovaTypography {
  // Prevent instantiation
  NovaTypography._();

  // ============================================
  // HEADING STYLES
  // ============================================

  /// Display text style (34px, black, -0.03em tracking)
  /// Usage: Hero headlines, splash screen titles
  static const TextStyle display = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.w800, // Extra-bold for impact
    height: 1.0,
    letterSpacing: -1.02, // -0.03em for Framer-style impact
  );

  /// Heading Large / H1 text style (28px, extra-bold, -0.03em tracking)
  /// Usage: Screen titles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800, // Extra-bold for more impact
    height: 1.1,
    letterSpacing: -0.84, // -0.03em for Framer-style impact
  );

  /// Heading Medium / H2 text style (22px, bold, -0.03em)
  /// Usage: Section headers
  static const TextStyle headingMedium = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.66, // -0.03em for Framer-style impact
  );

  /// Heading Small / H3 text style (18px, bold, -0.03em)
  /// Usage: Subsection headers, card titles
  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.54, // -0.03em for Framer-style impact
  );

  // ============================================
  // BODY STYLES
  // ============================================

  /// Body Large text style (16px, medium)
  /// Usage: Emphasized paragraphs
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500, // Medium for more presence
    height: 1.5,
    letterSpacing: -0.32, // -0.02em for better readability
  );

  /// Body Medium text style (15px, medium) - Instagram size
  /// Usage: Primary body text, descriptions, comments, chat
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.3, // -0.02em for better readability
  );

  /// Body Small text style (13px, regular)
  /// Usage: Timestamps, metadata, secondary labels
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.26, // -0.02em for better readability
  );

  // ============================================
  // UTILITY STYLES
  // ============================================

  /// Label Large text style (15px, bold)
  /// Usage: Usernames, inline emphasis
  static const TextStyle labelLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700, // Bold for emphasis
    height: 1.4,
    letterSpacing: -0.3, // -0.02em for Inter
  );

  /// Label Medium text style (14px, semibold)
  /// Usage: Buttons, chips, badges
  static const TextStyle labelMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.28, // -0.02em for Inter
  );

  /// Label Small text style (12px, semibold)
  /// Usage: Legal text, micro labels (use sparingly)
  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600, // Semibold for readability at small size
    height: 1.3,
    letterSpacing: -0.24, // -0.02em for Inter
  );

  /// Button text style (15px, bold, tight line height)
  /// Usage: All buttons and CTAs
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700, // Bold for buttons
    height: 1.0, // Tight for vertical centering
    letterSpacing: -0.3, // -0.02em for Inter
  );

  /// Overline text style (10px, semibold, uppercase, tracked)
  /// Usage: Category labels, badges, eyebrows
  static const TextStyle overline = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.5, // 0.05em = 0.5px at 10px
  );

  // ============================================
  // LEGACY ALIASES (for backward compatibility)
  // ============================================

  /// @deprecated Use [headingLarge] instead
  static const TextStyle h1 = headingLarge;

  /// @deprecated Use [headingMedium] instead
  static const TextStyle h2 = headingMedium;

  /// @deprecated Use [headingSmall] instead
  static const TextStyle h3 = headingSmall;

  /// @deprecated Use [bodyMedium] instead
  static const TextStyle body = bodyMedium;

  /// @deprecated Use [labelLarge] instead
  static const TextStyle bodyBold = labelLarge;

  /// @deprecated Use [bodySmall] instead
  static const TextStyle caption = bodySmall;

  /// @deprecated Use [labelSmall] instead
  static const TextStyle small = labelSmall;
}

/// Legacy alias for backward compatibility
/// @deprecated Use [NovaTypography] directly
typedef NovaTextStyles = NovaTypography;
