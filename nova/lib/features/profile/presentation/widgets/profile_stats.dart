// Widget: ProfileStats
// Feature: 006-user-profile (User Story 1 - T034)
// Purpose: Displays "X eventi creati | Y partecipazioni"

import 'package:flutter/material.dart';
import '../../domain/entities/profile_stats.dart' as entities;
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

/// Profile statistics widget
///
/// **Design**:
/// - Format: "X eventi creati | Y partecipazioni"
/// - Centered horizontally
/// - Uses NovaTypography.bodyMedium
/// - Muted color (textSecondary)
/// - Separator: vertical divider (|)
///
/// **Usage**:
/// ```dart
/// UserProfileStats(stats: ProfileStats(eventsCreatedCount: 5, participationsCount: 12))
/// ```
class UserProfileStats extends StatelessWidget {
  final entities.ProfileStats stats;

  const UserProfileStats({
    required this.stats,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.large,
        vertical: NovaSpacing.medium,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Events created count
          _buildStatItem(
            context,
            count: stats.eventsCreatedCount,
            label: stats.eventsCreatedCount == 1
                ? 'evento creato'
                : 'eventi creati',
          ),

          // Divider
          Padding(
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
            child: Text(
              '|',
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textTertiary(context),
              ),
            ),
          ),

          // Participations count
          _buildStatItem(
            context,
            count: stats.participationsCount,
            label: stats.participationsCount == 1
                ? 'partecipazione'
                : 'partecipazioni',
          ),
        ],
      ),
    );
  }

  /// Build individual stat item (number + label)
  Widget _buildStatItem(BuildContext context,
      {required int count, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Count (bold)
        Text(
          count.toString(),
          style: NovaTypography.bodyMedium.copyWith(
            color: NovaColors.textPrimary(context),
            fontWeight: FontWeight.w600,
          ),
        ),

        SizedBox(width: NovaSpacing.xsmall),

        // Label (muted)
        Text(
          label,
          style: NovaTypography.bodySmall.copyWith(
            color: NovaColors.textSecondary(context),
          ),
        ),
      ],
    );
  }
}
