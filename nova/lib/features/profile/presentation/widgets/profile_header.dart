// Widget: ProfileHeader
// Feature: 006-user-profile (User Story 1 - T033)
// Purpose: Displays avatar + stats (Instagram-style), name, class, bio, moderator badge

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  final VoidCallback? onEventiTap;
  final VoidCallback? onPartecipazioniTap;

  const ProfileHeader({
    required this.profile,
    this.stats,
    required this.isOwnProfile,
    this.onEditTap,
    this.onAvatarTap,
    this.onEventiTap,
    this.onPartecipazioniTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final eventsCount = stats?.eventsCreatedCount ?? 0;
    final participationsCount = stats?.participationsCount ?? 0;
    final hasActivity = eventsCount > 0 || participationsCount > 0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.large,
        vertical: NovaSpacing.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Avatar + Stats (Instagram-style, optimized spacing)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar (left)
              _buildAvatar(context),
              SizedBox(width: NovaSpacing.xlarge),
              // Stats (right) - evenly spaced with tighter layout
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatColumn(
                      context,
                      count: eventsCount,
                      label: 'eventi',
                      onTap: onEventiTap,
                      dimmed: !hasActivity,
                    ),
                    _buildStatColumn(
                      context,
                      count: participationsCount,
                      label: 'partecipazioni',
                      onTap: onPartecipazioniTap,
                      dimmed: !hasActivity,
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: NovaSpacing.small),

          // Moderator badge ABOVE name (if applicable)
          if (profile.isModerator) ...[
            _buildModeratorBadge(),
            SizedBox(height: NovaSpacing.xsmall),
          ],

          // Row 2: Name (bold, left-aligned) - Instagram style
          if (profile.fullName.isNotEmpty)
            Text(
              profile.fullName,
              style: NovaTypography.labelLarge.copyWith(
                color: NovaColors.textPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),

          // Row 3: Class as plain text (not badge)
          if (profile.classYear != null && profile.classYear!.isNotEmpty) ...[
            SizedBox(height: 2),
            Text(
              profile.classYear!,
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
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
  ///
  /// When [dimmed] is true, the stat appears with reduced opacity
  /// to indicate no activity (both stats are 0).
  Widget _buildStatColumn(
    BuildContext context, {
    required int count,
    required String label,
    VoidCallback? onTap,
    bool dimmed = false,
  }) {
    // Reduce visual weight when profile has no activity
    final numberColor = dimmed
        ? NovaColors.textTertiary(context)
        : NovaColors.textPrimary(context);
    final labelColor = dimmed
        ? NovaColors.textTertiary(context)
        : NovaColors.textSecondary(context);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Prominent number (Instagram-style bold)
        Text(
          count.toString(),
          style: NovaTypography.headingLarge.copyWith(
            color: numberColor,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        SizedBox(height: 2),
        // Label below
        Text(
          label,
          style: NovaTypography.bodySmall.copyWith(
            color: labelColor,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );

    // Don't make zero stats tappable if dimmed
    return Expanded(
      child: (onTap != null && !dimmed)
          ? GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: content,
            )
          : content,
    );
  }

  /// Build avatar with gradient border for moderators
  Widget _buildAvatar(BuildContext context) {
    final size = 80.0; // Instagram-style smaller avatar

    // DEBUG: Print avatar URL to diagnose Android loading issue
    debugPrint('🖼️ ProfileHeader avatar URL: ${profile.avatarUrl}');

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
                child: CachedNetworkImage(
                  key: ValueKey(profile.avatarUrl),
                  imageUrl: profile.avatarUrl!,
                  cacheKey: profile.avatarUrl!,
                  width: size - 4,
                  height: size - 4,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _buildInitialsAvatar(size - 4),
                  errorWidget: (context, url, error) {
                    debugPrint('❌ ProfileHeader avatar error: $error for URL: $url');
                    return _buildInitialsAvatar(size - 4);
                  },
                  fadeInDuration: Duration.zero,
                  fadeOutDuration: Duration.zero,
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
