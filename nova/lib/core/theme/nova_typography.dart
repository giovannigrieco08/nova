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

  /// Display text style (42px, black, -0.05em tracking)
  /// Usage: Hero headlines, splash screen titles
  /// Maximum visual impact with aggressive sizing
  static const TextStyle display = TextStyle(
    fontSize: 42,
    fontWeight: FontWeight.w900, // Black weight for maximum impact
    height: 1.0,
    letterSpacing: -2.1, // -0.05em for ultra-compact look
  );

  /// Heading Large / H1 text style (36px, black, -0.05em tracking)
  /// Usage: Screen titles
  /// Maximum visual impact with aggressive sizing
  static const TextStyle headingLarge = TextStyle(
    fontSize: 36,
    fontWeight: FontWeight.w900, // Black weight for maximum impact
    height: 1.05,
    letterSpacing: -1.8, // -0.05em for ultra-compact look
  );

  /// Heading Medium / H2 text style (28px, black, -0.04em)
  /// Usage: Section headers
  /// Strong visual presence with tight tracking
  static const TextStyle headingMedium = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900, // Black for maximum impact
    height: 1.1,
    letterSpacing: -1.4, // -0.05em for ultra-compact look
  );

  /// Heading Small / H3 text style (24px, extra-bold, -0.04em)
  /// Usage: Subsection headers, card titles
  /// Strong visual presence with tight tracking
  static const TextStyle headingSmall = TextStyle(
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
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500, // Medium for readable emphasis
    height: 1.5,
    letterSpacing: -0.32, // -0.02em for readability
  );

  /// Body Medium text style (15px, regular)
  /// Usage: Primary body text, descriptions, comments, chat messages
  /// Regular weight for comfortable reading
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400, // Regular for easy reading
    height: 1.45,
    letterSpacing: -0.30, // -0.02em for readability
  );

  /// Body Small text style (13px, regular)
  /// Usage: Timestamps, metadata, secondary labels, placeholders
  /// Light weight for subtle secondary information
  static const TextStyle bodySmall = TextStyle(
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
  static const TextStyle sectionTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700, // Bold for section emphasis
    height: 1.4,
    letterSpacing: -0.30, // -0.02em for readability
  );

  /// Label Large text style (15px, bold)
  /// Usage: Usernames, inline emphasis
  static const TextStyle labelLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700, // Bold for emphasis
    height: 1.4,
    letterSpacing: -0.30, // -0.02em for readability
  );

  /// Label Medium text style (14px, semibold)
  /// Usage: Buttons, chips, badges
  static const TextStyle labelMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600, // SemiBold for buttons
    height: 1.35,
    letterSpacing: -0.28, // -0.02em for readability
  );

  /// Label Small text style (12px, medium)
  /// Usage: Legal text, micro labels, hints (use sparingly)
  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500, // Medium for subtle presence
    height: 1.3,
    letterSpacing: -0.24, // -0.02em for readability
  );

  /// Button text style (15px, semibold, tight line height)
  /// Usage: All buttons and CTAs
  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600, // SemiBold for buttons
    height: 1.0, // Tight for vertical centering
    letterSpacing: -0.30, // -0.02em for readability
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
