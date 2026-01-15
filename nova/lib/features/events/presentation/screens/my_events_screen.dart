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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/entities/event.dart';
import '../providers/my_events_provider.dart';
import '../widgets/event_status_badge.dart';

/// My Events screen showing user's created events
class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        data: (events) => _buildEventsList(context, ref, events),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(context, error.toString()),
      ),
    );
  }

  /// Build events list
  Widget _buildEventsList(BuildContext context, WidgetRef ref, List<Event> events) {
    if (events.isEmpty) {
      return _buildEmptyState(context);
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
        itemBuilder: (context, index) => _buildEventCard(context, events[index]),
      ),
    );
  }

  /// Build event card
  Widget _buildEventCard(BuildContext context, Event event) {
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
              // Header: Title + Status Badge
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

  /// Empty state
  Widget _buildEmptyState(BuildContext context) {
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
  Widget _buildError(BuildContext context, String error) {
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
