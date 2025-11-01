// lib/core/widgets/nova_logo.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nova/core/theme/nova_colors.dart';

/// Nova logo widget with support for light/dark themes and custom sizes
///
/// Usage:
/// ```dart
/// NovaLogo()  // Default medium size
/// NovaLogo.large()  // Large size
/// NovaLogo.small()  // Small size
/// NovaLogo(height: 100, color: NovaColors.lightPrimary)  // Custom
/// ```
class NovaLogo extends StatelessWidget {
  final double? height;
  final double? width;
  final Color? color;
  final BoxFit fit;

  const NovaLogo({
    super.key,
    this.height,
    this.width,
    this.color,
    this.fit = BoxFit.contain,
  });

  /// Small logo (24px height) - For app bars, list items
  const NovaLogo.small({
    super.key,
    this.color,
    this.fit = BoxFit.contain,
  })  : height = 24,
        width = null;

  /// Medium logo (48px height) - Default size for most UI elements
  const NovaLogo.medium({
    super.key,
    this.color,
    this.fit = BoxFit.contain,
  })  : height = 48,
        width = null;

  /// Large logo (80px height) - For login screens, splash screens
  const NovaLogo.large({
    super.key,
    this.color,
    this.fit = BoxFit.contain,
  })  : height = 80,
        width = null;

  /// Extra large logo (120px height) - For splash screens, onboarding
  const NovaLogo.extraLarge({
    super.key,
    this.color,
    this.fit = BoxFit.contain,
  })  : height = 120,
        width = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use provided color, or default to theme-appropriate color
    final logoColor = color ??
        (isDark ? NovaColors.textPrimaryDark : NovaColors.textPrimaryLight);

    return SvgPicture.asset(
      'assets/logos/nova_logo.svg',
      height: height,
      width: width,
      fit: fit,
      colorFilter: ColorFilter.mode(
        logoColor,
        BlendMode.srcIn,
      ),
      semanticsLabel: 'Nova Logo',
    );
  }
}
