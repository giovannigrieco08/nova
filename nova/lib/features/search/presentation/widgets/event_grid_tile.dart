/// Event grid tile widget
///
/// Compact square tile for displaying events in a grid layout.
/// Instagram-style design with image and overlay text.
library;

import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:intl/intl.dart';
import 'package:nova/features/events/domain/entities/event.dart';

/// Compact square tile for event grid display
class EventGridTile extends StatelessWidget {
  final Event event;
  final VoidCallback? onTap;

  const EventGridTile({
    super.key,
    required this.event,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(NovaRadius.medium),
          color: NovaColors.surfaceLight,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image or placeholder
            _buildBackground(),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    NovaColors.transparent,
                    NovaColors.overlayDark.withValues(alpha: 0.7),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
            // Content overlay
            Positioned(
              left: NovaSpacing.s,
              right: NovaSpacing.s,
              bottom: NovaSpacing.s,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Date badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: NovaSpacing.xs,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: NovaColors.primaryStatic,
                      borderRadius: BorderRadius.circular(NovaRadius.small),
                    ),
                    child: Text(
                      _formatDate(event.eventDate),
                      style: NovaTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: NovaSpacing.xxs),
                  // Title
                  Text(
                    event.title,
                    style: NovaTextStyles.body.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                    maxLines: 2,
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

  Widget _buildBackground() {
    if (event.imageUrl != null && event.imageUrl!.isNotEmpty) {
      return Image.network(
        event.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder();
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: NovaColors.primaryLight,
      child: Center(
        child: Icon(
          Icons.event_outlined,
          color: NovaColors.primaryStatic.withValues(alpha: 0.5),
          size: 40,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);

    if (eventDay == today) {
      return 'OGGI';
    } else if (eventDay == today.add(const Duration(days: 1))) {
      return 'DOMANI';
    } else {
      return DateFormat('d MMM', 'it').format(date).toUpperCase();
    }
  }
}
