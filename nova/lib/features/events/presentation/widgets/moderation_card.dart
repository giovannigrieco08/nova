// Widget: ModerationCard
// Feature: 004-event-creation-moderation (US3 - Moderation Queue)
// Purpose: Display pending event with approve/reject actions for moderators
//
// Layout:
// - Event image (16:9 ratio) or placeholder
// - Title + description preview
// - Event date/time + location
// - Creator info (name + class)
// - Action buttons: Approve (green) + Reject (red)
// - Loading overlay during action

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/entities/event.dart';

/// Moderation card for pending event review
class ModerationCard extends StatelessWidget {
  final Event event;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool isLoading;

  const ModerationCard({
    super.key,
    required this.event,
    required this.onApprove,
    required this.onReject,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NovaRadius.l),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event image (16:9) or placeholder
              _buildEventImage(context),

              Padding(
                padding: EdgeInsets.all(NovaSpacing.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      event.title,
                      style: NovaTextStyles.h3,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: NovaSpacing.s),

                    // Description preview
                    Text(
                      event.description,
                      style: NovaTextStyles.body.copyWith(
                        color: NovaColors.textSecondary(context),
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: NovaSpacing.m),

                    // Event date/time + location
                    _buildEventDetails(context),

                    SizedBox(height: NovaSpacing.m),

                    // Creator info
                    _buildCreatorInfo(context),

                    SizedBox(height: NovaSpacing.m),

                    // Action buttons
                    _buildActionButtons(context),
                  ],
                ),
              ),
            ],
          ),

          // Loading overlay
          if (isLoading) _buildLoadingOverlay(context),
        ],
      ),
    );
  }

  /// Build event image or placeholder
  Widget _buildEventImage(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NovaRadius.l),
        ),
        child: event.imageUrl != null
            ? Image.network(
                event.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(context),
              )
            : _buildPlaceholder(context),
      ),
    );
  }

  /// Placeholder image for events without images
  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      color: NovaColors.surface(context),
      child: Center(
        child: Icon(
          Icons.event_outlined,
          size: 48,
          color: NovaColors.textSecondary(context),
        ),
      ),
    );
  }

  /// Build event date/time + location
  Widget _buildEventDetails(BuildContext context) {
    final dateFormatter = DateFormat('dd/MM/yyyy HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date/Time
        Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 16,
              color: NovaColors.textSecondary(context),
            ),
            SizedBox(width: NovaSpacing.xs),
            Text(
              dateFormatter.format(event.eventDate),
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],
        ),

        // Location (if provided)
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
      ],
    );
  }

  /// Build creator info (name + class)
  Widget _buildCreatorInfo(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.s),
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        borderRadius: BorderRadius.circular(NovaRadius.s),
      ),
      child: Row(
        children: [
          Icon(
            Icons.person_outline,
            size: 16,
            color: NovaColors.textSecondary(context),
          ),
          SizedBox(width: NovaSpacing.xs),
          Text(
            'Creato da: ${event.creatorId}', // TODO: Replace with actual user name
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Build action buttons (Approve + Reject)
  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        // Reject button (red)
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : onReject,
            icon: const Icon(Icons.close, size: 20),
            label: const Text('Rifiuta'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: NovaSpacing.m),
              side: BorderSide(color: NovaColors.error(context)),
              foregroundColor: NovaColors.error(context),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NovaRadius.m),
              ),
            ),
          ),
        ),

        SizedBox(width: NovaSpacing.s),

        // Approve button (green)
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onApprove,
            icon: const Icon(Icons.check, size: 20),
            label: const Text('Approva'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: NovaSpacing.m),
              backgroundColor: NovaColors.approveGreen,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NovaRadius.m),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Build loading overlay
  Widget _buildLoadingOverlay(BuildContext context) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(NovaRadius.l),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: NovaColors.primary(context),
          ),
        ),
      ),
    );
  }
}
