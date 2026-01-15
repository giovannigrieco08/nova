// lib/core/widgets/nova_glass.dart

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';

/// Glass effect intensity levels
enum GlassLevel { subtle, medium, strong }

/// Helper class for generating glass effect parameters
class NovaGlass {
  NovaGlass._();

  /// Get blur and opacity settings based on theme and level
  static ({double blur, Color glassColor, Color borderColor}) getSettings(
    BuildContext context,
    GlassLevel level,
  ) {
    final isDark = NovaColors.isDark(context);

    // Reduced blur values for better performance
    // BackdropFilter with high blur causes significant GPU load
    switch (level) {
      case GlassLevel.subtle:
        return (
          blur: isDark ? 5.0 : 4.0,  // Reduced from 10/8
          glassColor: isDark ? NovaColors.glassTintDarkSubtle : NovaColors.glassTintSubtle,
          borderColor: isDark ? NovaColors.glassBorderDarkSubtle : NovaColors.glassBorderSubtle,
        );

      case GlassLevel.medium:
        return (
          blur: isDark ? 7.0 : 6.0,  // Reduced from 14/12
          glassColor: isDark ? NovaColors.glassTintDarkMedium : NovaColors.glassTintMedium,
          borderColor: isDark ? NovaColors.glassBorderDarkMedium : NovaColors.glassBorderMedium,
        );

      case GlassLevel.strong:
        return (
          blur: isDark ? 10.0 : 8.0,  // Reduced from 18/15
          glassColor: isDark ? NovaColors.glassTintDarkStrong : NovaColors.glassTintStrong,
          borderColor: isDark ? NovaColors.glassBorderDarkStrong : NovaColors.glassBorderStrong,
        );
    }
  }
}

/// Glass morphism card widget using native BackdropFilter
///
/// Creates a frosted glass effect with blur and semi-transparent background.
/// Use this for consistent glassmorphism across the app.
class NovaGlassCard extends StatelessWidget {
  final Widget child;
  final GlassLevel level;
  final double borderRadius;

  const NovaGlassCard({
    required this.child,
    this.level = GlassLevel.subtle,
    this.borderRadius = NovaRadius.m,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final settings = NovaGlass.getSettings(context, level);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: settings.blur, sigmaY: settings.blur),
        child: Container(
          decoration: BoxDecoration(
            color: settings.glassColor,
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: settings.borderColor,
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
