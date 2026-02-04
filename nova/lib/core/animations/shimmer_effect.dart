import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';

/// A shimmering gradient effect for loading placeholders.
///
/// Creates an animated gradient that sweeps across the child widget,
/// commonly used for skeleton loading states.
///
/// Usage:
/// ```dart
/// ShimmerEffect(
///   child: Container(
///     width: 200,
///     height: 20,
///     decoration: BoxDecoration(
///       color: NovaColors.cardLight,
///       borderRadius: BorderRadius.circular(4),
///     ),
///   ),
/// )
/// ```
class ShimmerEffect extends StatefulWidget {
  /// The widget to apply shimmer effect to.
  final Widget child;

  /// Base color of the shimmer (the darker color).
  final Color? baseColor;

  /// Highlight color of the shimmer (the lighter color that sweeps).
  final Color? highlightColor;

  /// Duration of one complete shimmer cycle.
  final Duration duration;

  /// Whether the shimmer is currently active.
  final bool enabled;

  /// Direction of the shimmer sweep.
  final ShimmerDirection direction;

  const ShimmerEffect({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
    this.duration = const Duration(milliseconds: 800),
    this.enabled = true,
    this.direction = ShimmerDirection.leftToRight,
  });

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _animation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(ShimmerEffect oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled != oldWidget.enabled) {
      if (widget.enabled) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    // Use simple opacity animation instead of expensive ShaderMask
    // ShaderMask recreates shader every frame = GPU killer
    // Opacity pulse achieves similar visual effect at fraction of cost
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        // Map animation value (-1.0 to 2.0) to opacity (0.3 to 0.7)
        final normalizedValue =
            ((_animation.value + 1.0) / 3.0).clamp(0.0, 1.0);
        final opacity = 0.3 + (normalizedValue * 0.4);
        return Opacity(
          opacity: opacity,
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Direction of shimmer animation sweep.
enum ShimmerDirection {
  leftToRight,
  rightToLeft,
  topToBottom,
  bottomToTop,
}

/// A rectangular shimmer placeholder with rounded corners.
///
/// Usage:
/// ```dart
/// ShimmerBox(width: 100, height: 20)
/// ShimmerBox.circle(size: 48)
/// ```
class ShimmerBox extends StatelessWidget {
  /// Width of the box.
  final double? width;

  /// Height of the box.
  final double height;

  /// Border radius of the box.
  final double borderRadius;

  /// Base color (defaults to theme-aware gray).
  final Color? baseColor;

  /// Highlight color (defaults to theme-aware light gray).
  final Color? highlightColor;

  const ShimmerBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 4,
    this.baseColor,
    this.highlightColor,
  });

  /// Creates a circular shimmer placeholder.
  const ShimmerBox.circle({
    super.key,
    required double size,
    this.baseColor,
    this.highlightColor,
  })  : width = size,
        height = size,
        borderRadius = size / 2;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final base =
        baseColor ?? (isDark ? NovaColors.cardDark : NovaColors.cardLight);

    return ShimmerEffect(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// A text line shimmer placeholder.
///
/// Simulates a line of text with appropriate height and random width.
class ShimmerText extends StatelessWidget {
  /// Width of the text line. If null, fills available space.
  final double? width;

  /// Fraction of available width (0.0 to 1.0). Used if width is null.
  final double widthFraction;

  /// Height of the text line.
  final double height;

  const ShimmerText({
    super.key,
    this.width,
    this.widthFraction = 1.0,
    this.height = 14,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveWidth = width ?? (constraints.maxWidth * widthFraction);
        return ShimmerBox(
          width: effectiveWidth,
          height: height,
          borderRadius: height / 2,
        );
      },
    );
  }
}

/// A card-like shimmer placeholder with multiple elements.
///
/// Common pattern for event/post loading states.
class ShimmerCard extends StatelessWidget {
  /// Whether to show an image placeholder at the top.
  final bool showImage;

  /// Aspect ratio of the image placeholder.
  final double imageAspectRatio;

  /// Number of text lines to show.
  final int textLines;

  /// Whether to show an avatar/icon placeholder.
  final bool showAvatar;

  const ShimmerCard({
    super.key,
    this.showImage = true,
    this.imageAspectRatio = 1.0,
    this.textLines = 2,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with avatar
        if (showAvatar)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const ShimmerBox.circle(size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      ShimmerText(widthFraction: 0.4, height: 14),
                      SizedBox(height: 4),
                      ShimmerText(widthFraction: 0.25, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Image placeholder
        if (showImage)
          AspectRatio(
            aspectRatio: imageAspectRatio,
            child: ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 0,
            ),
          ),

        // Text content
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(textLines, (index) {
              final isLast = index == textLines - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                child: ShimmerText(
                  widthFraction: isLast ? 0.6 : 1.0,
                  height: 14,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
