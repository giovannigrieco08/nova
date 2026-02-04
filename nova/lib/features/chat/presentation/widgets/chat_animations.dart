import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nova/core/theme/nova_colors.dart';

/// Animated heart that appears on double-tap (Instagram-style quick react)
class HeartPopAnimation extends StatefulWidget {
  final VoidCallback? onComplete;
  final Offset position;
  final Color? color;

  const HeartPopAnimation({
    super.key,
    this.onComplete,
    required this.position,
    this.color,
  });

  @override
  State<HeartPopAnimation> createState() => _HeartPopAnimationState();
}

class _HeartPopAnimationState extends State<HeartPopAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // Scale: 0 -> 1.4 -> 1.0 (overshoot effect)
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.4, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 25,
      ),
    ]).animate(_controller);

    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0),
        weight: 30,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      widget.onComplete?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 40,
      top: widget.position.dy - 40,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Icon(
                Icons.favorite,
                size: 80,
                color: widget.color ?? NovaColors.error(context),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Wrapper for message tiles with appear animation (slide + fade)
class AnimatedMessageTile extends StatefulWidget {
  final Widget child;
  final bool animate;
  final int index;

  const AnimatedMessageTile({
    super.key,
    required this.child,
    this.animate = true,
    this.index = 0,
  });

  @override
  State<AnimatedMessageTile> createState() => _AnimatedMessageTileState();
}

class _AnimatedMessageTileState extends State<AnimatedMessageTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    if (widget.animate) {
      // Stagger delay based on index (max 5 items)
      final delay = Duration(milliseconds: math.min(widget.index * 50, 250));
      Future.delayed(delay, () {
        if (mounted) {
          _controller.forward();
        }
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) {
      return widget.child;
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: widget.child,
      ),
    );
  }
}

/// Animated reaction chip with scale + bounce effect
class AnimatedReactionChip extends StatefulWidget {
  final Widget child;
  final bool isNew;

  const AnimatedReactionChip({
    super.key,
    required this.child,
    this.isNew = false,
  });

  @override
  State<AnimatedReactionChip> createState() => _AnimatedReactionChipState();
}

class _AnimatedReactionChipState extends State<AnimatedReactionChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.2)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_controller);

    if (widget.isNew) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}

/// Overlay manager for showing heart animations
class HeartAnimationOverlay {
  static OverlayEntry? _currentEntry;

  static void show(
    BuildContext context, {
    required Offset globalPosition,
    VoidCallback? onComplete,
  }) {
    // Haptic feedback
    HapticFeedback.mediumImpact();

    // Remove any existing animation
    _currentEntry?.remove();

    // Get overlay position relative to screen
    final overlayState = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder: (context) => HeartPopAnimation(
        position: globalPosition,
        onComplete: () {
          _currentEntry?.remove();
          _currentEntry = null;
          onComplete?.call();
        },
      ),
    );

    overlayState.insert(_currentEntry!);
  }
}

/// Send button animation (pulse on enabled)
class AnimatedSendButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback? onPressed;
  final Widget child;

  const AnimatedSendButton({
    super.key,
    required this.enabled,
    this.onPressed,
    required this.child,
  });

  @override
  State<AnimatedSendButton> createState() => _AnimatedSendButtonState();
}

class _AnimatedSendButtonState extends State<AnimatedSendButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(AnimatedSendButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !oldWidget.enabled) {
      _controller.forward().then((_) => _controller.reverse());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onPressed : null,
        child: widget.child,
      ),
    );
  }
}

/// Typing indicator with bouncing dots
class BouncingDotsIndicator extends StatefulWidget {
  final Color? color;
  final double dotSize;

  const BouncingDotsIndicator({
    super.key,
    this.color,
    this.dotSize = 8,
  });

  @override
  State<BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<BouncingDotsIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      3,
      (index) => AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      ),
    );

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0, end: -8).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    // Start animations with stagger
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 150), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dotColor = widget.color ?? NovaColors.textTertiary(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[index].value),
              child: Container(
                width: widget.dotSize,
                height: widget.dotSize,
                margin: EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

/// Message status indicator (sent/delivered/read)
class MessageStatusIndicator extends StatelessWidget {
  final MessageStatus status;
  final Color? color;

  const MessageStatusIndicator({
    super.key,
    required this.status,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? _getStatusColor(context);

    switch (status) {
      case MessageStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: iconColor,
          ),
        );
      case MessageStatus.sent:
        return Icon(
          Icons.check,
          size: 14,
          color: iconColor,
        );
      case MessageStatus.delivered:
        return Stack(
          children: [
            Icon(Icons.check, size: 14, color: iconColor),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.check, size: 14, color: iconColor),
            ),
          ],
        );
      case MessageStatus.read:
        return Stack(
          children: [
            Icon(Icons.check, size: 14, color: NovaColors.primary(context)),
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Icon(Icons.check,
                  size: 14, color: NovaColors.primary(context)),
            ),
          ],
        );
      case MessageStatus.failed:
        return Icon(
          Icons.error_outline,
          size: 14,
          color: NovaColors.error(context),
        );
    }
  }

  Color _getStatusColor(BuildContext context) {
    switch (status) {
      case MessageStatus.read:
        return NovaColors.primary(context);
      case MessageStatus.failed:
        return NovaColors.error(context);
      default:
        return NovaColors.textTertiary(context);
    }
  }
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}
