// Widget: EventCard
// Feature: 003-events-feed
// Purpose: Glassmorphic event card for feed display (Instagram-like UX)

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../shared/widgets/glass_container.dart';
import '../../domain/entities/event.dart';
import '../utils/date_formatter.dart';

class EventCard extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;
  final bool showParticipantBadge;

  const EventCard({
    super.key,
    required this.event,
    this.onTap,
    this.showParticipantBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        margin: const EdgeInsets.symmetric(
          horizontal: NovaSpacing.m,
          vertical: NovaSpacing.m,
        ),
        padding: EdgeInsets.zero,
        borderRadius: NovaRadius.l,
        blur: 25.0, // Strong blur for Instagram-like glassmorphism
        opacity: isDark ? 0.3 : 0.2, // More transparent for glass effect
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image (4:3 aspect ratio for more impact)
            _buildCoverImage(context),

            // Content
            Padding(
              padding: const EdgeInsets.all(NovaSpacing.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title - larger and bolder
                  Text(
                    event.title,
                    style: NovaTextStyles.h2.copyWith(
                      color: isDark
                          ? NovaColors.textPrimaryDark
                          : NovaColors.textPrimaryLight,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: NovaSpacing.m),

                  // Date & Location - larger icons and text
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: isDark
                            ? NovaColors.textSecondaryDark
                            : NovaColors.textSecondaryLight,
                      ),
                      const SizedBox(width: NovaSpacing.s),
                      Text(
                        DateFormatter.cardEventDate(event.eventDate, event.eventTime),
                        style: NovaTextStyles.body.copyWith(
                          color: isDark
                              ? NovaColors.textSecondaryDark
                              : NovaColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NovaSpacing.s),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 18,
                        color: isDark
                            ? NovaColors.textSecondaryDark
                            : NovaColors.textSecondaryLight,
                      ),
                      const SizedBox(width: NovaSpacing.s),
                      Expanded(
                        child: Text(
                          event.location,
                          style: NovaTextStyles.body.copyWith(
                            color: isDark
                                ? NovaColors.textSecondaryDark
                                : NovaColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: NovaSpacing.m),

                  // Description preview - larger text
                  Text(
                    event.description,
                    style: NovaTextStyles.body.copyWith(
                      color: isDark
                          ? NovaColors.textTertiaryDark
                          : NovaColors.textTertiaryLight,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context) {
    final hasImage = event.coverImages.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final imageWidget = AspectRatio(
      aspectRatio: 4 / 3, // Larger, more impactful like Instagram
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(NovaRadius.l),
        ),
        child: hasImage
            ? CachedNetworkImage(
                imageUrl: event.coverImages.first,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: isDark ? Colors.grey[800] : Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
                errorWidget: (context, url, error) => _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );

    // Wrap with Hero for smooth animation to detail screen
    if (hasImage) {
      return Hero(
        tag: 'event-${event.id}',
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          color: isDark ? Colors.grey[800] : Colors.grey[200],
          child: Center(
            child: Icon(
              Icons.event_rounded,
              size: 64,
              color: isDark ? Colors.grey[600] : Colors.grey[400],
            ),
          ),
        );
      },
    );
  }
}
