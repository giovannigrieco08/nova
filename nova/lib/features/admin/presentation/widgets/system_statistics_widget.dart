// =====================================================================
// SystemStatisticsWidget - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Display system-wide statistics with backlog highlighting
// Architecture: Grid layout showing event counts and moderator metrics
// =====================================================================

import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/features/admin/domain/entities/system_stats.dart';

/// System statistics widget
///
/// Displays system-wide metrics:
/// - Event counts (total, pending, approved, rejected)
/// - Moderator counts (total, active in last 7 days)
/// - Average review time in hours
/// - Backlog count (events pending >24h) - highlighted in red if >0
class SystemStatisticsWidget extends StatelessWidget {
  final SystemStats stats;

  const SystemStatisticsWidget({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NovaSpacing.l),
      decoration: BoxDecoration(
        color: NovaColors.card(context),
        borderRadius: NovaRadius.circularM,
        border: Border.all(
          color: NovaColors.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panoramica Sistema',
            style: NovaTextStyles.h3,
          ),
          const SizedBox(height: NovaSpacing.l),

          // Event statistics
          _SectionHeader(title: 'Eventi'),
          const SizedBox(height: NovaSpacing.m),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Totale',
                  value: '${stats.totalEvents}',
                  color: NovaColors.primary(context),
                ),
              ),
              const SizedBox(width: NovaSpacing.m),
              Expanded(
                child: _StatCard(
                  label: 'In attesa',
                  value: '${stats.pendingEvents}',
                  color: NovaColors.warning(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: NovaSpacing.m),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Approvati',
                  value: '${stats.approvedEvents}',
                  color: NovaColors.success(context),
                ),
              ),
              const SizedBox(width: NovaSpacing.m),
              Expanded(
                child: _StatCard(
                  label: 'Rifiutati',
                  value: '${stats.rejectedEvents}',
                  color: NovaColors.error(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: NovaSpacing.l),

          // Backlog warning (highlighted if >0)
          if (stats.eventsOlderThan24h > 0)
            Container(
              padding: const EdgeInsets.all(NovaSpacing.m),
              decoration: BoxDecoration(
                color: NovaColors.error(context).withValues(alpha: 0.1),
                borderRadius: NovaRadius.circularM,
                border: Border.all(
                  color: NovaColors.error(context),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: NovaColors.error(context),
                    size: 24,
                  ),
                  const SizedBox(width: NovaSpacing.m),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BACKLOG CRITICO',
                          style: NovaTextStyles.bodyBold.copyWith(
                            color: NovaColors.error(context),
                          ),
                        ),
                        const SizedBox(height: NovaSpacing.xxs),
                        Text(
                          '${stats.eventsOlderThan24h} ${stats.eventsOlderThan24h == 1 ? "evento" : "eventi"} in attesa da più di 24 ore',
                          style: NovaTextStyles.caption.copyWith(
                            color: NovaColors.error(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: NovaSpacing.l),

          // Moderator statistics
          _SectionHeader(title: 'Moderatori'),
          const SizedBox(height: NovaSpacing.m),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Totale',
                  value: '${stats.totalModerators}',
                  color: NovaColors.primary(context),
                ),
              ),
              const SizedBox(width: NovaSpacing.m),
              Expanded(
                child: _StatCard(
                  label: 'Attivi (7 giorni)',
                  value: '${stats.activeModerators}',
                  color: NovaColors.success(context),
                ),
              ),
            ],
          ),

          const SizedBox(height: NovaSpacing.l),

          // Performance metrics
          _SectionHeader(title: 'Performance'),
          const SizedBox(height: NovaSpacing.m),
          _StatCard(
            label: 'Tempo medio revisione',
            value: '${stats.avgReviewTimeHours.toStringAsFixed(1)}h',
            color: stats.avgReviewTimeHours > 24
                ? NovaColors.warning(context)
                : NovaColors.success(context),
          ),
        ],
      ),
    );
  }
}

/// Section header widget
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: NovaTextStyles.bodyBold.copyWith(
        color: NovaColors.textSecondary(context),
      ),
    );
  }
}

/// Stat card widget
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NovaSpacing.m),
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        borderRadius: NovaRadius.circularM,
        border: Border.all(
          color: NovaColors.border(context),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: NovaTextStyles.h1.copyWith(
              color: color,
            ),
          ),
          const SizedBox(height: NovaSpacing.xs),
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
}
