// lib/core/theme/nova_spacing.dart

/// Nova spacing constants based on 4px grid system
///
/// All spacing in Nova MUST use these values to ensure
/// visual consistency and alignment to device pixel grids.
///
/// Never hardcode spacing values - always reference this class.
class NovaSpacing {
  // Prevent instantiation
  NovaSpacing._();

  /// Hair spacing (2px) - use sparingly
  static const double xxs = 2;

  /// Extra small spacing (4px)
  /// Usage: Tight padding, minimal gaps
  static const double xs = 4;

  /// Small spacing (8px)
  /// Usage: Between related elements, list item gaps
  static const double s = 8;

  /// Medium spacing (12px) - Instagram standard card padding
  /// Usage: Card padding, modal content padding (most common)
  static const double m = 12;

  /// Large spacing (16px)
  /// Usage: Screen horizontal padding, between unrelated elements
  static const double l = 16;

  /// Extra large spacing (20px)
  /// Usage: Section spacing, major element gaps
  static const double xl = 20;

  /// Double extra large spacing (24px)
  /// Usage: Major sections, screen top/bottom padding
  static const double xxl = 24;

  /// Triple extra large spacing (32px)
  /// Usage: Hero element spacing, splash screens
  static const double xxxl = 32;

  /// Quadruple extra large spacing (48px)
  /// Usage: Empty states, splash screens, major hero spacing
  static const double xxxxl = 48;

  // ============================================
  // SEMANTIC ALIASES (for backwards compatibility)
  // ============================================

  /// Extra extra small spacing (2px) - Alias for xxs
  static const double xxsmall = xxs;

  /// Extra small spacing (4px) - Alias for xs
  static const double xsmall = xs;

  /// Small spacing (8px) - Alias for s
  static const double small = s;

  /// Medium spacing (12px) - Alias for m
  static const double medium = m;

  /// Large spacing (16px) - Alias for l
  static const double large = l;

  /// Extra large spacing (20px) - Alias for xl
  static const double xlarge = xl;

  /// Double extra large spacing (24px) - Alias for xxl
  static const double xxlarge = xxl;

  /// Triple extra large spacing (32px) - Alias for xxxl
  static const double xxxlarge = xxxl;

  /// Quadruple extra large spacing (48px) - Alias for xxxxl
  static const double xxxxlarge = xxxxl;
}
