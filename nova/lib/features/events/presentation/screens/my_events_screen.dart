// Screen: MyEventsScreen
// Feature: 004-event-creation-moderation (US2 - Status Tracking)
// Purpose: Display user's created events with status badges
//
// Features:
// - List of user's events (all statuses)
// - EventStatusBadge for each event
// - Show rejection_reason if status='rejected' (expandable)
// - Empty state: "Nessun evento creato"
// - Pull-to-refresh
// - Delete own events

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/entities/event.dart';
import '../providers/my_events_provider.dart';
import '../providers/events_feed_provider.dart';
import '../widgets/event_status_badge.dart';

/// My Events screen showing user's created events
class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen> {
  @override
  Widget build(BuildContext context) {
    final myEventsAsync = ref.watch(myEventsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('I Miei Eventi'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NovaColors.backgroundPrimary(context),
        foregroundColor: NovaColors.textPrimary(context),
      ),
      body: myEventsAsync.when(
        data: (events) => _buildEventsList(events),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(error.toString()),
      ),
    );
  }

  /// Build events list
  Widget _buildEventsList(List<Event> events) {
    if (events.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh events
        ref.invalidate(myEventsProvider);
      },
      child: ListView.separated(
        padding: EdgeInsets.all(NovaSpacing.medium),
        itemCount: events.length,
        separatorBuilder: (context, index) => SizedBox(height: NovaSpacing.medium),
        itemBuilder: (context, index) => _buildEventCard(events[index]),
      ),
    );
  }

  /// Build event card
  Widget _buildEventCard(Event event) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NovaRadius.large),
        side: BorderSide(color: NovaColors.border(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(NovaRadius.large),
        onTap: () {
          // TODO: Navigate to event detail screen
        },
        child: Padding(
          padding: EdgeInsets.all(NovaSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title + Status Badge + Menu
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      event.title,
                      style: NovaTypography.headingSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: NovaSpacing.small),
                  EventStatusBadge(
                    status: event.status,
                    compact: true,
                  ),
                  SizedBox(width: NovaSpacing.xsmall),
                  // Menu button
                  GestureDetector(
                    onTap: () => _showEventMenu(event),
                    child: Icon(
                      Icons.more_vert,
                      size: 20,
                      color: NovaColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
              SizedBox(height: NovaSpacing.small),

              // Event date/time
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: NovaColors.textSecondary(context),
                  ),
                  SizedBox(width: NovaSpacing.xsmall),
                  Text(
                    event.formattedDateTime,
                    style: NovaTypography.bodySmall.copyWith(
                      color: NovaColors.textSecondary(context),
                    ),
                  ),
                ],
              ),

              // Location (if exists)
              if (event.location != null) ...[
                SizedBox(height: NovaSpacing.xsmall),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: NovaColors.textSecondary(context),
                    ),
                    SizedBox(width: NovaSpacing.xsmall),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: NovaTypography.bodySmall.copyWith(
                          color: NovaColors.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Rejection reason (if rejected)
              if (event.rejectionReason != null) ...[
                SizedBox(height: NovaSpacing.medium),
                Container(
                  padding: EdgeInsets.all(NovaSpacing.small),
                  decoration: BoxDecoration(
                    color: NovaColors.error(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(NovaRadius.small),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: NovaColors.error(context),
                          ),
                          SizedBox(width: NovaSpacing.xsmall),
                          Text(
                            'Motivo rifiuto:',
                            style: NovaTypography.labelSmall.copyWith(
                              color: NovaColors.error(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: NovaSpacing.xsmall),
                      Text(
                        event.rejectionReason!,
                        style: NovaTypography.bodySmall.copyWith(
                          color: NovaColors.error(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Show event menu with delete option
  void _showEventMenu(Event event) {
    if (Platform.isIOS) {
      showCupertinoModalPopup(
        context: context,
        builder: (ctx) => CupertinoActionSheet(
          actions: [
            CupertinoActionSheetAction(
              isDestructiveAction: true,
              onPressed: () {
                Navigator.pop(ctx);
                _confirmDeleteEvent(event);
              },
              child: const Text('Elimina evento'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.delete_outline, color: NovaColors.error(context)),
                title: Text(
                  'Elimina evento',
                  style: TextStyle(color: NovaColors.error(context)),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteEvent(event);
                },
              ),
            ],
          ),
        ),
      );
    }
  }

  /// Confirm and delete event
  void _confirmDeleteEvent(Event event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Elimina evento'),
        content: const Text(
          'Sei sicuro di voler eliminare questo evento? Questa azione non può essere annullata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: NovaColors.error(context)),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(eventsRepositoryProvider).deleteEvent(event.id);
        if (mounted) {
          // Refresh the list
          ref.invalidate(myEventsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Evento eliminato')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Errore: ${e.toString()}')),
          );
        }
      }
    }
  }

  /// Empty state
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.large),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 64,
              color: NovaColors.textSecondary(context),
            ),
            SizedBox(height: NovaSpacing.medium),
            Text(
              'Nessun evento creato',
              style: NovaTypography.headingMedium.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.small),
            Text(
              'Crea il tuo primo evento per vederlo qui!',
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.large),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Navigate to event creation
                Navigator.pop(context); // Go back for now
              },
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Crea evento'),
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.primary(context),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.large,
                  vertical: NovaSpacing.medium,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NovaRadius.medium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Error state
  Widget _buildError(String error) {
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
              style: NovaTypography.headingMedium.copyWith(
                color: NovaColors.error(context),
              ),
            ),
            SizedBox(height: NovaSpacing.small),
            Text(
              error,
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
