// Screen: ModeratorStatsScreen
// Feature: 004-event-creation-moderation (US3 - Moderation Queue)
// Purpose: Dashboard showing moderation statistics and metrics
//
// Metrics:
// - Total pending events (real-time)
// - Events moderated today/this week/this month
// - Approval vs rejection rate
// - Average moderation time
//
// Access: Moderators only

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../providers/moderation_stats_provider.dart';

/// Moderator statistics dashboard screen
class ModeratorStatsScreen extends ConsumerWidget {
  const ModeratorStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(moderationStatsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiche Moderazione'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NovaColors.background(context),
        foregroundColor: NovaColors.textPrimary(context),
      ),
      body: statsAsync.when(
        data: (stats) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(moderationStatsProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(NovaSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Panoramica Moderazione',
                  style: NovaTextStyles.h2,
                ),
                SizedBox(height: NovaSpacing.s),
                Text(
                  'Statistiche sulla tua attività di moderazione',
                  style: NovaTextStyles.body.copyWith(
                    color: NovaColors.textSecondary(context),
                  ),
                ),
                SizedBox(height: NovaSpacing.l),

                // Pending events card (prominent)
                _buildPendingCard(context, stats.totalPending),
                SizedBox(height: NovaSpacing.m),

                // Today's activity
                _buildSectionTitle(context, 'Attività di Oggi'),
                SizedBox(height: NovaSpacing.s),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.check_circle_outline,
                        iconColor: NovaColors.successLight,
                        label: 'Approvati',
                        value: stats.approvedToday.toString(),
                      ),
                    ),
                    SizedBox(width: NovaSpacing.s),
                    Expanded(
                      child: _buildStatCard(
                        context,
                        icon: Icons.cancel_outlined,
                        iconColor: NovaColors.error(context),
                        label: 'Rifiutati',
                        value: stats.rejectedToday.toString(),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: NovaSpacing.l),

                // This week's activity
                _buildSectionTitle(context, 'Questa Settimana'),
                SizedBox(height: NovaSpacing.s),
                _buildStatCard(
                  context,
                  icon: Icons.calendar_today_outlined,
                  iconColor: NovaColors.primary(context),
                  label: 'Eventi Approvati',
                  value: stats.approvedThisWeek.toString(),
                ),
                SizedBox(height: NovaSpacing.l),

                // This month's activity
                _buildSectionTitle(context, 'Questo Mese'),
                SizedBox(height: NovaSpacing.s),
                _buildStatCard(
                  context,
                  icon: Icons.event_available_outlined,
                  iconColor: NovaColors.primary(context),
                  label: 'Eventi Approvati',
                  value: stats.approvedThisMonth.toString(),
                ),
                SizedBox(height: NovaSpacing.l),

                // Performance metrics
                _buildSectionTitle(context, 'Metriche di Performance'),
                SizedBox(height: NovaSpacing.s),
                _buildPerformanceCard(context, stats),
                SizedBox(height: NovaSpacing.l),

                // Info box
                _buildInfoBox(context),
              ],
            ),
          ),
        ),
        loading: () => Center(
          child: CircularProgressIndicator(
            color: NovaColors.primary(context),
          ),
        ),
        error: (error, stack) => Center(
          child: Padding(
            padding: EdgeInsets.all(NovaSpacing.l),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 80,
                  color: NovaColors.error(context),
                ),
                SizedBox(height: NovaSpacing.m),
                Text(
                  'Errore di Caricamento',
                  style: NovaTextStyles.h2,
                ),
                SizedBox(height: NovaSpacing.s),
                Text(
                  error.toString(),
                  style: NovaTextStyles.caption.copyWith(
                    color: NovaColors.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: NovaSpacing.l),
                ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(moderationStatsProvider);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Riprova'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build section title
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: NovaTextStyles.h3,
    );
  }

  /// Build pending events card (prominent)
  Widget _buildPendingCard(BuildContext context, int count) {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.l),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NovaColors.primary(context),
            NovaColors.primary(context).withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(NovaRadius.l),
        boxShadow: [
          BoxShadow(
            color: NovaColors.primary(context).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.pending_actions_outlined,
            size: 48,
            color: NovaColors.onPrimaryLight,
          ),
          SizedBox(width: NovaSpacing.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: NovaTextStyles.h1.copyWith(
                    color: NovaColors.onPrimaryLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  count == 1 ? 'Evento in Attesa' : 'Eventi in Attesa',
                  style: NovaTextStyles.body.copyWith(
                    color: NovaColors.onPrimaryLight.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            Icon(
              Icons.arrow_forward_ios,
              color: NovaColors.onPrimaryLight,
              size: 20,
            ),
        ],
      ),
    );
  }

  /// Build stat card
  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.m),
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        borderRadius: BorderRadius.circular(NovaRadius.m),
        border: Border.all(color: NovaColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 32),
          SizedBox(height: NovaSpacing.s),
          Text(
            value,
            style: NovaTextStyles.h2.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: NovaSpacing.xs),
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

  /// Build performance card
  Widget _buildPerformanceCard(BuildContext context, ModerationStats stats) {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.m),
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        borderRadius: BorderRadius.circular(NovaRadius.m),
        border: Border.all(color: NovaColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Approval rate
          _buildPerformanceRow(
            context,
            label: 'Tasso di Approvazione',
            value: '${stats.approvalRatePercent.toStringAsFixed(1)}%',
            icon: Icons.trending_up_outlined,
          ),
          Divider(height: NovaSpacing.l),

          // Rejection rate
          _buildPerformanceRow(
            context,
            label: 'Tasso di Rifiuto',
            value: '${stats.rejectionRatePercent.toStringAsFixed(1)}%',
            icon: Icons.trending_down_outlined,
          ),
          Divider(height: NovaSpacing.l),

          // Average moderation time
          _buildPerformanceRow(
            context,
            label: 'Tempo Medio di Moderazione',
            value: stats.averageModerationTimeHours != null
                ? '${stats.averageModerationTimeHours!.toStringAsFixed(1)}h'
                : 'N/A',
            icon: Icons.timer_outlined,
          ),
        ],
      ),
    );
  }

  /// Build performance row
  Widget _buildPerformanceRow(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: NovaColors.textSecondary(context),
        ),
        SizedBox(width: NovaSpacing.s),
        Expanded(
          child: Text(
            label,
            style: NovaTextStyles.body,
          ),
        ),
        Text(
          value,
          style: NovaTextStyles.button.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Build info box
  Widget _buildInfoBox(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.m),
      decoration: BoxDecoration(
        color: NovaColors.primary(context).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(NovaRadius.m),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            size: 20,
            color: NovaColors.primary(context),
          ),
          SizedBox(width: NovaSpacing.s),
          Expanded(
            child: Text(
              'Le statistiche vengono aggiornate in tempo reale. '
              'Trascina verso il basso per aggiornare i dati.',
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
