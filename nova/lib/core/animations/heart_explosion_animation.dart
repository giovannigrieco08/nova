import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nova/core/theme/nova_colors.dart';

/// Instagram-style heart explosion animation for double-tap like.
///
/// Usage:
/// ```dart
/// HeartExplosionAnimation(
///   show: _showHeart,
///   onComplete: () => setState(() => _showHeart = false),
/// )
/// ```
class HeartExplosionAnimation extends StatefulWidget {
  /// Whether to show and trigger the animation.
  final bool show;

  /// Callback when animation completes.
  final VoidCallback? onComplete;

  /// Size of the heart icon.
  final double size;

  /// Color of the heart.
  final Color color;

  const HeartExplosionAnimation({
    super.key,
    required this.show,
    this.onComplete,
    this.size = 100,
    this.color = NovaColors.likeActive, // Instagram red
  });

  @override
  State<HeartExplosionAnimation> createState() =>
      _HeartExplosionAnimationState();
}

class _HeartExplosionAnimationState extends State<HeartExplosionAnimation>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Scale animation: 0 -> 1.3 -> 1.0 (bounce effect)
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 40,
      ),
    ]).animate(_scaleController);

    // Fade animation: starts after scale, fades out
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0)
        .chain(CurveTween(curve: Curves.easeIn))
        .animate(_fadeController);

    // Listen for animation completion
    _scaleController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        // Wait a bit then fade out
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) {
            _fadeController.forward();
          }
        });
      }
    });

    _fadeController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete?.call();
        _reset();
      }
    });
  }

  @override
  void didUpdateWidget(HeartExplosionAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !oldWidget.show) {
      _triggerAnimation();
    }
  }

  void _triggerAnimation() {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Reset and play
    _reset();
    _scaleController.forward();
  }

  void _reset() {
    _scaleController.reset();
    _fadeController.reset();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show && _scaleController.value == 0) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: Listenable.merge([_scaleAnimation, _fadeAnimation]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Icon(
        Icons.favorite,
        size: widget.size,
        color: widget.color,
        shadows: [
          Shadow(
            color: NovaColors.textPrimaryLight.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
    );
  }
}

/// A wrapper widget that detects double-tap and shows heart animation.
///
/// Usage:
/// ```dart
/// DoubleTapLikeOverlay(
///   onDoubleTap: _handleLike,
///   child: Image.network(imageUrl),
/// )
/// ```
class DoubleTapLikeOverlay extends StatefulWidget {
  /// The child widget to wrap (usually an image).
  final Widget child;

  /// Callback when double-tapped.
  final VoidCallback? onDoubleTap;

  /// Single tap callback (optional).
  final VoidCallback? onTap;

  /// Heart animation size.
  final double heartSize;

  /// Heart animation color.
  final Color heartColor;

  const DoubleTapLikeOverlay({
    super.key,
    required this.child,
    this.onDoubleTap,
    this.onTap,
    this.heartSize = 100,
    this.heartColor = NovaColors.likeActive,
  });

  @override
  State<DoubleTapLikeOverlay> createState() => _DoubleTapLikeOverlayState();
}

class _DoubleTapLikeOverlayState extends State<DoubleTapLikeOverlay> {
  bool _showHeart = false;

  void _handleDoubleTap() {
    setState(() {
      _showHeart = true;
    });
    widget.onDoubleTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      onTap: widget.onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          widget.child,
          HeartExplosionAnimation(
            show: _showHeart,
            size: widget.heartSize,
            color: widget.heartColor,
            onComplete: () {
              setState(() {
                _showHeart = false;
              });
            },
          ),
        ],
      ),
    );
  }
}
