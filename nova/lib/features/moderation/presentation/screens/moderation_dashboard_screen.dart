// =====================================================================
// ModerationDashboardScreen - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Main moderation queue screen showing pending events
// Architecture: ConsumerWidget with pendingEventsProvider
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/features/moderation/presentation/providers/pending_events_provider.dart';
import 'package:nova/features/moderation/presentation/providers/realtime_connection_provider.dart';
import 'package:nova/features/moderation/presentation/widgets/pending_event_card.dart';
import 'package:nova/features/moderation/presentation/widgets/moderator_stats_widget.dart';
import 'package:nova/features/moderation/presentation/screens/event_review_screen.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_scaffold.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_app_bar.dart';

/// Moderation dashboard screen
///
/// Shows:
/// - Personal moderator statistics (top)
/// - Pending events list (sorted oldest first)
/// - Empty state when no pending events
/// - Real-time updates via Supabase stream
///
/// Tapping event card navigates to EventReviewScreen.
class ModerationDashboardScreen extends ConsumerWidget {
  const ModerationDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingEventsAsync = ref.watch(pendingEventsProvider);
    final isConnected = ref.watch(realtimeConnectionProvider);

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: const Text('Moderazione'),
      ),
      body: Column(
        children: [
          // Connection status banner (T076 - Phase 5)
          if (!isConnected)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: NovaSpacing.m,
                vertical: NovaSpacing.s,
              ),
              decoration: BoxDecoration(
                color: NovaColors.warning(context).withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(
                    color: NovaColors.warning(context),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 16,
                    color: NovaColors.warning(context),
                  ),
                  const SizedBox(width: NovaSpacing.s),
                  Expanded(
                    child: Text(
                      'Modalità offline - Aggiornamenti ogni 15 secondi',
                      style: NovaTextStyles.caption.copyWith(
                        color: NovaColors.warning(context),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Main content
          Expanded(
            child: pendingEventsAsync.when(
              data: (events) => _buildContent(context, ref, events),
              loading: () => _buildLoading(context),
              error: (error, stack) => _buildError(context, error),
            ),
          ),
        ],
      ),
    );
  }

  /// Build main content with stats and events list
  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<dynamic> events,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        // Invalidate provider to trigger refresh
        ref.invalidate(pendingEventsProvider);
      },
      color: NovaColors.primary(context),
      child: CustomScrollView(
        slivers: [
          // Stats widget (sticky at top)
          const SliverToBoxAdapter(
            child: ModeratorStatsWidget(),
          ),

          // Section header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                NovaSpacing.l,
                NovaSpacing.l,
                NovaSpacing.l,
                NovaSpacing.s,
              ),
              child: Text(
                events.isEmpty
                    ? 'Nessun evento in attesa'
                    : 'Eventi in attesa (${events.length})',
                style: NovaTextStyles.h3.copyWith(
                  color: NovaColors.textPrimary(context),
                ),
              ),
            ),
          ),

          // Pending events list
          if (events.isEmpty)
            SliverFillRemaining(
              child: _buildEmptyState(context),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final event = events[index];
                  return PendingEventCard(
                    event: event,
                    onTap: () => _navigateToReview(context, event),
                  );
                },
                childCount: events.length,
              ),
            ),

          // Bottom spacing
          const SliverToBoxAdapter(
            child: SizedBox(height: NovaSpacing.xxl),
          ),
        ],
      ),
    );
  }

  /// Build loading state
  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: NovaColors.primary(context),
          ),
          const SizedBox(height: NovaSpacing.l),
          Text(
            'Caricamento eventi...',
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Build error state
  Widget _buildError(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: NovaColors.error(context),
            ),
            const SizedBox(height: NovaSpacing.l),
            Text(
              'Errore nel caricamento',
              style: NovaTextStyles.h3.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.s),
            Text(
              error.toString(),
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Build empty state (no pending events)
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: NovaColors.success(context),
            ),
            const SizedBox(height: NovaSpacing.l),
            Text(
              'Coda vuota!',
              style: NovaTextStyles.h2.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.s),
            Text(
              'Non ci sono eventi in attesa di moderazione.',
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Navigate to event review screen
  void _navigateToReview(BuildContext context, dynamic event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EventReviewScreen(event: event),
      ),
    );
  }
}
