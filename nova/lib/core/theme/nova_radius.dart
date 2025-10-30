// lib/core/theme/nova_radius.dart

import 'package:flutter/material.dart';

/// Nova border radius constants
///
/// Defines all corner rounding values used in Nova.
/// Never hardcode radius values - always reference this class.
class NovaRadius {
  // Prevent instantiation
  NovaRadius._();

  /// Extra small radius (8px)
  /// Usage: Small buttons, chips, tags
  static const double xs = 8;

  /// Small radius (12px)
  /// Usage: Input fields, small cards, standard buttons
  static const double s = 12;

  /// Medium radius (16px) - Default for most cards
  /// Usage: Event cards, comment cards, most UI cards
  static const double m = 16;

  /// Large radius (20px)
  /// Usage: Profile cards, modals, bottom sheets, emphasized cards
  static const double l = 20;

  /// Extra large radius (24px)
  /// Usage: Hero elements, splash screen, large modals
  static const double xl = 24;

  /// Full radius (9999px) - Creates circular shape
  /// Usage: Avatars, FAB, circular buttons, pills
  static const double full = 9999;

  // ----------------------------------------------------------
  // Convenience BorderRadius Helpers (Pre-built for speed)
  // ----------------------------------------------------------

  /// BorderRadius.circular(xs) - 8px all corners
  static BorderRadius get circularXs => BorderRadius.circular(xs);

  /// BorderRadius.circular(s) - 12px all corners
  static BorderRadius get circularS => BorderRadius.circular(s);

  /// BorderRadius.circular(m) - 16px all corners
  static BorderRadius get circularM => BorderRadius.circular(m);

  /// BorderRadius.circular(l) - 20px all corners
  static BorderRadius get circularL => BorderRadius.circular(l);

  /// BorderRadius.circular(xl) - 24px all corners
  static BorderRadius get circularXl => BorderRadius.circular(xl);

  /// BorderRadius.circular(full) - Circular shape
  static BorderRadius get circularFull => BorderRadius.circular(full);

  /// BorderRadius.vertical(top: l) - 20px rounded top only
  /// Usage: Bottom sheets, modals
  static BorderRadius get topL => BorderRadius.vertical(
        top: Radius.circular(l),
      );

  /// BorderRadius.vertical(top: xl) - 24px rounded top only
  /// Usage: Large modals, emphasis
  static BorderRadius get topXl => BorderRadius.vertical(
        top: Radius.circular(xl),
      );
}
