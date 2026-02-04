// Screen: ModerationScreen
// Feature: 005-moderation-admin-panel
// Purpose: Queue of pending events for moderators/admins to review

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../shared/widgets/adaptive/adaptive_scaffold.dart';
import '../../../../shared/widgets/adaptive/adaptive_loading_indicator.dart';
import '../../../events/presentation/providers/events_feed_provider.dart';
import '../../data/models/moderation_event.dart';
import '../providers/pending_events_provider.dart';

/// Moderation queue screen for admins and moderators
///
/// Shows all pending events waiting for approval/rejection.
/// Only accessible to users with 'moderator' or 'admin' roles.
class ModerationScreen extends ConsumerStatefulWidget {
  const ModerationScreen({super.key});

  @override
  ConsumerState<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends ConsumerState<ModerationScreen> {
  @override
  Widget build(BuildContext context) {
    final pendingEventsAsync = ref.watch(pendingEventsProvider);

    return AdaptiveScaffold(
      appBar: _buildAppBar(),
      body: pendingEventsAsync.when(
        data: (events) => _buildEventsList(events),
        loading: () => const Center(child: AdaptiveLoadingIndicator()),
        error: (error, _) => _buildErrorView(error),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (Platform.isIOS) {
      return CupertinoNavigationBar(
        middle: Text('Moderazione', style: NovaTypography.headingSmall),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios),
        ),
      );
    }
    return AppBar(
      title: Text(
        'Moderazione',
        style: NovaTypography.headingSmall.copyWith(
          color: NovaColors.textPrimary(context),
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new,
          color: NovaColors.textPrimary(context),
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildEventsList(List<ModerationEvent> events) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: NovaColors.success(context),
            ),
            SizedBox(height: NovaSpacing.medium),
            Text(
              'Nessun evento in attesa',
              style: NovaTypography.headingSmall.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.small),
            Text(
              'La coda di moderazione è vuota',
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(pendingEventsProvider);
      },
      child: ListView.separated(
        padding: EdgeInsets.all(NovaSpacing.medium),
        itemCount: events.length,
        separatorBuilder: (_, __) => SizedBox(height: NovaSpacing.medium),
        itemBuilder: (context, index) {
          final event = events[index];
          return _buildEventCard(event);
        },
      ),
    );
  }

  Widget _buildEventCard(ModerationEvent event) {
    return Container(
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        borderRadius: BorderRadius.circular(NovaRadius.large),
        border: Border.all(color: NovaColors.border(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with organizer info
          Padding(
            padding: EdgeInsets.all(NovaSpacing.medium),
            child: Row(
              children: [
                // Emoji/cover indicator
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: NovaColors.backgroundSecondary(context),
                    borderRadius: BorderRadius.circular(NovaRadius.medium),
                  ),
                  child: Center(
                    child: event.coverImageUrl != null
                        ? ClipRRect(
                            borderRadius:
                                BorderRadius.circular(NovaRadius.medium),
                            child: Image.network(
                              event.coverImageUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            event.emojiIcon ?? '📅',
                            style: const TextStyle(fontSize: 22),
                          ),
                  ),
                ),
                SizedBox(width: NovaSpacing.small),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: NovaTypography.labelLarge.copyWith(
                          color: NovaColors.textPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'di ${event.organizerName ?? 'Utente'} • ${event.timeSinceSubmission}',
                        style: NovaTypography.bodySmall.copyWith(
                          color: NovaColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                // Resubmission badge
                if (event.isResubmission)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: NovaSpacing.small,
                      vertical: NovaSpacing.xsmall,
                    ),
                    decoration: BoxDecoration(
                      color: NovaColors.warning(context).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(NovaRadius.small),
                    ),
                    child: Text(
                      'Re-invio',
                      style: NovaTypography.labelSmall.copyWith(
                        color: NovaColors.warning(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Description preview
          Padding(
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.medium),
            child: Text(
              event.descriptionPreview,
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textPrimary(context),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Date and location info
          Padding(
            padding: EdgeInsets.all(NovaSpacing.medium),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: NovaColors.textSecondary(context),
                ),
                SizedBox(width: NovaSpacing.xsmall),
                Expanded(
                  child: Text(
                    event.formattedDateRange,
                    style: NovaTypography.bodySmall.copyWith(
                      color: NovaColors.textSecondary(context),
                    ),
                  ),
                ),
                if (event.location != null) ...[
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: NovaColors.textSecondary(context),
                  ),
                  SizedBox(width: NovaSpacing.xsmall),
                  Text(
                    event.location!,
                    style: NovaTypography.bodySmall.copyWith(
                      color: NovaColors.textSecondary(context),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Action buttons
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: NovaColors.border(context)),
              ),
            ),
            child: Row(
              children: [
                // Reject button
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _showRejectDialog(event),
                    icon: Icon(
                      Icons.close,
                      color: NovaColors.error(context),
                    ),
                    label: Text(
                      'Rifiuta',
                      style: NovaTypography.labelMedium.copyWith(
                        color: NovaColors.error(context),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: NovaColors.border(context),
                ),
                // Approve button
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _approveEvent(event),
                    icon: Icon(
                      Icons.check,
                      color: NovaColors.success(context),
                    ),
                    label: Text(
                      'Approva',
                      style: NovaTypography.labelMedium.copyWith(
                        color: NovaColors.success(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _approveEvent(ModerationEvent event) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc('moderate_event', params: {
        'p_event_id': event.id,
        'p_action': 'approved',
      });

      // Force refresh to update UI immediately
      ref.invalidate(pendingEventsProvider);
      // Also refresh the events feed so the approved event appears there
      ref.read(eventsFeedProvider.notifier).refresh();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evento "${event.title}" approvato'),
            backgroundColor: NovaColors.success(context),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }

  Future<void> _showRejectDialog(ModerationEvent event) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Motivo del rifiuto'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            hintText: 'Inserisci il motivo...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          maxLength: 500,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () {
              if (reasonController.text.trim().isNotEmpty) {
                Navigator.pop(context, reasonController.text.trim());
              }
            },
            child: Text(
              'Rifiuta',
              style: TextStyle(color: NovaColors.error(context)),
            ),
          ),
        ],
      ),
    );

    reasonController.dispose();

    if (reason != null && reason.isNotEmpty) {
      await _rejectEvent(event, reason);
    }
  }

  Future<void> _rejectEvent(ModerationEvent event, String reason) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.rpc('moderate_event', params: {
        'p_event_id': event.id,
        'p_action': 'rejected',
        'p_rejection_reason': reason,
      });

      // Force refresh to update UI immediately
      ref.invalidate(pendingEventsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Evento "${event.title}" rifiutato'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }

  Widget _buildErrorView(Object error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.large),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: NovaColors.error(context),
            ),
            SizedBox(height: NovaSpacing.medium),
            Text(
              'Errore nel caricamento',
              style: NovaTypography.headingSmall.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.small),
            Text(
              error.toString(),
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.large),
            ElevatedButton(
              onPressed: () => ref.invalidate(pendingEventsProvider),
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}
