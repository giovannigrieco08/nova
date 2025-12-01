// Widget: ProfileHeader
// Feature: 006-user-profile (User Story 1 - T033)
// Purpose: Displays avatar, name, username, class, bio, moderator badge

import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;
import '../../domain/entities/profile.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';

/// Profile header widget with avatar, name, username, class, bio
///
/// **Design**:
/// - Avatar: 96×96px circle (or gradient with initials if no avatar)
/// - Name: NovaTypography.headingLarge
/// - Username: @username in NovaTypography.bodySmall (muted color)
/// - Class: pill badge (e.g., "3A Scientifico")
/// - Bio: max 150 chars, emoji support
/// - Moderator badge: if role=moderator, show "Moderatore 🛡️" badge
///
/// **Usage**:
/// ```dart
/// ProfileHeader(
///   profile: profile,
///   isOwnProfile: true,
/// )
/// ```
class ProfileHeader extends StatelessWidget {
  final Profile profile;
  final bool isOwnProfile;
  final VoidCallback? onEditTap; // Only shown if isOwnProfile=true

  const ProfileHeader({
    required this.profile,
    required this.isOwnProfile,
    this.onEditTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(NovaSpacing.large),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar with optional gradient border for moderators
          _buildAvatar(context),
          SizedBox(height: NovaSpacing.medium),

          // Full name
          if (profile.fullName != null && profile.fullName!.isNotEmpty)
            Text(
              profile.fullName!,
              style: NovaTypography.headingLarge.copyWith(
                color: NovaColors.textPrimary(context),
              ),
              textAlign: TextAlign.center,
            ),

          SizedBox(height: NovaSpacing.xsmall),

          // Username (@nome.cognome)
          Text(
            '@${profile.username}',
            style: NovaTypography.bodySmall.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),

          SizedBox(height: NovaSpacing.small),

          // Class badge and moderator badge
          Wrap(
            spacing: NovaSpacing.small,
            runSpacing: NovaSpacing.xsmall,
            alignment: WrapAlignment.center,
            children: [
              // Class badge (if class exists)
              if (profile.classYear != null && profile.classYear!.isNotEmpty)
                _buildClassBadge(context, profile.classYear!),

              // Moderator badge (if role=moderator or admin)
              if (profile.isModerator) _buildModeratorBadge(),
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
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  /// Build avatar with gradient border for moderators
  Widget _buildAvatar(BuildContext context) {
    final size = 96.0;

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
    if (profile.fullName != null && profile.fullName!.isNotEmpty) {
      final words = profile.fullName!.trim().split(RegExp(r'\s+'));
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

  /// Build class badge (e.g., "3A Scientifico")
  Widget _buildClassBadge(BuildContext context, String classYear) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.small,
        vertical: NovaSpacing.xsmall,
      ),
      decoration: BoxDecoration(
        color: NovaColors.backgroundTertiary(context),
        borderRadius: BorderRadius.circular(NovaRadius.medium),
      ),
      child: Text(
        classYear,
        style: NovaTypography.bodySmall.copyWith(
          color: NovaColors.textPrimary(context),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// Build moderator badge ("Moderatore 🛡️")
  Widget _buildModeratorBadge() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.small,
        vertical: NovaSpacing.xsmall,
      ),
      decoration: BoxDecoration(
        color: NovaColors.brandViolet.withOpacity(0.1),
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
            'Moderatore',
            style: NovaTypography.bodySmall.copyWith(
              color: NovaColors.brandViolet,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: NovaSpacing.xsmall),
          Text(
            '🛡️',
            style: NovaTypography.bodySmall,
          ),
        ],
      ),
    );
  }
}
