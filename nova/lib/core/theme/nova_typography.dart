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

  /// Display text style (32px, bold, -0.02em tracking)
  /// Usage: Hero headlines, splash screen titles
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.64, // -0.02em = -0.64px at 32px
  );

  /// Heading Large / H1 text style (24px, bold, -0.01em tracking)
  /// Usage: Screen titles
  static const TextStyle headingLarge = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.24, // -0.01em = -0.24px at 24px
  );

  /// Heading Medium / H2 text style (20px, semibold)
  /// Usage: Section headers
  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Heading Small / H3 text style (18px, semibold)
  /// Usage: Subsection headers, card titles
  static const TextStyle headingSmall = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  // ============================================
  // BODY STYLES
  // ============================================

  /// Body Large text style (16px, regular)
  /// Usage: Emphasized paragraphs
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Body Medium text style (15px, regular) - Instagram size
  /// Usage: Primary body text, descriptions, comments, chat
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Body Small text style (13px, regular)
  /// Usage: Timestamps, metadata, secondary labels
  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  // ============================================
  // UTILITY STYLES
  // ============================================

  /// Label Large text style (15px, semibold)
  /// Usage: Usernames, inline emphasis
  static const TextStyle labelLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// Label Medium text style (13px, semibold)
  /// Usage: Buttons, chips, badges
  static const TextStyle labelMedium = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// Label Small text style (11px, medium)
  /// Usage: Legal text, micro labels (use sparingly)
  static const TextStyle labelSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );

  /// Button text style (15px, semibold, tight line height)
  /// Usage: All buttons and CTAs
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.0, // Tight for vertical centering
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
