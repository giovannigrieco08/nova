// Widget: PendingEventBanner
// Feature: Events Feed - Pending Events Section
// Purpose: Compact banner showing user's pending events awaiting moderation

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../domain/entities/event.dart';

/// Compact banner widget for displaying pending events at top of feed.
///
/// Shows:
/// - Small thumbnail (50x50) with dark overlay
/// - "In attesa di approvazione" status text
/// - Event title (truncated)
/// - Chevron indicating tappable
///
/// Visible only to the event creator.
class PendingEventBanner extends StatelessWidget {
  final Event event;
  final VoidCallback onTap;

  const PendingEventBanner({
    super.key,
    required this.event,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: NovaColors.card(context),
          border: Border(
            bottom: BorderSide(
              color: NovaColors.divider(context),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Thumbnail with dark overlay
            _buildThumbnail(context),
            const SizedBox(width: 12),
            // Status and title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'In attesa di approvazione',
                    style: TextStyle(
                      color: NovaColors.warning(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: NovaColors.textPrimary(context),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right,
              color: NovaColors.textTertiary(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    return ClipRRect(
      borderRadius: NovaRadius.circularXs,
      child: SizedBox(
        width: 50,
        height: 50,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Event image
            if (event.imageUrl != null)
              CachedNetworkImage(
                imageUrl: event.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: NovaColors.surface(context),
                  child: Icon(
                    Icons.event,
                    color: NovaColors.textTertiary(context),
                    size: 24,
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: NovaColors.surface(context),
                  child: Icon(
                    Icons.event,
                    color: NovaColors.textTertiary(context),
                    size: 24,
                  ),
                ),
              )
            else
              Container(
                color: NovaColors.surface(context),
                child: Icon(
                  Icons.event,
                  color: NovaColors.textTertiary(context),
                  size: 24,
                ),
              ),
            // Dark overlay
            Container(
              color: Colors.black.withValues(alpha: 0.5),
            ),
            // Clock icon in center
            Center(
              child: Icon(
                Icons.schedule,
                color: Colors.white.withValues(alpha: 0.9),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
