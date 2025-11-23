import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../providers/comment_likes_notifier.dart';

/// LikeButton Widget
///
/// Animated heart button for liking comments with optimistic UI.
/// Platform-adaptive: filled heart (liked) vs outlined heart (not liked).
///
/// Features:
/// - Pop scale animation on like (1.0 → 1.3 → 1.0 over 300ms)
/// - Color transition: gray (not liked) → purple Nova brand (liked)
/// - Like count display (abbreviated as "1K+" for >999)
/// - Optimistic UI (<200ms perceived response time)
/// - Error handling with automatic rollback
///
/// **FR-028**: Students can like/unlike comments instantly
/// **FR-029**: Like count visible to all users
///
/// Usage:
/// ```dart
/// LikeButton(
///   commentId: comment.id,
///   initialLikeCount: comment.likeCount,
///   initialIsLiked: comment.isLikedByCurrentUser,
/// )
/// ```
class LikeButton extends ConsumerStatefulWidget {
  final String commentId;
  final int initialLikeCount;
  final bool initialIsLiked;

  const LikeButton({
    super.key,
    required this.commentId,
    required this.initialLikeCount,
    required this.initialIsLiked,
  });

  @override
  ConsumerState<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends ConsumerState<LikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller for pop effect
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Scale animation: 1.0 → 1.3 → 1.0 (pop effect)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 50,
      ),
    ]).animate(_animationController);

    // Initialize likes notifier with comment data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(commentLikesNotifierProvider(widget.commentId).notifier)
          .initialize(
            isLiked: widget.initialIsLiked,
            likeCount: widget.initialLikeCount,
          );
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final likesState = ref.watch(commentLikesNotifierProvider(widget.commentId));
    final likesNotifier =
        ref.read(commentLikesNotifierProvider(widget.commentId).notifier);

    // T050: Show error toast when like/unlike fails
    ref.listen<CommentLikesState>(
      commentLikesNotifierProvider(widget.commentId),
      (previous, next) {
        if (next.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(next.error!),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {
                  likesNotifier.clearError();
                },
              ),
            ),
          );
          // Clear error after showing
          Future.delayed(const Duration(seconds: 4), () {
            likesNotifier.clearError();
          });
        }
      },
    );

    return Semantics(
      button: true,
      label: likesState.isLiked
          ? 'Rimuovi mi piace, ${_formatLikeCount(likesState.likeCount)} mi piace'
          : 'Aggiungi mi piace, ${_formatLikeCount(likesState.likeCount)} mi piace',
      enabled: !likesState.isProcessing,
      child: GestureDetector(
        onTap: likesState.isProcessing ? null : () => _handleLike(likesNotifier),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated heart icon
            AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Icon(
                    likesState.isLiked
                        ? (Platform.isIOS ? CupertinoIcons.heart_fill : Icons.favorite)
                        : (Platform.isIOS
                            ? CupertinoIcons.heart
                            : Icons.favorite_border),
                    size: 20,
                    color: likesState.isLiked
                        ? NovaColors.primary // Purple Nova brand color
                        : NovaColors.textTertiaryLight, // Gray when not liked
                  ),
                );
              },
            ),

            // Like count (if > 0)
            if (likesState.likeCount > 0) ...[
              SizedBox(width: NovaSpacing.tiny),
              Text(
                _formatLikeCount(likesState.likeCount),
                style: NovaTypography.labelSmall.copyWith(
                  color: likesState.isLiked
                      ? NovaColors.primary
                      : NovaColors.textTertiaryLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Handle like button tap
  ///
  /// Triggers pop animation and calls toggleLike on notifier.
  void _handleLike(CommentLikesNotifier notifier) {
    // Play pop animation (only when liking, not unliking)
    final currentState = ref.read(commentLikesNotifierProvider(widget.commentId));
    if (!currentState.isLiked) {
      _animationController.forward(from: 0.0);
    }

    // Toggle like with optimistic UI
    notifier.toggleLike();
  }

  /// Format like count for display
  ///
  /// Abbreviates counts >999 as "1K+", "10K+", etc.
  String _formatLikeCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 10000) {
      // 1K - 9.9K
      final k = (count / 1000).toStringAsFixed(1);
      return '${k}K';
    } else {
      // 10K+
      final k = (count / 1000).floor();
      return '${k}K+';
    }
  }
}
