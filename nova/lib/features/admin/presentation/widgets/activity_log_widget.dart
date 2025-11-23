// =====================================================================
// ActivityLogWidget - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Display activity log with filtering capabilities
// Architecture: ConsumerWidget with real-time updates
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/features/admin/domain/entities/activity_log_entry.dart';
import 'package:nova/features/admin/presentation/providers/activity_log_provider.dart';
import 'package:nova/features/admin/presentation/providers/activity_log_filter_provider.dart';

/// Activity log widget with filtering and date navigation
///
/// Displays stream of admin and moderation actions with:
/// - Action type filter dropdown (All, Approved, Rejected, Promoted, Removed)
/// - Date navigation (previous/next day buttons)
/// - Real-time updates via Supabase Realtime
class ActivityLogWidget extends ConsumerWidget {
  const ActivityLogWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityLogAsync = ref.watch(activityLogProvider);
    final filter = ref.watch(activityLogFilterProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Filters section
        _buildFilters(context, ref, filter),

        const SizedBox(height: NovaSpacing.m),

        // Activity log entries
        activityLogAsync.when(
          data: (entries) => _buildEntries(context, entries),
          loading: () => _buildLoading(),
          error: (error, stack) => _buildError(context, error),
        ),
      ],
    );
  }

  /// Build filter controls (action type dropdown + date navigation)
  Widget _buildFilters(
    BuildContext context,
    WidgetRef ref,
    ActivityLogFilter filter,
  ) {
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
        children: [
          // Action type filter dropdown
          Row(
            children: [
              Expanded(
                child: _buildActionTypeFilter(context, ref, filter),
              ),
            ],
          ),

          const SizedBox(height: NovaSpacing.m),

          // Date navigation
          _buildDateNavigation(context, ref, filter),
        ],
      ),
    );
  }

  /// Build action type filter dropdown
  Widget _buildActionTypeFilter(
    BuildContext context,
    WidgetRef ref,
    ActivityLogFilter filter,
  ) {
    return DropdownButtonFormField<String?>(
      value: filter.actionType,
      decoration: InputDecoration(
        labelText: 'Tipo azione',
        border: OutlineInputBorder(
          borderRadius: NovaRadius.circularS,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: NovaSpacing.m,
          vertical: NovaSpacing.s,
        ),
      ),
      items: const [
        DropdownMenuItem(value: null, child: Text('Tutte')),
        DropdownMenuItem(value: 'approved', child: Text('Approvato')),
        DropdownMenuItem(value: 'rejected', child: Text('Rifiutato')),
        DropdownMenuItem(value: 'promoted', child: Text('Promosso')),
        DropdownMenuItem(value: 'removed', child: Text('Rimosso')),
      ],
      onChanged: (value) {
        ref.read(activityLogFilterProvider.notifier).state =
            filter.copyWith(actionType: value);
      },
    );
  }

  /// Build date navigation controls
  Widget _buildDateNavigation(
    BuildContext context,
    WidgetRef ref,
    ActivityLogFilter filter,
  ) {
    final dateFormat = DateFormat('dd MMM yyyy', 'it');
    final selectedDate = filter.startDate ?? DateTime.now();

    return Row(
      children: [
        // Previous day button
        IconButton(
          onPressed: () {
            final previousDay = selectedDate.subtract(const Duration(days: 1));
            ref.read(activityLogFilterProvider.notifier).state =
                filter.copyWith(
              startDate: DateTime(
                previousDay.year,
                previousDay.month,
                previousDay.day,
              ),
              endDate: DateTime(
                previousDay.year,
                previousDay.month,
                previousDay.day,
                23,
                59,
                59,
              ),
            );
          },
          icon: const Icon(Icons.chevron_left),
        ),

        // Current date display
        Expanded(
          child: Center(
            child: Text(
              filter.startDate != null
                  ? dateFormat.format(selectedDate)
                  : 'Tutte le date',
              style: NovaTextStyles.bodyBold,
            ),
          ),
        ),

        // Next day button (disabled if today)
        IconButton(
          onPressed: selectedDate.isBefore(
            DateTime.now().subtract(const Duration(days: 1)),
          )
              ? () {
                  final nextDay = selectedDate.add(const Duration(days: 1));
                  ref.read(activityLogFilterProvider.notifier).state =
                      filter.copyWith(
                    startDate: DateTime(
                      nextDay.year,
                      nextDay.month,
                      nextDay.day,
                    ),
                    endDate: DateTime(
                      nextDay.year,
                      nextDay.month,
                      nextDay.day,
                      23,
                      59,
                      59,
                    ),
                  );
                }
              : null,
          icon: const Icon(Icons.chevron_right),
        ),

        // Clear date filter button
        if (filter.startDate != null)
          IconButton(
            onPressed: () {
              ref.read(activityLogFilterProvider.notifier).state =
                  filter.copyWith(
                startDate: null,
                endDate: null,
              );
            },
            icon: const Icon(Icons.clear),
            tooltip: 'Mostra tutte le date',
          ),
      ],
    );
  }

  /// Build list of activity log entries
  Widget _buildEntries(BuildContext context, List<ActivityLogEntry> entries) {
    if (entries.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: NovaSpacing.s),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return _buildLogEntry(context, entry);
      },
    );
  }

  /// Build single log entry card
  Widget _buildLogEntry(BuildContext context, ActivityLogEntry entry) {
    final timeFormat = DateFormat('HH:mm', 'it');
    final dateFormat = DateFormat('dd MMM', 'it');

    return Container(
      padding: const EdgeInsets.all(NovaSpacing.m),
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
          // Header: timestamp and action badge
          Row(
            children: [
              // Timestamp
              Text(
                '${timeFormat.format(entry.timestamp)} · ${dateFormat.format(entry.timestamp)}',
                style: NovaTextStyles.caption.copyWith(
                  color: NovaColors.textSecondary(context),
                ),
              ),

              const SizedBox(width: NovaSpacing.s),

              // Action badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: NovaSpacing.s,
                  vertical: NovaSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: _getActionBadgeColor(context, entry.actionColor),
                  borderRadius: NovaRadius.circularS,
                ),
                child: Text(
                  entry.actionDescription,
                  style: NovaTextStyles.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: NovaSpacing.s),

          // Actor name
          Text(
            entry.actorName,
            style: NovaTextStyles.bodyBold,
          ),

          const SizedBox(height: NovaSpacing.xxs),

          // Target (event title or user name)
          Text(
            entry.targetDescription,
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),

          // Rejection reason (if applicable)
          if (entry.rejectionReason != null) ...[
            const SizedBox(height: NovaSpacing.s),
            Container(
              padding: const EdgeInsets.all(NovaSpacing.s),
              decoration: BoxDecoration(
                color: NovaColors.error(context).withOpacity(0.1),
                borderRadius: NovaRadius.circularS,
              ),
              child: Text(
                'Motivo: ${entry.rejectionReason}',
                style: NovaTextStyles.caption.copyWith(
                  color: NovaColors.error(context),
                ),
              ),
            ),
          ],

          // Role change info (for admin actions)
          if (entry.isAdminAction && entry.oldRole != null) ...[
            const SizedBox(height: NovaSpacing.s),
            Text(
              '${entry.oldRole} → ${entry.newRole}',
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textTertiary(context),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Get badge color based on action type
  Color _getActionBadgeColor(BuildContext context, String colorKey) {
    switch (colorKey) {
      case 'success':
        return NovaColors.success(context);
      case 'error':
        return NovaColors.error(context);
      case 'primary':
        return NovaColors.primary(context);
      case 'warning':
        return NovaColors.warning(context);
      default:
        return NovaColors.textSecondary(context);
    }
  }

  /// Build empty state
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(NovaSpacing.xl),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: NovaColors.textTertiary(context),
            ),
            const SizedBox(height: NovaSpacing.m),
            Text(
              'Nessuna attività',
              style: NovaTextStyles.h3.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.s),
            Text(
              'Le azioni di moderazione e amministrazione appariranno qui',
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textTertiary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build loading state
  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.xl),
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// Build error state
  Widget _buildError(BuildContext context, Object error) {
    return Container(
      padding: const EdgeInsets.all(NovaSpacing.l),
      decoration: BoxDecoration(
        color: NovaColors.error(context).withOpacity(0.1),
        borderRadius: NovaRadius.circularM,
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: NovaColors.error(context),
          ),
          const SizedBox(height: NovaSpacing.m),
          Text(
            'Errore nel caricamento log',
            style: NovaTextStyles.bodyBold.copyWith(
              color: NovaColors.error(context),
            ),
          ),
          const SizedBox(height: NovaSpacing.s),
          Text(
            error.toString(),
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
