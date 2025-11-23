// =====================================================================
// PendingEventCard Widget - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Display event in moderation queue with key details
// Architecture: Stateless widget using NovaColors design system
// =====================================================================

import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/moderation/data/models/moderation_event.dart';

/// Card displaying a pending event in moderation queue
///
/// Shows:
/// - Emoji icon or cover image
/// - Event title
/// - Description preview (max 150 characters)
/// - Organizer name
/// - Date/time
/// - Location
/// - Time since submission
/// - Re-submission badge (if applicable)
///
/// Tappable to navigate to EventReviewScreen.
class PendingEventCard extends StatelessWidget {
  /// Event to display
  final ModerationEvent event;

  /// Callback when card is tapped
  final VoidCallback onTap;

  const PendingEventCard({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: NovaSpacing.l,
        vertical: NovaSpacing.s,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: NovaRadius.circularM,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: NovaRadius.circularM,
        child: Padding(
          padding: const EdgeInsets.all(NovaSpacing.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Icon/Image + Title + Re-submission Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Event icon or image
                  _buildEventIcon(context),
                  const SizedBox(width: NovaSpacing.m),

                  // Title and metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          event.title,
                          style: NovaTextStyles.h3.copyWith(
                            color: NovaColors.textPrimary(context),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: NovaSpacing.xs),

                        // Organizer
                        Text(
                          'Organizzatore: ${event.organizerName}',
                          style: NovaTextStyles.caption.copyWith(
                            color: NovaColors.textSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Re-submission badge
                  if (event.isResubmission)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: NovaSpacing.s,
                        vertical: NovaSpacing.xxs,
                      ),
                      decoration: BoxDecoration(
                        color: NovaColors.warning(context).withOpacity(0.1),
                        borderRadius: NovaRadius.circularXs,
                        border: Border.all(
                          color: NovaColors.warning(context),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        'Risottomesso',
                        style: NovaTextStyles.small.copyWith(
                          color: NovaColors.warning(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: NovaSpacing.m),

              // Description preview
              Text(
                event.descriptionPreview,
                style: NovaTextStyles.body.copyWith(
                  color: NovaColors.textPrimary(context),
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: NovaSpacing.m),

              // Date, time, location
              Wrap(
                spacing: NovaSpacing.m,
                runSpacing: NovaSpacing.xs,
                children: [
                  _buildMetadataChip(
                    context,
                    icon: Icons.calendar_today,
                    label: event.formattedDateRange,
                  ),
                  if (event.location != null)
                    _buildMetadataChip(
                      context,
                      icon: Icons.location_on,
                      label: event.location!,
                    ),
                ],
              ),

              const SizedBox(height: NovaSpacing.s),

              // Time since submission
              Text(
                'Inviato ${event.timeSinceSubmission}',
                style: NovaTextStyles.caption.copyWith(
                  color: NovaColors.textTertiary(context),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build event icon (emoji or image thumbnail)
  Widget _buildEventIcon(BuildContext context) {
    if (event.emojiIcon != null) {
      // Emoji icon
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: NovaColors.primary(context).withOpacity(0.1),
          borderRadius: NovaRadius.circularS,
        ),
        child: Center(
          child: Text(
            event.emojiIcon!,
            style: const TextStyle(fontSize: 32),
          ),
        ),
      );
    } else if (event.coverImageUrl != null) {
      // Cover image thumbnail
      return ClipRRect(
        borderRadius: NovaRadius.circularS,
        child: Image.network(
          event.coverImageUrl!,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback to placeholder on error
            return Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: NovaColors.divider(context),
                borderRadius: NovaRadius.circularS,
              ),
              child: Icon(
                Icons.image_not_supported,
                color: NovaColors.textTertiary(context),
              ),
            );
          },
        ),
      );
    } else {
      // Fallback: default icon
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: NovaColors.divider(context),
          borderRadius: NovaRadius.circularS,
        ),
        child: Icon(
          Icons.event,
          color: NovaColors.textSecondary(context),
        ),
      );
    }
  }

  /// Build metadata chip (date, location, etc.)
  Widget _buildMetadataChip(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: NovaColors.textSecondary(context),
        ),
        const SizedBox(width: NovaSpacing.xxs),
        Flexible(
          child: Text(
            label,
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textSecondary(context),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
