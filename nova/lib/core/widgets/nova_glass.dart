// lib/core/widgets/nova_glass.dart

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';

/// Glass effect intensity levels
enum GlassLevel { subtle, medium, strong }

/// Helper class for generating liquid glass settings based on theme and level
class NovaGlass {
  NovaGlass._();

  /// Get liquid glass settings based on context theme and level
  static LiquidGlassSettings getSettings(
    BuildContext context,
    GlassLevel level,
  ) {
    final isDark = NovaColors.isDark(context);

    switch (level) {
      case GlassLevel.subtle:
        return LiquidGlassSettings(
          thickness: isDark ? 8 : 6,
          glassColor: isDark ? const Color(0x15FFFFFF) : const Color(0x18FFFFFF),
          blur: isDark ? 10 : 8,
          lightIntensity: isDark ? 1.5 : 1.2,
          ambientStrength: isDark ? 0.6 : 0.5,
        );

      case GlassLevel.medium:
        return LiquidGlassSettings(
          thickness: isDark ? 12 : 10,
          glassColor: isDark ? const Color(0x25FFFFFF) : const Color(0x20FFFFFF),
          blur: isDark ? 14 : 12,
          lightIntensity: isDark ? 1.8 : 1.5,
          ambientStrength: isDark ? 0.5 : 0.4,
        );

      case GlassLevel.strong:
        return LiquidGlassSettings(
          thickness: isDark ? 18 : 15,
          glassColor: isDark ? const Color(0x35FFFFFF) : const Color(0x30FFFFFF),
          blur: isDark ? 18 : 15,
          lightIntensity: isDark ? 2.2 : 2.0,
          ambientStrength: isDark ? 0.4 : 0.3,
        );
    }
  }
}

/// Simplified wrapper widget for liquid glass cards
///
/// Wraps LiquidGlass with Nova-specific defaults and fallback handling.
/// Use this instead of LiquidGlass directly for consistency.
class NovaGlassCard extends StatelessWidget {
  final Widget child;
  final GlassLevel level;
  final double borderRadius;

  const NovaGlassCard({
    required this.child,
    this.level = GlassLevel.subtle,
    this.borderRadius = NovaRadius.m,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    try {
      // Try liquid glass renderer
      return LiquidGlass(
        settings: NovaGlass.getSettings(context, level),
        shape: LiquidRoundedSuperellipse(
          borderRadius: Radius.circular(borderRadius),
        ),
        child: child,
      );
    } catch (e) {
      // Fallback to BackdropFilter if liquid_glass_renderer fails
      debugPrint('LiquidGlass failed, using BackdropFilter fallback: $e');
      return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0x26FFFFFF), // White 15% opacity
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: const Color(0x4DFFFFFF), // White 30% opacity
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      );
    }
  }
}
