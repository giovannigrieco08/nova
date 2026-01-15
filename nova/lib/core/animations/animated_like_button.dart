import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/nova_colors.dart';

/// Instagram-style animated like button with bounce effect and haptic feedback.
///
/// Features:
/// - Scale bounce animation (1.0 → 1.4 → 0.9 → 1.0)
/// - Color transition animation
/// - Haptic feedback on tap
///
/// Usage:
/// ```dart
/// AnimatedLikeButton(
///   isLiked: _isLiked,
///   onTap: () => setState(() => _isLiked = !_isLiked),
/// )
/// ```
class AnimatedLikeButton extends StatefulWidget {
  /// Whether the item is currently liked.
  final bool isLiked;

  /// Callback when button is tapped.
  final VoidCallback? onTap;

  /// Size of the icon.
  final double size;

  /// Color when liked.
  final Color likedColor;

  /// Color when not liked.
  final Color unlikedColor;

  /// Whether to use outline icon when not liked.
  final bool useOutlineWhenUnliked;

  const AnimatedLikeButton({
    super.key,
    required this.isLiked,
    this.onTap,
    this.size = 24,
    this.likedColor = NovaColors.likeActive,
    this.unlikedColor = NovaColors.textPrimaryLight,
    this.useOutlineWhenUnliked = true,
  });

  @override
  State<AnimatedLikeButton> createState() => _AnimatedLikeButtonState();
}

class _AnimatedLikeButtonState extends State<AnimatedLikeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // Bounce effect: 1.0 → 1.4 → 0.9 → 1.0
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.4, end: 0.9)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(AnimatedLikeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Trigger animation when isLiked changes to true
    if (widget.isLiked && !oldWidget.isLiked) {
      _triggerAnimation();
    }
  }

  void _triggerAnimation() {
    _controller.forward(from: 0.0);
  }

  void _handleTap() {
    // Haptic feedback
    HapticFeedback.lightImpact();

    // Trigger animation if liking (not unliking)
    if (!widget.isLiked) {
      _triggerAnimation();
    }

    widget.onTap?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: Icon(
            widget.isLiked
                ? Icons.favorite
                : (widget.useOutlineWhenUnliked
                    ? Icons.favorite_border
                    : Icons.favorite),
            key: ValueKey(widget.isLiked),
            size: widget.size,
            color: widget.isLiked ? widget.likedColor : widget.unlikedColor,
          ),
        ),
      ),
    );
  }
}
