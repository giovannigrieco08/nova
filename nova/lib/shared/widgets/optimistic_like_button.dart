// Shared Widget: OptimisticLikeButton
// Feature: 003-events-feed
// Purpose: Like button with optimistic UI (<200ms response time)

import 'package:flutter/material.dart';

class OptimisticLikeButton extends StatefulWidget {
  final bool isLiked; // Initial like state
  final int likeCount; // Current like count
  final VoidCallback onLike; // Callback when user taps like
  final VoidCallback onUnlike; // Callback when user taps unlike
  final bool isLoading; // Show loading indicator (for error rollback)
  final double iconSize; // Size of heart icon
  final bool showCount; // Show like count next to icon

  const OptimisticLikeButton({
    super.key,
    required this.isLiked,
    required this.likeCount,
    required this.onLike,
    required this.onUnlike,
    this.isLoading = false,
    this.iconSize = 24.0,
    this.showCount = true,
  });

  @override
  State<OptimisticLikeButton> createState() => _OptimisticLikeButtonState();
}

class _OptimisticLikeButtonState extends State<OptimisticLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Animation for heart scale effect (bounce on tap)
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Play bounce animation
    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    // Execute optimistic action (instant UI update)
    if (widget.isLiked) {
      widget.onUnlike();
    } else {
      widget.onLike();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.isLoading ? null : _handleTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated heart icon
          ScaleTransition(
            scale: _scaleAnimation,
            child: Icon(
              widget.isLiked ? Icons.favorite : Icons.favorite_border,
              color: widget.isLiked ? Colors.red : Colors.grey[600],
              size: widget.iconSize,
            ),
          ),

          // Like count (if enabled)
          if (widget.showCount) ...[
            const SizedBox(width: 4),
            Text(
              _formatCount(widget.likeCount),
              style: TextStyle(
                fontSize: widget.iconSize * 0.6,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // Loading indicator (shown during error rollback)
          if (widget.isLoading) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: widget.iconSize * 0.6,
              height: widget.iconSize * 0.6,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.grey[400],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Format like count (1234 -> "1.2K", 1234567 -> "1.2M")
  String _formatCount(int count) {
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
}
