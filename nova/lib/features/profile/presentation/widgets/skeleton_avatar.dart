// Widget: SkeletonAvatar
// Feature: 002-profile-setup
// Purpose: Shimmer loading placeholder for avatar

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/theme/nova_colors.dart';

/// Skeleton loading placeholder for avatar
///
/// Shows a 150px circle with shimmer animation
/// Used during profile loading state (NFR-001a)
class SkeletonAvatar extends StatelessWidget {
  final double size;

  const SkeletonAvatar({
    super.key,
    this.size = 150.0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = NovaColors.isDark(context);

    return Shimmer.fromColors(
      baseColor: isDark ? NovaColors.surfaceDark : NovaColors.borderLight,
      highlightColor: isDark ? NovaColors.cardDark : NovaColors.dividerLight,
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark ? NovaColors.surfaceDark : NovaColors.borderLight,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
