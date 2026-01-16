// Screen: ModerationQueueScreen
// Feature: 004-event-creation-moderation (US3 - Moderation Queue)
// Purpose: Main moderation interface for reviewing pending events
//
// Features:
// - List of pending events (oldest first = FIFO)
// - Pull-to-refresh
// - Approve with single tap + confirmation
// - Reject with dialog for reason entry
// - Empty state when no pending events
// - Error handling with retry
//
// Access: Moderators only (RLS policy enforced)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/animations/page_transitions.dart';
import '../providers/moderation_queue_provider.dart';
import '../providers/events_feed_provider.dart';
import '../widgets/moderation_card.dart';
import '../widgets/rejection_dialog.dart';
import 'moderator_stats_screen.dart';

/// Moderation queue screen for reviewing pending events
class ModerationQueueScreen extends ConsumerStatefulWidget {
  const ModerationQueueScreen({super.key});

  @override
  ConsumerState<ModerationQueueScreen> createState() =>
      _ModerationQueueScreenState();
}

class _ModerationQueueScreenState
    extends ConsumerState<ModerationQueueScreen> {
  String? _processingEventId; // Track which event is being processed

  @override
  Widget build(BuildContext context) {
    final pendingEventsAsync = ref.watch(moderationQueueProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coda di Moderazione'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NovaColors.background(context),
        foregroundColor: NovaColors.textPrimary(context),
        actions: [
          // Stats button (navigate to ModeratorStatsScreen)
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                NovaPageRoute.swipeBack(page: const ModeratorStatsScreen()),
              );
            },
            tooltip: 'Statistiche',
          ),
        ],
      ),
      body: pendingEventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return _buildEmptyState(context);
          }

          return RefreshIndicator(
            onRefresh: () async {
              await ref.read(moderationQueueProvider.notifier).refresh();
            },
            child: ListView.separated(
              padding: EdgeInsets.symmetric(vertical: NovaSpacing.m),
              itemCount: events.length,
              separatorBuilder: (context, index) =>
                  SizedBox(height: NovaSpacing.s),
              itemBuilder: (context, index) {
                final event = events[index];
                final isProcessing = _processingEventId == event.id;

                return ModerationCard(
                  event: event,
                  isLoading: isProcessing,
                  onApprove: () => _handleApprove(event.id),
                  onReject: () => _handleReject(event.id, event.title),
                );
              },
            ),
          );
        },
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: NovaColors.primary(context),
              ),
              SizedBox(height: NovaSpacing.m),
              Text(
                'Caricamento eventi in attesa...',
                style: NovaTextStyles.body.copyWith(
                  color: NovaColors.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
        error: (error, stack) => _buildErrorState(context, error),
      ),
    );
  }

  /// Build empty state (no pending events)
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: NovaColors.textSecondary(context),
          ),
          SizedBox(height: NovaSpacing.m),
          Text(
            'Nessun Evento in Attesa',
            style: NovaTextStyles.h2,
          ),
          SizedBox(height: NovaSpacing.s),
          Text(
            'Tutti gli eventi sono stati moderati!',
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build error state with retry button
  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
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
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: NovaSpacing.l),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(moderationQueueProvider.notifier).refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.l,
                  vertical: NovaSpacing.m,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle approve event with confirmation
  Future<void> _handleApprove(String eventId) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approva Evento'),
        content: const Text(
          'Sei sicuro di voler approvare questo evento? '
          'Sarà visibile a tutti gli studenti nel feed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: NovaColors.approveGreen,
            ),
            child: const Text('Approva'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Set loading state
    setState(() => _processingEventId = eventId);

    try {
      await ref.read(moderationQueueProvider.notifier).approveEvent(eventId);

      // Refresh the main feed so the approved event appears
      ref.invalidate(eventsFeedProvider);
      ref.invalidate(userPendingEventsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evento approvato con successo'),
            backgroundColor: NovaColors.approveGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: ${e.toString()}'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingEventId = null);
      }
    }
  }

  /// Handle reject event with reason dialog
  Future<void> _handleReject(String eventId, String eventTitle) async {
    // Show rejection dialog
    final rejectionReason = await showDialog<String>(
      context: context,
      builder: (context) => RejectionDialog(eventTitle: eventTitle),
    );

    if (rejectionReason == null) return; // User cancelled

    // Set loading state
    setState(() => _processingEventId = eventId);

    try {
      await ref.read(moderationQueueProvider.notifier).rejectEvent(eventId, rejectionReason);

      // Refresh the feed (removes from pending events banner if creator is viewing)
      ref.invalidate(eventsFeedProvider);
      ref.invalidate(userPendingEventsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Evento rifiutato'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Errore: ${e.toString()}'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingEventId = null);
      }
    }
  }
}
