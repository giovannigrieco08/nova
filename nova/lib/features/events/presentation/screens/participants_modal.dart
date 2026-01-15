// =====================================================================
// Nova - Participants Modal (Simplified - Instagram-style)
// =====================================================================
// Purpose: Display full list of event participants
// Architecture: Native Material bottom sheet with simple list
// =====================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/user_profile.dart';
import '../../../profile/presentation/widgets/avatar_initials.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_spacing.dart';
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
      isDismissible: true,
      enableDrag: true,
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
        color: NovaColors.cardLight, // Pure white (Instagram-style)
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NovaRadius.m),
        ),
      ),
      child: Column(
        children: [
          // Header with close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NovaSpacing.l, vertical: NovaSpacing.m),
            child: Row(
              children: [
                // Title
                Expanded(
                  child: Text(
                    'Partecipanti ($totalCount)',
                    style: NovaTypography.labelLarge.copyWith(
                      color: NovaColors.textPrimaryLight,
                    ),
                  ),
                ),

                // Close button
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    color: NovaColors.textPrimaryLight,
                    size: 24,
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Chiudi',
                ),
              ],
            ),
          ),

          // Divider
          const Divider(
            height: 1,
            thickness: 0.5,
            color: NovaColors.borderLight,
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
      padding: const EdgeInsets.symmetric(vertical: NovaSpacing.s),
      itemCount: participants.length,
      separatorBuilder: (context, index) => const Divider(
        height: 1,
        thickness: 0.5,
        indent: 72, // Align with text (48px avatar + 24px padding)
        color: NovaColors.borderLight,
      ),
      itemBuilder: (context, index) {
        final participant = participants[index];
        return _buildParticipantTile(context, participant);
      },
    );
  }

  /// Build single participant tile (Instagram-style)
  Widget _buildParticipantTile(BuildContext context, UserProfile participant) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: NovaSpacing.l, vertical: NovaSpacing.s),
      child: Row(
        children: [
          // Avatar (40x40 circle)
          SizedBox(
            width: 40,
            height: 40,
            child: ClipOval(
              child: participant.hasAvatar
                  ? CachedNetworkImage(
                      imageUrl: participant.avatarUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: NovaColors.placeholder,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: NovaColors.grayDark,
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => AvatarInitials(
                        fullName: participant.displayName,
                        size: 40,
                      ),
                    )
                  : AvatarInitials(
                      fullName: participant.displayName,
                      size: 40,
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
                  style: NovaTypography.labelMedium.copyWith(
                    color: NovaColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: NovaSpacing.xxs),

                // Class (if available)
                if (participant.classValue != null)
                  Text(
                    participant.classValue!,
                    style: NovaTypography.labelSmall.copyWith(
                      color: NovaColors.grayDark,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build empty state (Instagram-style)
  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: NovaColors.grayDark,
            ),
            const SizedBox(height: NovaSpacing.l),
            Text(
              'Nessun partecipante',
              style: NovaTypography.bodyLarge.copyWith(
                color: NovaColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: NovaSpacing.s),
            Text(
              'Sii il primo a partecipare!',
              style: NovaTypography.labelMedium.copyWith(
                color: NovaColors.grayDark,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
