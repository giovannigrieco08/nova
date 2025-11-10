// =====================================================================
// Nova - Participants Modal
// =====================================================================
// Purpose: Display full list of event participants
// Architecture: Bottom sheet with scrollable participant list
// =====================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/user_profile.dart';
import '../../../profile/presentation/widgets/avatar_initials.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';

/// Bottom sheet modal displaying all event participants
///
/// Features:
/// - Scrollable list of participants
/// - Avatar + name + class for each participant
/// - Close button at top
/// - Performance-optimized ListView.builder
/// - Responsive to dark mode
///
/// Usage:
/// ```dart
/// showParticipantsModal(
///   context: context,
///   participants: event.participants,
///   totalCount: event.participantCount,
/// );
/// ```
class ParticipantsModal extends StatelessWidget {
  /// List of all participants
  final List<UserProfile> participants;

  /// Total participant count (for header)
  final int totalCount;

  const ParticipantsModal({
    super.key,
    required this.participants,
    required this.totalCount,
  });

  /// Show modal as bottom sheet
  static Future<void> show({
    required BuildContext context,
    required List<UserProfile> participants,
    required int totalCount,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ParticipantsModal(
        participants: participants,
        totalCount: totalCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Take 70% of screen height
    final height = MediaQuery.of(context).size.height * 0.7;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: NovaColors.background(context),
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NovaRadius.l),
        ),
      ),
      child: Column(
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.all(NovaSpacing.l),
            child: Row(
              children: [
                // Title
                Expanded(
                  child: Text(
                    'Participants ($totalCount)',
                    style: NovaTextStyles.h2.copyWith(
                      color: NovaColors.textPrimary(context),
                    ),
                  ),
                ),

                // Close button
                IconButton(
                  icon: Icon(
                    Icons.close,
                    color: NovaColors.textSecondary(context),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          // Divider
          Divider(
            height: 1,
            color: NovaColors.border(context),
          ),

          // Participants list
          Expanded(
            child: participants.isEmpty
                ? _buildEmptyState(context)
                : _buildParticipantsList(context),
          ),
        ],
      ),
    );
  }

  /// Build scrollable participants list
  Widget _buildParticipantsList(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(NovaSpacing.l),
      itemCount: participants.length,
      separatorBuilder: (context, index) => const SizedBox(
        height: NovaSpacing.m,
      ),
      itemBuilder: (context, index) {
        final participant = participants[index];
        return _buildParticipantTile(context, participant);
      },
    );
  }

  /// Build single participant tile
  Widget _buildParticipantTile(BuildContext context, UserProfile participant) {
    return Container(
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
          // Avatar
          SizedBox(
            width: 48,
            height: 48,
            child: ClipOval(
              child: participant.hasAvatar
                  ? CachedNetworkImage(
                      imageUrl: participant.avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: NovaColors.surface(context),
                        child: Center(
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: NovaColors.primary(context),
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => AvatarInitials(
                        fullName: participant.displayName,
                        size: 48,
                      ),
                    )
                  : AvatarInitials(
                      fullName: participant.displayName,
                      size: 48,
                    ),
            ),
          ),

          const SizedBox(width: NovaSpacing.m),

          // Participant info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  participant.displayName,
                  style: NovaTextStyles.bodyBold.copyWith(
                    color: NovaColors.textPrimary(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: NovaSpacing.xxs),

                // Class (if available)
                if (participant.classValue != null)
                  Text(
                    participant.classValue!,
                    style: NovaTextStyles.caption.copyWith(
                      color: NovaColors.textSecondary(context),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build empty state
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: NovaColors.textSecondary(context),
            ),
            const SizedBox(height: NovaSpacing.l),
            Text(
              'No participants yet',
              style: NovaTextStyles.h3.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.s),
            Text(
              'Be the first to join this event!',
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
}
