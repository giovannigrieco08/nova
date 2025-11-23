// lib/core/theme/nova_typography.dart

import 'package:flutter/material.dart';

class NovaTextStyles {
  // Prevent instantiation
  NovaTextStyles._();

  /// Display text style (32px, bold, -0.02em tracking)
  /// Usage: Hero headlines, splash screen titles
  static const TextStyle display = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.64, // -0.02em = -0.64px at 32px
  );

  /// H1 text style (24px, bold, -0.01em tracking)
  /// Usage: Screen titles
  static const TextStyle h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.24, // -0.01em = -0.24px at 24px
  );

  /// H2 text style (20px, semibold)
  /// Usage: Section headers
  static const TextStyle h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// H3 text style (18px, semibold)
  /// Usage: Subsection headers, card titles
  static const TextStyle h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  /// Body Large text style (16px, regular)
  /// Usage: Emphasized paragraphs
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );

  /// Body text style (15px, regular) - Instagram size
  /// Usage: Primary body text, descriptions, comments, chat
  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Body Bold text style (15px, semibold)
  /// Usage: Usernames, inline emphasis
  static const TextStyle bodyBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  /// Caption text style (13px, regular)
  /// Usage: Timestamps, metadata, secondary labels
  static const TextStyle caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
  );

  /// Small text style (11px, regular)
  /// Usage: Legal text, micro labels (use sparingly)
  static const TextStyle small = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w400,
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
}

/// NovaTypography - Semantic typography aliases for easier usage
///
/// This class provides semantic names for typography styles:
/// - headingLarge, headingMedium, headingSmall
/// - bodyLarge, bodyMedium, bodySmall
///
/// Maps to NovaTextStyles with clearer naming conventions.
class NovaTypography {
  // Prevent instantiation
  NovaTypography._();

  /// Heading large (24px, bold) - Maps to h1
  /// Usage: Screen titles, page headers
  static const TextStyle headingLarge = NovaTextStyles.h1;

  /// Heading medium (20px, semibold) - Maps to h2
  /// Usage: Section headers, card titles
  static const TextStyle headingMedium = NovaTextStyles.h2;

  /// Heading small (18px, semibold) - Maps to h3
  /// Usage: Subsection headers, emphasized labels
  static const TextStyle headingSmall = NovaTextStyles.h3;

  /// Body large (16px, regular) - Maps to bodyLarge
  /// Usage: Emphasized paragraphs, important text
  static const TextStyle bodyLarge = NovaTextStyles.bodyLarge;

  /// Body medium (15px, regular) - Maps to body
  /// Usage: Primary body text, descriptions
  static const TextStyle bodyMedium = NovaTextStyles.body;

  /// Body small (13px, regular) - Maps to caption
  /// Usage: Timestamps, metadata, secondary labels
  static const TextStyle bodySmall = NovaTextStyles.caption;

  /// Button text (15px, semibold, tight) - Maps to button
  /// Usage: All buttons and CTAs
  static const TextStyle button = NovaTextStyles.button;
}
