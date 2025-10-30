// lib/core/theme/nova_shadows.dart

import 'package:flutter/material.dart';

/// Nova shadow constants
///
/// Defines elevation shadows used throughout Nova.
/// Shadows are subtle to complement liquid glass effect.
///
/// Never hardcode BoxShadow - always reference this class.
class NovaShadows {
  // Prevent instantiation
  NovaShadows._();

  /// No shadow - flat design
  /// Usage: Pure glass effect with no additional elevation
  static const List<BoxShadow> none = [];

  /// Small shadow (Level 1) - Subtle elevation
  /// offset(0,1) blur 2px, 5% black opacity
  /// Usage: Event cards, comment cards, standard elevated elements
  static const List<BoxShadow> small = [
    BoxShadow(
      offset: Offset(0, 1),
      blurRadius: 2,
      color: Color(0x0D000000), // rgba(0, 0, 0, 0.05)
    ),
  ];

  /// Medium shadow (Level 2) - Moderate elevation
  /// offset(0,2) blur 8px, 8% black opacity
  /// Usage: Modals, bottom sheets, overlays, floating elements
  static const List<BoxShadow> medium = [
    BoxShadow(
      offset: Offset(0, 2),
      blurRadius: 8,
      color: Color(0x14000000), // rgba(0, 0, 0, 0.08)
    ),
  ];

  /// Large shadow (Level 3) - Strong elevation
  /// offset(0,4) blur 16px, 12% black opacity
  /// Usage: Hero elements, splash screen cards, major emphasis
  static const List<BoxShadow> large = [
    BoxShadow(
      offset: Offset(0, 4),
      blurRadius: 16,
      color: Color(0x1F000000), // rgba(0, 0, 0, 0.12)
    ),
  ];
}
