/// Profile search tile widget
///
/// Compact card for displaying profile search results.
/// Shows avatar, name, and class.
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_radius.dart';
import '../../domain/entities/search_results.dart';
import '../utils/text_highlight.dart';

/// Compact tile for profile search results
class ProfileSearchTile extends StatelessWidget {
  final ProfileSearchResult profile;
  final VoidCallback? onTap;
  final String? highlightQuery;

  const ProfileSearchTile({
    super.key,
    required this.profile,
    this.onTap,
    this.highlightQuery,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(NovaRadius.medium),
      child: Container(
        padding: const EdgeInsets.all(NovaSpacing.s),
        decoration: BoxDecoration(
          color: NovaColors.surfaceLight,
          borderRadius: BorderRadius.circular(NovaRadius.medium),
          border: Border.all(
            color: NovaColors.borderLight,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(),
            const SizedBox(width: NovaSpacing.s),
            // Profile details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name with highlighting
                  highlightQuery != null && highlightQuery!.isNotEmpty
                      ? HighlightedText(
                          text: profile.fullName,
                          query: highlightQuery!,
                          style: NovaTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: NovaColors.textPrimaryStatic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        )
                      : Text(
                          profile.fullName,
                          style: NovaTextStyles.body.copyWith(
                            fontWeight: FontWeight.w600,
                            color: NovaColors.textPrimaryStatic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                  if (profile.className != null) ...[
                    const SizedBox(height: NovaSpacing.xxs),
                    // Class
                    Row(
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 14,
                          color: NovaColors.textSecondaryStatic,
                        ),
                        const SizedBox(width: NovaSpacing.xxs),
                        Text(
                          profile.className!,
                          style: NovaTextStyles.caption.copyWith(
                            color: NovaColors.textSecondaryStatic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Chevron icon
            Icon(
              Icons.chevron_right,
              color: NovaColors.textTertiaryStatic,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (profile.avatarUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: profile.avatarUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          placeholder: (context, url) => CircleAvatar(
            radius: 24,
            backgroundColor: NovaColors.dividerLight,
            child: Text(
              _getInitials(profile.fullName),
              style: NovaTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: NovaColors.textSecondaryStatic,
              ),
            ),
          ),
          errorWidget: (context, url, error) => CircleAvatar(
            radius: 24,
            backgroundColor: NovaColors.dividerLight,
            child: Text(
              _getInitials(profile.fullName),
              style: NovaTextStyles.body.copyWith(
                fontWeight: FontWeight.w600,
                color: NovaColors.textSecondaryStatic,
              ),
            ),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: 24,
      backgroundColor: NovaColors.dividerLight,
      child: Text(
        _getInitials(profile.fullName),
        style: NovaTextStyles.body.copyWith(
          fontWeight: FontWeight.w600,
          color: NovaColors.textSecondaryStatic,
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
