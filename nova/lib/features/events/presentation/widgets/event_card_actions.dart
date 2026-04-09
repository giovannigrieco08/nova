import 'package:flutter/material.dart';
import '../../../../core/animations/animated_like_button.dart';

/// Actions row: Like (animated) + Comment icons.
class EventCardActions extends StatelessWidget {
  final bool isLiked;
  final bool isProcessing;
  final VoidCallback? onLike;
  final VoidCallback onComment;

  const EventCardActions({
    super.key,
    required this.isLiked,
    required this.isProcessing,
    this.onLike,
    required this.onComment,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          AnimatedLikeButton(
            isLiked: isLiked,
            onTap: isProcessing ? null : onLike,
            size: 24,
          ),
          const SizedBox(width: 2),
          IconButton(
            icon: const Icon(Icons.mode_comment_outlined, size: 24),
            color: Colors.black,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: onComment,
            tooltip: 'Commenti',
          ),
        ],
      ),
    );
  }
}
