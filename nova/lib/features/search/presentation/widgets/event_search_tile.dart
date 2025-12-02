/// Event search tile widget
///
/// Compact card for displaying event search results.
/// Shows title, date, location with optional image thumbnail.

import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/search_results.dart';
import '../utils/text_highlight.dart';

/// Compact tile for event search results
class EventSearchTile extends StatelessWidget {
  final EventSearchResult event;
  final VoidCallback? onTap;
  final String? highlightQuery;

  const EventSearchTile({
    super.key,
    required this.event,
    this.onTap,
    this.highlightQuery,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NovaRadius.medium),
      child: Container(
        padding: const EdgeInsets.all(NovaSpacing.s),
        decoration: BoxDecoration(
          color: NovaColors.surfaceLight,
          borderRadius: BorderRadius.circular(NovaRadius.medium),
          border: Border.all(
            color: NovaColors.borderLight,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Event image thumbnail
            _buildThumbnail(),
            const SizedBox(width: NovaSpacing.s),
            // Event details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title with highlighting
                  highlightQuery != null && highlightQuery!.isNotEmpty
                      ? HighlightedText(
                          text: event.title,
                          query: highlightQuery!,
                          style: NovaTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: NovaColors.textPrimaryStatic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          event.title,
                          style: NovaTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: NovaColors.textPrimaryStatic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  const SizedBox(height: NovaSpacing.xxs),
                  // Date and location row
                  Row(
                    children: [
                      if (event.eventDate != null) ...[
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: NovaColors.textSecondaryStatic,
                        ),
                        const SizedBox(width: NovaSpacing.xxs),
                        Text(
                          _formatDate(event.eventDate!),
                          style: NovaTextStyles.caption.copyWith(
                            color: NovaColors.textSecondaryStatic,
                          ),
                        ),
                      ],
                      if (event.eventDate != null && event.location != null)
                        const SizedBox(width: NovaSpacing.s),
                      if (event.location != null) ...[
                        Icon(
                          Icons.location_on_outlined,
                          size: 14,
                          color: NovaColors.textSecondaryStatic,
                        ),
                        const SizedBox(width: NovaSpacing.xxs),
                        Expanded(
                          child: Text(
                            event.location!,
                            style: NovaTextStyles.caption.copyWith(
                              color: NovaColors.textSecondaryStatic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Chevron icon
            Icon(
              Icons.chevron_right,
              color: NovaColors.textTertiaryStatic,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(NovaRadius.small),
      child: Container(
        width: 56,
        height: 56,
        color: NovaColors.dividerLight,
        child: event.imageUrl != null
            ? Image.network(
                event.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Center(
      child: Icon(
        Icons.event_outlined,
        color: NovaColors.textTertiaryStatic,
        size: 24,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(date.year, date.month, date.day);

    if (eventDay == today) {
      return 'Oggi, ${DateFormat.Hm('it').format(date)}';
    } else if (eventDay == today.add(const Duration(days: 1))) {
      return 'Domani, ${DateFormat.Hm('it').format(date)}';
    } else {
      return DateFormat('d MMM', 'it').format(date);
    }
  }
}
