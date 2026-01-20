// Widget: ProfileHeader
// Feature: 006-user-profile (User Story 1 - T033)
// Updated: 014-profile-banner - Added banner display with avatar overlay
// Purpose: Displays banner, avatar + stats (Instagram-style), name, class, bio, moderator badge

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/profile_stats.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';

/// Profile header widget with banner and Instagram-style layout
///
/// **Design**:
/// - Banner (3:1 aspect ratio, gradient fallback)
/// - Avatar (80px) overlapping banner bottom, centered
/// - Below: Name (bold), class, moderator badge
/// - Below: Stats (events, participations)
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
  final VoidCallback? onBannerTap;
  final VoidCallback? onEventiTap;
  final VoidCallback? onPartecipazioniTap;

  /// Banner height (screen width / 3 for 3:1 aspect ratio)
  static const double _bannerAspectRatio = 3.0;

  /// Avatar size
  static const double _avatarSize = 88.0;

  /// Avatar overlap (how much avatar overlaps into banner)
  static const double _avatarOverlap = 44.0;

  const ProfileHeader({
    required this.profile,
    this.stats,
    required this.isOwnProfile,
    this.onEditTap,
    this.onAvatarTap,
    this.onBannerTap,
    this.onEventiTap,
    this.onPartecipazioniTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bannerHeight = screenWidth / _bannerAspectRatio;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Banner + Avatar stack
        SizedBox(
          height: bannerHeight + _avatarSize - _avatarOverlap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: GestureDetector(
                  onTap: onBannerTap,
                  child: _buildBanner(context, screenWidth, bannerHeight),
                ),
              ),

              // Avatar (centered, overlapping banner)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: _buildAvatar(context),
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: NovaSpacing.small),

        // Content below avatar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: NovaSpacing.large),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Moderator badge (if applicable)
              if (profile.isModerator) ...[
                _buildModeratorBadge(),
                SizedBox(height: NovaSpacing.xsmall),
              ],

              // Name (bold, centered)
              if (profile.fullName.isNotEmpty)
                Text(
                  profile.fullName,
                  style: NovaTypography.labelLarge.copyWith(
                    color: NovaColors.textPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),

              // Class
              if (profile.classYear != null && profile.classYear!.isNotEmpty) ...[
                SizedBox(height: 2),
                Text(
                  profile.classYear!,
                  style: NovaTypography.bodySmall.copyWith(
                    color: NovaColors.textSecondary(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              SizedBox(height: NovaSpacing.medium),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatColumn(
                    context,
                    count: stats?.eventsCreatedCount ?? 0,
                    label: 'eventi',
                    onTap: onEventiTap,
                  ),
                  SizedBox(width: NovaSpacing.xxl),
                  _buildStatColumn(
                    context,
                    count: stats?.participationsCount ?? 0,
                    label: 'partecipazioni',
                    onTap: onPartecipazioniTap,
                  ),
                ],
              ),

              // Bio (if exists)
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                SizedBox(height: NovaSpacing.medium),
                Text(
                  profile.bio!,
                  style: NovaTypography.bodyMedium.copyWith(
                    color: NovaColors.textPrimary(context),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],

              SizedBox(height: NovaSpacing.medium),
            ],
          ),
        ),
      ],
    );
  }

  /// Build banner with image or gradient fallback
  Widget _buildBanner(BuildContext context, double width, double height) {
    final hasBanner = profile.bannerUrl != null && profile.bannerUrl!.isNotEmpty;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Fallback gradient when no banner
        gradient: !hasBanner
            ? LinearGradient(
                colors: [NovaColors.brandViolet, NovaColors.brandPink],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
      ),
      child: hasBanner
          ? CachedNetworkImage(
              imageUrl: profile.bannerUrl!,
              cacheKey: profile.bannerUrl!,
              width: width,
              height: height,
              fit: BoxFit.cover,
              placeholder: (context, url) => _buildBannerPlaceholder(context),
              errorWidget: (context, url, error) => _buildBannerFallback(),
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
            )
          : null,
    );
  }

  /// Banner loading placeholder
  Widget _buildBannerPlaceholder(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            NovaColors.brandViolet.withValues(alpha: 0.5),
            NovaColors.brandPink.withValues(alpha: 0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  /// Banner error fallback (gradient)
  Widget _buildBannerFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [NovaColors.brandViolet, NovaColors.brandPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }

  /// Build stat column (Instagram-style: prominent number + single-line label)
  Widget _buildStatColumn(
    BuildContext context, {
    required int count,
    required String label,
    VoidCallback? onTap,
  }) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Prominent number (Instagram-style bold)
        Text(
          count.toString(),
          style: NovaTypography.headingLarge.copyWith(
            color: NovaColors.textPrimary(context),
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        SizedBox(height: 2),
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
    );

    return onTap != null
        ? GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: content,
          )
        : content;
  }

  /// Build avatar with white border (for banner overlay) and gradient border for moderators
  Widget _buildAvatar(BuildContext context) {
    const size = _avatarSize;
    const borderWidth = 4.0;
    final innerSize = size - (borderWidth * 2);

    // Avatar container with white border + optional gradient border for moderators
    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: NovaColors.background(context), // White/dark border around avatar
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(borderWidth),
      child: Container(
        width: innerSize,
        height: innerSize,
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
          color: profile.isModerator ? null : NovaColors.backgroundSecondary(context),
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
                    width: innerSize - (profile.isModerator ? 4 : 0),
                    height: innerSize - (profile.isModerator ? 4 : 0),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => _buildInitialsAvatar(innerSize - (profile.isModerator ? 4 : 0)),
                    errorWidget: (context, url, error) => _buildInitialsAvatar(innerSize - (profile.isModerator ? 4 : 0)),
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                  ),
                )
              : _buildInitialsAvatar(innerSize - (profile.isModerator ? 4 : 0)),
        ),
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
