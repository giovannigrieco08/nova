// Widget: GlassContainer
// Purpose: Reusable glassmorphism effect container (blur + transparency)
// Design Pattern: Semi-transparent background with backdrop blur

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/nova_radius.dart';
import '../../core/theme/nova_colors.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color? color;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.margin,
    this.borderRadius = NovaRadius.m,
    this.blur = 25.0, // Increased from 10.0 for stronger effect
    this.opacity = 0.25, // Increased from 0.1 for more transparency
    this.color,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor =
        isDark ? NovaColors.backgroundLight : NovaColors.backgroundDark;

    return Container(
      width: width,
      height: height,
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (color ?? defaultColor).withValues(alpha: opacity),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(
                    color: (color ?? defaultColor)
                        .withValues(alpha: 0.4), // Increased from 0.2
                    width: 2.0, // Increased from 1.5 for more prominent border
                  ),
              boxShadow: [
                BoxShadow(
                  color: NovaColors.backgroundDark
                      .withValues(alpha: isDark ? 0.3 : 0.15),
                  blurRadius: 30, // Increased for stronger shadow
                  offset: const Offset(0, 12),
                  spreadRadius: 2,
                ),
                // Add inner glow for glass effect
                BoxShadow(
                  color: (color ?? defaultColor).withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
