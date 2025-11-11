// Screen: EventDetailScreen
// Feature: 004-event-creation-moderation (Phase 6 - Event Sharing)
// Purpose: Display full event details with share button and deep link support

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart'; // NovaTextStyles
import '../../../../core/services/share_service.dart';
import '../providers/event_detail_provider.dart';
import '../providers/repository_providers.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_status.dart';

class EventDetailScreen extends ConsumerWidget {
  /// Event ID to display
  /// - If null, expects Event object passed via route arguments
  /// - If provided, fetches event by ID (deep link navigation)
  final String? eventId;

  const EventDetailScreen({
    super.key,
    this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);

    // If eventId provided, fetch event by ID (deep link navigation)
    if (eventId != null) {
      final eventAsync = ref.watch(eventDetailProvider(eventId!));

      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Dettagli Evento',
            style: NovaTextStyles.h3,
          ),
          backgroundColor: NovaColors.background(context),
          elevation: 0,
        ),
        body: eventAsync.when(
          data: (event) {
            if (event == null) {
              return _buildErrorState(
                context,
                'Evento non trovato',
                'Questo evento non esiste o è stato eliminato.',
              );
            }

            // Handle pending event (only creator and moderators can see)
            if (event.status == EventStatus.pending &&
                event.creatorId != currentUserId) {
              return _buildErrorState(
                context,
                'Evento in attesa',
                'Questo evento è in attesa di moderazione.',
              );
            }

            // Handle rejected event (only creator can see)
            if (event.status == EventStatus.rejected &&
                event.creatorId != currentUserId) {
              return _buildErrorState(
                context,
                'Evento non disponibile',
                'Questo evento non è disponibile.',
              );
            }

            return _buildEventContent(context, event, currentUserId);
          },
          loading: () => Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                NovaColors.primary(context),
              ),
            ),
          ),
          error: (error, stack) => _buildErrorState(
            context,
            'Errore',
            'Impossibile caricare l\'evento: $error',
          ),
        ),
      );
    }

    // Otherwise, expect Event object from route arguments
    final event = ModalRoute.of(context)!.settings.arguments as Event;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Dettagli Evento',
          style: NovaTextStyles.h3,
        ),
        backgroundColor: NovaColors.background(context),
        elevation: 0,
        actions: [
          // Share button (only visible if event is approved)
          if (event.status == EventStatus.approved)
            IconButton(
              icon: Icon(
                Icons.share,
                color: NovaColors.textPrimary(context),
              ),
              onPressed: () async {
                try {
                  await ShareService.shareEvent(event);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Errore durante la condivisione'),
                        backgroundColor: NovaColors.error(context),
                      ),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: _buildEventContent(context, event, currentUserId),
    );
  }

  Widget _buildEventContent(
    BuildContext context,
    Event event,
    String? currentUserId,
  ) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event Image
          if (event.imageUrl != null)
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(event.imageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),

          Padding(
            padding: EdgeInsets.all(NovaSpacing.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  event.title,
                  style: NovaTextStyles.h2.copyWith(
                    color: NovaColors.textPrimary(context),
                  ),
                ),
                SizedBox(height: NovaSpacing.m),

                // Date and Time
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 16,
                      color: NovaColors.textSecondary(context),
                    ),
                    SizedBox(width: NovaSpacing.xs),
                    Text(
                      event.formattedDateTime,
                      style: NovaTextStyles.body.copyWith(
                        color: NovaColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: NovaSpacing.s),

                // Location
                if (event.location != null)
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 16,
                        color: NovaColors.textSecondary(context),
                      ),
                      SizedBox(width: NovaSpacing.xs),
                      Expanded(
                        child: Text(
                          event.location!,
                          style: NovaTextStyles.body.copyWith(
                            color: NovaColors.textSecondary(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: NovaSpacing.l),

                // Description
                Text(
                  'Descrizione',
                  style: NovaTextStyles.h3.copyWith(
                    color: NovaColors.textPrimary(context),
                  ),
                ),
                SizedBox(height: NovaSpacing.s),
                Text(
                  event.description,
                  style: NovaTextStyles.body.copyWith(
                    color: NovaColors.textPrimary(context),
                  ),
                ),
                SizedBox(height: NovaSpacing.l),

                // Status badge (only visible to creator for non-approved events)
                if (event.creatorId == currentUserId &&
                    event.status != EventStatus.approved)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: NovaSpacing.m,
                      vertical: NovaSpacing.s,
                    ),
                    decoration: BoxDecoration(
                      color: event.status == EventStatus.pending
                          ? NovaColors.primary(context).withOpacity(0.2)
                          : NovaColors.error(context).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(NovaRadius.s),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          event.status == EventStatus.pending
                              ? Icons.hourglass_empty
                              : Icons.cancel,
                          size: 16,
                          color: event.status == EventStatus.pending
                              ? NovaColors.primary(context)
                              : NovaColors.error(context),
                        ),
                        SizedBox(width: NovaSpacing.xs),
                        Text(
                          event.status == EventStatus.pending
                              ? 'In attesa di moderazione'
                              : 'Rifiutato',
                          style: NovaTextStyles.caption.copyWith(
                            color: event.status == EventStatus.pending
                                ? NovaColors.primary(context)
                                : NovaColors.error(context),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Rejection reason (only visible to creator)
                if (event.status == EventStatus.rejected &&
                    event.creatorId == currentUserId &&
                    event.rejectionReason != null) ...[
                  SizedBox(height: NovaSpacing.m),
                  Container(
                    padding: EdgeInsets.all(NovaSpacing.m),
                    decoration: BoxDecoration(
                      color: NovaColors.error(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(NovaRadius.s),
                      border: Border.all(
                        color: NovaColors.error(context).withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Motivo del rifiuto',
                          style: NovaTextStyles.caption.copyWith(
                            color: NovaColors.error(context),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: NovaSpacing.xs),
                        Text(
                          event.rejectionReason!,
                          style: NovaTextStyles.body.copyWith(
                            color: NovaColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String title,
    String message,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.l),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: NovaColors.textSecondary(context),
            ),
            SizedBox(height: NovaSpacing.m),
            Text(
              title,
              style: NovaTextStyles.h2.copyWith(
                color: NovaColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.s),
            Text(
              message,
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: NovaSpacing.l),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.primary(context),
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.l,
                  vertical: NovaSpacing.m,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NovaRadius.s),
                ),
              ),
              child: Text(
                'Torna indietro',
                style: NovaTextStyles.button.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
