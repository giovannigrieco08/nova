// =====================================================================
// Realtime Badge Widget - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Display count badge with optional fallback indicator
// Architecture: Stateless widget using NovaColors design system
// =====================================================================

import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';

/// Realtime badge showing count with optional fallback indicator
///
/// Features:
/// - Red circular badge with white count text
/// - Yellow dot indicator when fallback mode active (e.g., polling instead of WebSocket)
/// - Hides when count is 0 and no fallback indicator shown
///
/// Example usage:
/// ```dart
/// RealtimeBadge(
///   count: 5,
///   showFallbackIndicator: false, // Green (real-time)
/// )
///
/// RealtimeBadge(
///   count: 3,
///   showFallbackIndicator: true, // Yellow dot visible (polling mode)
/// )
/// ```
class RealtimeBadge extends StatelessWidget {
  /// Number to display in badge (0 hides badge)
  final int count;

  /// Whether to show yellow dot fallback indicator
  ///
  /// Use when real-time connection failed and polling fallback is active.
  /// Shows small yellow dot on top-right of badge.
  final bool showFallbackIndicator;

  const RealtimeBadge({
    super.key,
    required this.count,
    this.showFallbackIndicator = false,
  });

  @override
  Widget build(BuildContext context) {
    // Hide badge if count is 0 and no fallback indicator
    if (count == 0 && !showFallbackIndicator) {
      return const SizedBox.shrink();
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main badge container
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.xs + 2, // 6px horizontal
            vertical: NovaSpacing.xxs, // 2px vertical
          ),
          decoration: BoxDecoration(
            color: NovaColors.errorLight, // Red notification badge
            borderRadius: BorderRadius.circular(10),
          ),
          constraints: const BoxConstraints(
            minWidth: 20,
            minHeight: 20,
          ),
          child: Center(
            child: Text(
              count > 99 ? '99+' : count.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.0,
              ),
            ),
          ),
        ),

        // Yellow dot fallback indicator (top-right)
        if (showFallbackIndicator)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: NovaColors.warningLight, // Yellow dot
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 1.5,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
