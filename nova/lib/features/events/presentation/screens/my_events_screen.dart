// Screen: MyEventsScreen
// Feature: 004-event-creation-moderation (US2 - Status Tracking)
// Feature: 007-coorganizer-management (T083 - Tabs for Co-Organized Events)
// Purpose: Display user's created events and co-organized events with tabs
//
// Features:
// - Tab 1: "Miei Eventi" - List of user's created events (all statuses)
// - Tab 2: "Co-Organizzati" - List of events where user is co-organizer
// - EventStatusBadge for each event
// - Show rejection_reason if status='rejected' (expandable)
// - Empty states for each tab
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
import 'rejected_event_edit_screen.dart';

/// My Events screen showing user's created events and co-organized events
class MyEventsScreen extends ConsumerWidget {
  const MyEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('I Miei Eventi'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: NovaColors.background(context),
          foregroundColor: NovaColors.textPrimary(context),
          bottom: TabBar(
            labelColor: NovaColors.primary(context),
            unselectedLabelColor: NovaColors.textSecondary(context),
            indicatorColor: NovaColors.primary(context),
            labelStyle: NovaTextStyles.bodyBold,
            unselectedLabelStyle: NovaTextStyles.body,
            tabs: const [
              Tab(text: 'Miei Eventi'),
              Tab(text: 'Co-Organizzati'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Tab 1: Created Events
            _buildCreatedEventsTab(context, ref),
            // Tab 2: Co-Organized Events
            _buildCoOrganizedEventsTab(context, ref),
          ],
        ),
      ),
    );
  }

  /// Build created events tab
  Widget _buildCreatedEventsTab(BuildContext context, WidgetRef ref) {
    final myEventsAsync = ref.watch(myEventsProvider);

    return myEventsAsync.when(
      data: (events) => _buildEventsList(
        context,
        ref,
        events,
        emptyMessage: 'Nessun evento creato',
        emptyDescription: 'Crea il tuo primo evento per vederlo qui!',
        onRefresh: () => ref.invalidate(myEventsProvider),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildError(context, error.toString()),
    );
  }

  /// Build co-organized events tab
  Widget _buildCoOrganizedEventsTab(BuildContext context, WidgetRef ref) {
    final coOrganizedAsync = ref.watch(coOrganizedEventsProvider);

    return coOrganizedAsync.when(
      data: (events) => _buildEventsList(
        context,
        ref,
        events,
        emptyMessage: 'Nessun evento co-organizzato',
        emptyDescription:
            'Quando qualcuno ti aggiungerà come co-organizer, vedrai gli eventi qui!',
        onRefresh: () => ref.invalidate(coOrganizedEventsProvider),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildError(context, error.toString()),
    );
  }

  /// Build events list
  Widget _buildEventsList(
    BuildContext context,
    WidgetRef ref,
    List<Event> events, {
    required String emptyMessage,
    required String emptyDescription,
    required VoidCallback onRefresh,
  }) {
    if (events.isEmpty) {
      return _buildEmptyState(context, emptyMessage, emptyDescription);
    }

    return RefreshIndicator(
      onRefresh: () async {
        onRefresh();
      },
      child: ListView.separated(
        padding: EdgeInsets.all(NovaSpacing.m),
        itemCount: events.length,
        separatorBuilder: (context, index) => SizedBox(height: NovaSpacing.m),
        itemBuilder: (context, index) => _buildEventCard(context, events[index]),
      ),
    );
  }

  /// Build event card
  Widget _buildEventCard(BuildContext context, Event event) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NovaRadius.l),
        side: BorderSide(color: NovaColors.border(context)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(NovaRadius.l),
        onTap: () {
          // TODO(#003): Navigate to EventDetailScreen with event.id parameter
        },
        child: Padding(
          padding: EdgeInsets.all(NovaSpacing.m),
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
                      style: NovaTextStyles.h3,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: NovaSpacing.s),
                  EventStatusBadge(
                    status: event.status,
                    compact: true,
                  ),
                ],
              ),
              SizedBox(height: NovaSpacing.s),

              // Event date/time
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: NovaColors.textSecondary(context),
                  ),
                  SizedBox(width: NovaSpacing.xs),
                  Text(
                    event.formattedDateTime,
                    style: NovaTextStyles.caption.copyWith(
                      color: NovaColors.textSecondary(context),
                    ),
                  ),
                ],
              ),

              // Location (if exists)
              if (event.location != null) ...[
                SizedBox(height: NovaSpacing.xs),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: NovaColors.textSecondary(context),
                    ),
                    SizedBox(width: NovaSpacing.xs),
                    Expanded(
                      child: Text(
                        event.location!,
                        style: NovaTextStyles.caption.copyWith(
                          color: NovaColors.textSecondary(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              // Rejection reason (if rejected) + Edit button
              if (event.rejectionReason != null) ...[
                SizedBox(height: NovaSpacing.m),
                Container(
                  padding: EdgeInsets.all(NovaSpacing.s),
                  decoration: BoxDecoration(
                    color: NovaColors.error(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(NovaRadius.s),
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
                          SizedBox(width: NovaSpacing.xs),
                          Text(
                            'Motivo rifiuto:',
                            style: NovaTextStyles.caption.copyWith(
                              color: NovaColors.error(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: NovaSpacing.xs),
                      Text(
                        event.rejectionReason!,
                        style: NovaTextStyles.caption.copyWith(
                          color: NovaColors.error(context),
                        ),
                      ),
                      SizedBox(height: NovaSpacing.s),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => RejectedEventEditScreen(event: event),
                              ),
                            );
                          },
                          icon: Icon(Icons.edit, size: 16),
                          label: Text('Modifica e Ri-sottometti'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: NovaColors.primary(context),
                            side: BorderSide(color: NovaColors.primary(context)),
                          ),
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
  Widget _buildEmptyState(
    BuildContext context,
    String message,
    String description,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 64,
              color: NovaColors.textSecondary(context),
            ),
            SizedBox(height: NovaSpacing.m),
            Text(
              message,
              style: NovaTextStyles.h2.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.s),
            Text(
              description,
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

  /// Error state
  Widget _buildError(BuildContext context, String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: NovaColors.error(context),
            ),
            SizedBox(height: NovaSpacing.m),
            Text(
              'Errore nel caricamento',
              style: NovaTextStyles.h2.copyWith(
                color: NovaColors.error(context),
              ),
            ),
            SizedBox(height: NovaSpacing.s),
            Text(
              error,
              style: NovaTextStyles.caption.copyWith(
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
