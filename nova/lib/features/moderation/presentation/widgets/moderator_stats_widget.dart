// =====================================================================
// ModeratorStatsWidget - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Display personal moderator statistics
// Architecture: Consumer widget with moderatorStatsProvider
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/moderation/presentation/providers/moderator_stats_provider.dart';

/// Widget displaying moderator statistics
///
/// Shows:
/// - Reviews today
/// - Reviews this week
/// - Total reviews
/// - Approval rate percentage
///
/// Updates automatically when new stats available.
class ModeratorStatsWidget extends ConsumerWidget {
  const ModeratorStatsWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(moderatorStatsProvider);

    return statsAsync.when(
      data: (stats) => _buildStatsCard(context, stats),
      loading: () => _buildLoadingCard(context),
      error: (error, stack) => _buildErrorCard(context),
    );
  }

  /// Build stats card with data
  Widget _buildStatsCard(BuildContext context, ModeratorStats stats) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: NovaSpacing.l,
        vertical: NovaSpacing.m,
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: NovaRadius.circularM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Le tue statistiche',
              style: NovaTextStyles.h3.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.m),

            // Stats grid (2x2)
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'Oggi',
                    value: stats.reviewsToday.toString(),
                    color: NovaColors.primary(context),
                  ),
                ),
                const SizedBox(width: NovaSpacing.m),
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'Questa settimana',
                    value: stats.reviewsThisWeek.toString(),
                    color: NovaColors.info(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NovaSpacing.m),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'Totale',
                    value: stats.totalReviews.toString(),
                    color: NovaColors.success(context),
                  ),
                ),
                const SizedBox(width: NovaSpacing.m),
                Expanded(
                  child: _buildStatItem(
                    context,
                    label: 'Approvazioni',
                    value: '${stats.approvalRate.toStringAsFixed(0)}%',
                    color: NovaColors.warning(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build individual stat item
  Widget _buildStatItem(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(NovaSpacing.m),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: NovaRadius.circularS,
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: NovaTextStyles.h2.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: NovaSpacing.xxs),
          Text(
            label,
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Build loading placeholder
  Widget _buildLoadingCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: NovaSpacing.l,
        vertical: NovaSpacing.m,
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: NovaRadius.circularM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Le tue statistiche',
              style: NovaTextStyles.h3.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.l),
            Center(
              child: CircularProgressIndicator(
                color: NovaColors.primary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.l),
          ],
        ),
      ),
    );
  }

  /// Build error placeholder
  Widget _buildErrorCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: NovaSpacing.l,
        vertical: NovaSpacing.m,
      ),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: NovaRadius.circularM,
      ),
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Le tue statistiche',
              style: NovaTextStyles.h3.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.m),
            Text(
              'Impossibile caricare le statistiche',
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
