import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/shared/widgets/glass_container.dart';

/// Platform-adaptive card container.
///
/// - iOS: [GlassContainer] with glassmorphism effect
/// - Android: [Material] surface with elevation
///
/// Example:
/// ```dart
/// AdaptiveCard(
///   child: Column(
///     children: [
///       Text('Title'),
///       Text('Content'),
///     ],
///   ),
/// )
/// ```
class AdaptiveCard extends StatelessWidget {
  /// Card content
  final Widget child;

  /// Internal padding
  final EdgeInsets? padding;

  /// Tap callback
  final VoidCallback? onTap;

  /// Border radius (defaults to NovaRadius.l)
  final double? borderRadius;

  /// Android only: Use elevation (shadow)
  final bool elevated;

  const AdaptiveCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.borderRadius,
    this.elevated = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? NovaRadius.l;
    final cardPadding = padding ?? const EdgeInsets.all(NovaSpacing.l);

    if (context.isIOS) {
      // iOS: Glassmorphism effect
      final glassChild = GlassContainer(
        borderRadius: radius,
        padding: cardPadding,
        child: child,
      );

      if (onTap != null) {
        return GestureDetector(
          onTap: onTap,
          child: glassChild,
        );
      }
      return glassChild;
    }

    // Android: Material Surface with elevation
    return Material(
      color: NovaColors.surface(context),
      elevation: elevated ? 1 : 0,
      surfaceTintColor: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Padding(
          padding: cardPadding,
          child: child,
        ),
      ),
    );
  }
}
