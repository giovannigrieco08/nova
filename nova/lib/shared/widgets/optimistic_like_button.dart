// Shared Widget: OptimisticLikeButton (Simplified)
// Feature: 003-events-feed
// Purpose: Like button using native IconButton (Instagram-style)

import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';

/// Simplified like button using native Flutter IconButton
///
/// Replaced custom animations with native Material touch feedback
/// for better performance and consistency with Instagram-style design
class OptimisticLikeButton extends StatelessWidget {
  final bool isLiked;
  final VoidCallback onLike;
  final VoidCallback onUnlike;
  final double iconSize;
  final Color? activeColor;
  final Color? inactiveColor;

  const OptimisticLikeButton({
    super.key,
    required this.isLiked,
    required this.onLike,
    required this.onUnlike,
    this.iconSize = 24.0,
    this.activeColor,
    this.inactiveColor,
  });

  void _handleTap() {
    if (isLiked) {
      onUnlike();
    } else {
      onLike();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        isLiked ? Icons.favorite : Icons.favorite_border,
        size: iconSize,
      ),
      color: isLiked
        ? (activeColor ?? NovaColors.instagramRed) // Instagram red
        : (inactiveColor ?? Colors.black), // Black
      onPressed: _handleTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
    );
  }
}

/// Utility function to format like counts
/// Examples: 1234 -> "1.2K", 1234567 -> "1.2M"
String formatLikeCount(int count) {
  if (count < 1000) {
    return count.toString();
  } else if (count < 1000000) {
    final k = (count / 1000).toStringAsFixed(1);
    // Remove trailing .0
    return k.endsWith('.0') ? '${k.substring(0, k.length - 2)}K' : '${k}K';
  } else {
    final m = (count / 1000000).toStringAsFixed(1);
    return m.endsWith('.0') ? '${m.substring(0, m.length - 2)}M' : '${m}M';
  }
}
