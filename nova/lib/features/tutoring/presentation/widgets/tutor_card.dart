// Widget: TutorCard
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: Card displaying a tutor in the tutors list

import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../data/repositories/tutor_repository.dart';

/// TutorCard - Card displaying tutor information in the list
///
/// Shows: avatar, name, class, subjects, price, rating
/// Platform-adaptive: Cupertino on iOS, Material on Android.
class TutorCard extends StatelessWidget {
  /// Tutor profile with author data
  final TutorProfileWithAuthorData tutor;

  /// Callback when card is tapped (shows contact sheet)
  final VoidCallback onTap;

  const TutorCard({
    super.key,
    required this.tutor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Platform.isIOS ? _buildCupertinoCard(context) : _buildMaterialCard(context);
  }

  Widget _buildCupertinoCard(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: onTap,
      child: _buildCardContent(context),
    );
  }

  Widget _buildMaterialCard(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: NovaRadius.circularM,
      child: _buildCardContent(context),
    );
  }

  Widget _buildCardContent(BuildContext context) {
    final profile = tutor.profile;

    return Container(
      margin: const EdgeInsets.only(bottom: NovaSpacing.m),
      decoration: BoxDecoration(
        color: NovaColors.card(context),
        borderRadius: NovaRadius.circularM,
        border: Border.all(
          color: NovaColors.border(context),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: NovaColors.isDark(context)
                ? NovaColors.textPrimaryLight.withValues(alpha: 0.3)
                : NovaColors.textPrimaryLight.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(NovaSpacing.l),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(context),
            const SizedBox(width: NovaSpacing.m),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and class row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tutor.authorName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: NovaColors.textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (tutor.authorClass != null) ...[
                        const SizedBox(width: NovaSpacing.s),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: NovaSpacing.s,
                            vertical: NovaSpacing.xxs,
                          ),
                          decoration: BoxDecoration(
                            color: NovaColors.primary(context).withValues(alpha: 0.1),
                            borderRadius: NovaRadius.circularXs,
                          ),
                          child: Text(
                            tutor.authorClass!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: NovaColors.primary(context),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: NovaSpacing.xs),
                  // Subjects
                  Text(
                    profile.subjectsDisplay,
                    style: TextStyle(
                      fontSize: 13,
                      color: NovaColors.textSecondary(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: NovaSpacing.s),
                  // Price and rating row
                  Row(
                    children: [
                      // Price badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: NovaSpacing.s,
                          vertical: NovaSpacing.xxs,
                        ),
                        decoration: BoxDecoration(
                          color: profile.isFree
                              ? NovaColors.success(context).withValues(alpha: 0.1)
                              : NovaColors.surface(context),
                          borderRadius: NovaRadius.circularXs,
                          border: profile.isFree
                              ? null
                              : Border.all(color: NovaColors.border(context)),
                        ),
                        child: Text(
                          profile.priceDisplay,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: profile.isFree
                                ? NovaColors.success(context)
                                : NovaColors.textPrimary(context),
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Rating (if available, for Phase B)
                      if (profile.rating > 0) ...[
                        Icon(
                          Icons.star_rounded,
                          size: 16,
                          color: NovaColors.warningLight,
                        ),
                        const SizedBox(width: NovaSpacing.xxs),
                        Text(
                          profile.rating.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: NovaColors.textSecondary(context),
                          ),
                        ),
                      ],
                      // Contact icon
                      const SizedBox(width: NovaSpacing.m),
                      Icon(
                        Platform.isIOS
                            ? CupertinoIcons.chat_bubble_text
                            : Icons.chat_bubble_outline_rounded,
                        size: 20,
                        color: NovaColors.primary(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: NovaColors.border(context),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: tutor.authorAvatarUrl != null
            ? CachedNetworkImage(
                imageUrl: tutor.authorAvatarUrl!,
                fit: BoxFit.cover,
                placeholder: (_, __) => _buildAvatarPlaceholder(context),
                errorWidget: (_, __, ___) => _buildAvatarPlaceholder(context),
              )
            : _buildAvatarPlaceholder(context),
      ),
    );
  }

  Widget _buildAvatarPlaceholder(BuildContext context) {
    // Get initials from name
    final initials = tutor.authorName
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
        .join();

    return Container(
      color: NovaColors.primary(context).withValues(alpha: 0.1),
      child: Center(
        child: Text(
          initials.isEmpty ? '?' : initials,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: NovaColors.primary(context),
          ),
        ),
      ),
    );
  }
}
