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
      baseColor: isDark ? const Color(0xFF2D3748) : const Color(0xFFE5E7EB),
      highlightColor:
          isDark ? const Color(0xFF4A5568) : const Color(0xFFF3F4F6),
      period: const Duration(milliseconds: 1500),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D3748) : const Color(0xFFE5E7EB),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
