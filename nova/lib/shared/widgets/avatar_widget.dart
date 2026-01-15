import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Circular avatar widget with fallback to initials.
///
/// Displays:
/// - Network image from avatarUrl if available
/// - Colored circle with initials as fallback
class AvatarWidget extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;
  final Color? backgroundColor;

  const AvatarWidget({
    super.key,
    this.avatarUrl,
    required this.name,
    this.size = 40,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final initials = _getInitials(name);
    final bgColor = backgroundColor ?? _getColorFromName(name);

    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (context, url) => _buildInitialsFallback(
            initials,
            bgColor,
          ),
          errorWidget: (context, url, error) => _buildInitialsFallback(
            initials,
            bgColor,
          ),
        ),
      );
    }

    return _buildInitialsFallback(initials, bgColor);
  }

  Widget _buildInitialsFallback(String initials, Color bgColor) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: NovaTextStyles.caption.copyWith(
            color: NovaColors.onPrimaryLight,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.4,
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
    }
    return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
  }

  Color _getColorFromName(String name) {
    // Generate a consistent color based on name hash
    // Uses NovaColors.avatarColors for design system compliance
    final hash = name.hashCode;
    return NovaColors.avatarColors[hash.abs() % NovaColors.avatarColors.length];
  }
}
