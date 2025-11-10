// =====================================================================
// Nova - Event Detail Screen
// =====================================================================
// Purpose: Display full event details with real-time updates
// Architecture: ConsumerWidget with AsyncValue handling
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/event.dart';
import '../providers/event_detail_provider.dart';
import '../widgets/image_gallery.dart';
import '../../../profile/presentation/widgets/avatar_initials.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../shared/widgets/nova_toast.dart';

/// Event detail screen with full information
///
/// Features:
/// - Image gallery with hero animation
/// - Event title, date, time, location
/// - Creator profile (tappable placeholder)
/// - Full description
/// - Participant list with avatars
/// - Like and comment counts
/// - Pull-to-refresh support
/// - Real-time updates via provider
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (context) => EventDetailScreen(eventId: 'event-id'),
///   ),
/// );
/// ```
class EventDetailScreen extends ConsumerWidget {
  /// Event ID to display
  final String eventId;

  const EventDetailScreen({
    super.key,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch event detail provider
    final eventAsync = ref.watch(eventDetailProvider(eventId));

    return Scaffold(
      backgroundColor: NovaColors.background(context),
      body: eventAsync.when(
        // Data loaded successfully
        data: (event) => _buildContent(context, ref, event),

        // Loading state
        loading: () => _buildLoadingState(context),

        // Error state
        error: (error, stackTrace) => _buildErrorState(
          context,
          ref,
          error.toString(),
        ),
      ),
    );
  }

  /// Build main content (event details)
  Widget _buildContent(BuildContext context, WidgetRef ref, Event event) {
    return RefreshIndicator(
      onRefresh: () => _handleRefresh(ref),
      color: NovaColors.primary(context),
      child: CustomScrollView(
        slivers: [
          // App bar with back button
          SliverAppBar(
            backgroundColor: NovaColors.background(context),
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back,
                color: NovaColors.textPrimary(context),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            floating: true,
            snap: true,
          ),

          // Content
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image gallery (16:9 aspect ratio)
                ImageGallery(
                  images: event.coverImages,
                  heroTag: 'event-$eventId',
                ),

                // Content padding
                Padding(
                  padding: const EdgeInsets.all(NovaSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Event title
                      Text(
                        event.title,
                        style: NovaTextStyles.h1.copyWith(
                          color: NovaColors.textPrimary(context),
                        ),
                      ),

                      const SizedBox(height: NovaSpacing.l),

                      // Date and time row
                      _buildInfoRow(
                        context,
                        Icons.calendar_today_outlined,
                        _formatDateTime(event.eventDate, event.eventTime),
                      ),

                      const SizedBox(height: NovaSpacing.m),

                      // Location row
                      _buildInfoRow(
                        context,
                        Icons.location_on_outlined,
                        event.location,
                      ),

                      const SizedBox(height: NovaSpacing.xxl),

                      // Creator profile section
                      _buildCreatorSection(context, event),

                      const SizedBox(height: NovaSpacing.xxl),

                      // Description
                      Text(
                        'Description',
                        style: NovaTextStyles.h3.copyWith(
                          color: NovaColors.textPrimary(context),
                        ),
                      ),

                      const SizedBox(height: NovaSpacing.m),

                      Text(
                        event.description,
                        style: NovaTextStyles.body.copyWith(
                          color: NovaColors.textSecondary(context),
                        ),
                      ),

                      const SizedBox(height: NovaSpacing.xxl),

                      // Participants section
                      _buildParticipantsSection(context, event),

                      const SizedBox(height: NovaSpacing.xxl),

                      // Engagement stats (likes, comments)
                      _buildEngagementStats(context, event),

                      // Bottom padding for safe area
                      const SizedBox(height: NovaSpacing.xxl),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build info row (icon + text)
  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: NovaColors.textSecondary(context),
        ),
        const SizedBox(width: NovaSpacing.s),
        Expanded(
          child: Text(
            text,
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
        ),
      ],
    );
  }

  /// Build creator profile section (tappable placeholder)
  Widget _buildCreatorSection(BuildContext context, Event event) {
    return InkWell(
      onTap: () {
        // TODO: Navigate to creator's events (future feature)
        NovaToast.showInfo(
          context,
          'Creator profile view coming soon!',
        );
      },
      borderRadius: BorderRadius.circular(NovaRadius.m),
      child: Container(
        padding: const EdgeInsets.all(NovaSpacing.m),
        decoration: BoxDecoration(
          color: NovaColors.surface(context),
          borderRadius: BorderRadius.circular(NovaRadius.m),
          border: Border.all(
            color: NovaColors.border(context),
          ),
        ),
        child: Row(
          children: [
            // Creator avatar (placeholder - will use actual data when available)
            AvatarInitials(
              fullName: 'Event Creator',
              size: 48,
            ),

            const SizedBox(width: NovaSpacing.m),

            // Creator info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Created by',
                    style: NovaTextStyles.caption.copyWith(
                      color: NovaColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: NovaSpacing.xxs),
                  Text(
                    'Event Creator', // TODO: Use actual creator name from event
                    style: NovaTextStyles.bodyBold.copyWith(
                      color: NovaColors.textPrimary(context),
                    ),
                  ),
                ],
              ),
            ),

            // Arrow icon
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: NovaColors.textSecondary(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Build participants section with avatars
  Widget _buildParticipantsSection(BuildContext context, Event event) {
    // TODO: Fetch actual participants from repository
    // For now, show placeholder with empty state

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Participants',
          style: NovaTextStyles.h3.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ),

        const SizedBox(height: NovaSpacing.m),

        // Empty state (no participants yet)
        Container(
          padding: const EdgeInsets.all(NovaSpacing.l),
          decoration: BoxDecoration(
            color: NovaColors.surface(context),
            borderRadius: BorderRadius.circular(NovaRadius.m),
            border: Border.all(
              color: NovaColors.border(context),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.people_outline,
                size: 32,
                color: NovaColors.textSecondary(context),
              ),
              const SizedBox(width: NovaSpacing.m),
              Expanded(
                child: Text(
                  'No participants yet. Be the first!',
                  style: NovaTextStyles.body.copyWith(
                    color: NovaColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build engagement stats (likes, comments)
  Widget _buildEngagementStats(BuildContext context, Event event) {
    // TODO: Fetch actual like and comment counts from repository

    return Row(
      children: [
        // Likes count
        _buildStatChip(
          context,
          Icons.favorite_outline,
          '0 likes', // TODO: Use actual count
        ),

        const SizedBox(width: NovaSpacing.m),

        // Comments count
        _buildStatChip(
          context,
          Icons.comment_outlined,
          '0 comments', // TODO: Use actual count
        ),
      ],
    );
  }

  /// Build stat chip (icon + count)
  Widget _buildStatChip(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        borderRadius: BorderRadius.circular(NovaRadius.full),
        border: Border.all(
          color: NovaColors.border(context),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: NovaColors.textSecondary(context),
          ),
          const SizedBox(width: NovaSpacing.xs),
          Text(
            text,
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Build loading state
  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: NovaColors.primary(context),
          ),
          const SizedBox(height: NovaSpacing.l),
          Text(
            'Loading event...',
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Build error state with retry button
  Widget _buildErrorState(BuildContext context, WidgetRef ref, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: NovaColors.error(context),
            ),
            const SizedBox(height: NovaSpacing.l),
            Text(
              'Failed to load event',
              style: NovaTextStyles.h2.copyWith(
                color: NovaColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NovaSpacing.m),
            Text(
              error,
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: NovaSpacing.xxl),
            FilledButton.icon(
              onPressed: () => _handleRefresh(ref),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: NovaColors.primary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle pull-to-refresh
  Future<void> _handleRefresh(WidgetRef ref) async {
    try {
      await ref.read(eventDetailProvider(eventId).notifier).refresh();
    } catch (e) {
      // Error already handled by provider state
    }
  }

  /// Format date and time for display
  String _formatDateTime(DateTime date, String time) {
    final dateFormat = DateFormat('EEEE, MMMM d, y'); // e.g., "Monday, January 15, 2024"
    return '${dateFormat.format(date)} at $time';
  }
}
