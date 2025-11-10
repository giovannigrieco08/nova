// =====================================================================
// Nova - Participant Avatars Widget
// =====================================================================
// Purpose: Display participant avatars with overflow badge
// Architecture: Circular avatar row with "+X more" indicator
// =====================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/user_profile.dart';
import '../../../profile/presentation/widgets/avatar_initials.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';

/// Participant avatars widget with overflow badge
///
/// Features:
/// - Shows up to 5 participant avatars
/// - Displays "+X more" badge if participants > 5
/// - Tappable to open full participants list modal
/// - Uses AvatarInitials for users without photos
/// - Responsive to dark mode
///
/// Usage:
/// ```dart
/// ParticipantAvatars(
///   participants: event.participants,
///   totalCount: event.participantCount,
///   onTap: () => showParticipantsModal(context),
/// )
/// ```
class ParticipantAvatars extends StatelessWidget {
  /// List of participants to display (should be max 5 for performance)
  final List<UserProfile> participants;

  /// Total participant count (for "+X more" badge)
  final int totalCount;

  /// Callback when tapped (opens full list modal)
  final VoidCallback? onTap;

  /// Avatar size in pixels
  final double size;

  const ParticipantAvatars({
    super.key,
    required this.participants,
    required this.totalCount,
    this.onTap,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    // Show max 5 avatars
    final displayedParticipants = participants.take(5).toList();
    final remainingCount = totalCount - displayedParticipants.length;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NovaRadius.full),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar stack (overlapping)
          SizedBox(
            height: size,
            child: Stack(
              children: [
                for (int i = 0; i < displayedParticipants.length; i++)
                  Positioned(
                    left: i * (size - NovaSpacing.s),
                    child: _buildAvatar(
                      context,
                      displayedParticipants[i],
                    ),
                  ),
              ],
            ),
          ),

          // Spacing between avatars and badge
          SizedBox(
            width: displayedParticipants.isEmpty
                ? 0
                : (displayedParticipants.length - 1) * (size - NovaSpacing.s) +
                    size +
                    NovaSpacing.s,
          ),

          // "+X more" badge
          if (remainingCount > 0) _buildOverflowBadge(context, remainingCount),
        ],
      ),
    );
  }

  /// Build single avatar (with photo or initials)
  Widget _buildAvatar(BuildContext context, UserProfile participant) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: NovaColors.background(context),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: participant.hasAvatar
            ? CachedNetworkImage(
                imageUrl: participant.avatarUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: NovaColors.surface(context),
                  child: Center(
                    child: SizedBox(
                      width: size * 0.5,
                      height: size * 0.5,
                      child: CircularProgressIndicator(
                        color: NovaColors.primary(context),
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => AvatarInitials(
                  fullName: participant.displayName,
                  size: size,
                ),
              )
            : AvatarInitials(
                fullName: participant.displayName,
                size: size,
              ),
      ),
    );
  }

  /// Build "+X more" overflow badge
  Widget _buildOverflowBadge(BuildContext context, int count) {
    return Container(
      height: size,
      padding: const EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: NovaColors.primary(context),
        borderRadius: BorderRadius.circular(NovaRadius.full),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: NovaTextStyles.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
