// Widget: EventsGrid
// Feature: 006-user-profile (User Story 1 - T037)
// Purpose: 3-column grid of events with lazy loading

import 'package:flutter/material.dart';
import '../../../events/domain/entities/event.dart';
import '../../../events/presentation/widgets/event_card.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

/// Events grid widget with 3 columns and lazy loading
///
/// **Design**:
/// - Grid: 3 columns (crossAxisCount: 3)
/// - Aspect ratio: 1:1 (square cards)
/// - Spacing: NovaSpacing.small between cards
/// - Lazy loading: ListView.builder with GridView
/// - Empty state: "Nessun evento" if events list is empty
/// - Loading state: shimmer placeholders
///
/// **Usage**:
/// ```dart
/// // Eventi tab (user's created events)
/// EventsGrid(
///   events: createdEvents,
///   onEventTap: (event) => Navigator.push(...),
///   emptyMessage: 'Nessun evento creato',
/// )
///
/// // Partecipazioni tab (user's participated events)
/// EventsGrid(
///   events: participatedEvents,
///   onEventTap: (event) => Navigator.push(...),
///   emptyMessage: 'Nessuna partecipazione',
/// )
/// ```
class EventsGrid extends StatelessWidget {
  final List<Event> events;
  final Function(Event) onEventTap;
  final String emptyMessage;
  final bool isLoading;

  const EventsGrid({
    required this.events,
    required this.onEventTap,
    this.emptyMessage = 'Nessun evento',
    this.isLoading = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (isLoading) {
      return _buildLoadingGrid(context);
    }

    // Empty state
    if (events.isEmpty) {
      return _buildEmptyState(context);
    }

    // Events grid
    return GridView.builder(
      padding: EdgeInsets.all(NovaSpacing.medium),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0, // Square cards
      ),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        return _buildEventGridItem(context, event);
      },
      // Performance optimization: cache extent for smooth scrolling
      cacheExtent: 1000,
    );
  }

  /// Build individual event grid item
  Widget _buildEventGridItem(BuildContext context, Event event) {
    return GestureDetector(
      onTap: () => onEventTap(event),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: NovaColors.backgroundSecondary(context),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Event image (cover image or placeholder)
            if (event.imageUrl != null && event.imageUrl!.isNotEmpty)
              Image.network(
                event.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (ctx, error, stackTrace) {
                  return _buildPlaceholder(event);
                },
                loadingBuilder: (ctx, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildPlaceholder(event);
                },
              )
            else
              _buildPlaceholder(event),

            // Gradient overlay for readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                ),
              ),
            ),

            // Event title at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.all(NovaSpacing.xsmall),
                child: Text(
                  event.title,
                  style: NovaTypography.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build placeholder for events without images
  Widget _buildPlaceholder(Event event) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            NovaColors.brandViolet,
            NovaColors.brandPink,
          ],
        ),
      ),
      child: Center(
        child: Text(
          event.title.isNotEmpty ? event.title[0].toUpperCase() : '?',
          style: NovaTypography.headingLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
    );
  }

  /// Build loading grid with shimmer placeholders
  Widget _buildLoadingGrid(BuildContext context) {
    return GridView.builder(
      padding: EdgeInsets.all(NovaSpacing.medium),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.0,
      ),
      itemCount: 9, // Show 9 placeholder cards
      itemBuilder: (ctx, index) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: NovaColors.backgroundSecondary(context),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: NovaColors.brandViolet.withOpacity(0.3),
            ),
          ),
        );
      },
    );
  }

  /// Build empty state
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.large),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_rounded,
              size: 64,
              color: NovaColors.textTertiary(context),
            ),
            SizedBox(height: NovaSpacing.medium),
            Text(
              emptyMessage,
              style: NovaTypography.bodyLarge.copyWith(
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
