// Widget: ProfileHeader
// Feature: 006-user-profile (User Story 1 - T033)
// Purpose: Displays avatar + stats (Instagram-style), name, class, bio, moderator badge

import 'package:flutter/material.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/profile_stats.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';

/// Profile header widget with Instagram-style layout
///
/// **Design (Instagram-style)**:
/// - Top row: Avatar (80px) on left + Stats (big numbers) on right
/// - Below: Name (bold), class badge, moderator badge
/// - Below: Bio (max 3 lines)
///
/// **Usage**:
/// ```dart
/// ProfileHeader(
///   profile: profile,
///   stats: stats,
///   isOwnProfile: true,
/// )
/// ```
class ProfileHeader extends StatelessWidget {
  final Profile profile;
  final ProfileStats? stats;
  final bool isOwnProfile;
  final VoidCallback? onEditTap;
  final VoidCallback? onAvatarTap;

  const ProfileHeader({
    required this.profile,
    this.stats,
    required this.isOwnProfile,
    this.onEditTap,
    this.onAvatarTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.large,
        vertical: NovaSpacing.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar + Stats (Instagram-style)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar (left)
              _buildAvatar(context),
              SizedBox(width: NovaSpacing.medium),
              // Stats (right) - expanded to fill remaining space
              Expanded(
                child: Row(
                  children: [
                    _buildStatColumn(
                      context,
                      count: stats?.eventsCreatedCount ?? 0,
                      label: 'eventi',
                    ),
                    _buildStatColumn(
                      context,
                      count: stats?.participationsCount ?? 0,
                      label: 'partecipazioni',
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: NovaSpacing.medium),

          // Row 2: Name (bold, left-aligned) - Instagram style
          if (profile.fullName.isNotEmpty)
            Text(
              profile.fullName,
              style: NovaTypography.labelLarge.copyWith(
                color: NovaColors.textPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),

          // Row 3: Class as plain text (not badge) + moderator badge
          if (profile.classYear != null && profile.classYear!.isNotEmpty) ...[
            SizedBox(height: 2),
            Text(
              profile.classYear!,
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
          ],

          // Moderator badge (if applicable)
          if (profile.isModerator) ...[
            SizedBox(height: NovaSpacing.xsmall),
            _buildModeratorBadge(),
          ],

          // Row 4: Bio (if exists)
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            SizedBox(height: NovaSpacing.xsmall),
            Text(
              profile.bio!,
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textPrimary(context),
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  /// Build stat column (Instagram-style: prominent number + single-line label)
  Widget _buildStatColumn(BuildContext context, {required int count, required String label}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Prominent number (Instagram-style bold)
          Text(
            count.toString(),
            style: NovaTypography.headingMedium.copyWith(
              color: NovaColors.textPrimary(context),
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          SizedBox(height: 4),
          // Label below
          Text(
            label,
            style: NovaTypography.bodySmall.copyWith(
              color: NovaColors.textSecondary(context),
              fontWeight: FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build avatar with gradient border for moderators
  Widget _buildAvatar(BuildContext context) {
    final size = 80.0; // Instagram-style smaller avatar

    // Avatar container with optional gradient border
    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // Gradient border for moderators
        gradient: profile.isModerator
            ? LinearGradient(
                colors: [NovaColors.brandViolet, NovaColors.brandPink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: profile.isModerator ? null : Colors.transparent,
      ),
      padding: EdgeInsets.all(profile.isModerator ? 2.0 : 0.0),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: NovaColors.backgroundSecondary(context),
        ),
        child: profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  profile.avatarUrl!,
                  width: size - 4,
                  height: size - 4,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, error, stackTrace) {
                    return _buildInitialsAvatar(size - 4);
                  },
                ),
              )
            : _buildInitialsAvatar(size - 4),
      ),
    );

    // Wrap with GestureDetector if onAvatarTap is provided
    if (onAvatarTap != null) {
      return GestureDetector(
        onTap: onAvatarTap,
        child: avatar,
      );
    }

    return avatar;
  }

  /// Build initials avatar with gradient background
  Widget _buildInitialsAvatar(double size) {
    // Extract initials from full_name or username
    final initials = _getInitials();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [NovaColors.brandViolet, NovaColors.brandPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: NovaTypography.headingLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Extract initials from full_name or username
  String _getInitials() {
    if (profile.fullName.isNotEmpty) {
      final words = profile.fullName.trim().split(RegExp(r'\s+'));
      if (words.length >= 2) {
        return '${words[0][0]}${words[1][0]}'.toUpperCase();
      } else if (words.isNotEmpty) {
        return words[0][0].toUpperCase();
      }
    }

    // Fallback to username first 2 chars
    if (profile.username.length >= 2) {
      return profile.username.substring(0, 2).toUpperCase();
    }

    return profile.username[0].toUpperCase();
  }

  /// Build moderator/admin badge
  Widget _buildModeratorBadge() {
    final isAdmin = profile.isAdmin;
    final label = isAdmin ? 'Admin' : 'Moderatore';
    final emoji = isAdmin ? '👑' : '🛡️';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.small,
        vertical: NovaSpacing.xsmall,
      ),
      decoration: BoxDecoration(
        color: NovaColors.brandViolet.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(NovaRadius.medium),
        border: Border.all(
          color: NovaColors.brandViolet,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            emoji,
            style: NovaTypography.bodySmall,
          ),
          SizedBox(width: NovaSpacing.xsmall),
          Text(
            label,
            style: NovaTypography.bodySmall.copyWith(
              color: NovaColors.brandViolet,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
