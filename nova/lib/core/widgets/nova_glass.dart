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

    switch (level) {
      case GlassLevel.subtle:
        return (
          blur: isDark ? 10.0 : 8.0,
          glassColor: isDark ? const Color(0x15FFFFFF) : const Color(0x18FFFFFF),
          borderColor: isDark ? const Color(0x30FFFFFF) : const Color(0x25FFFFFF),
        );

      case GlassLevel.medium:
        return (
          blur: isDark ? 14.0 : 12.0,
          glassColor: isDark ? const Color(0x25FFFFFF) : const Color(0x20FFFFFF),
          borderColor: isDark ? const Color(0x40FFFFFF) : const Color(0x35FFFFFF),
        );

      case GlassLevel.strong:
        return (
          blur: isDark ? 18.0 : 15.0,
          glassColor: isDark ? const Color(0x35FFFFFF) : const Color(0x30FFFFFF),
          borderColor: isDark ? const Color(0x50FFFFFF) : const Color(0x45FFFFFF),
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
    Key? key,
  }) : super(key: key);

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
