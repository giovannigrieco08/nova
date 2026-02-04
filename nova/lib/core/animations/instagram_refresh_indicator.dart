// Instagram-style refresh indicator
// Creates a spinning "snowflake" indicator like Instagram's pull-to-refresh

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';

/// Instagram-style spinning refresh indicator
/// Shows a rotating pattern of lines radiating from center
class InstagramRefreshIndicator extends StatefulWidget {
  /// Size of the indicator
  final double size;

  /// Whether the indicator is currently active (spinning)
  final bool isRefreshing;

  /// Pull progress (0.0 to 1.0) for pull-to-refresh animation
  final double pullProgress;

  const InstagramRefreshIndicator({
    super.key,
    this.size = 24,
    this.isRefreshing = false,
    this.pullProgress = 0.0,
  });

  @override
  State<InstagramRefreshIndicator> createState() =>
      _InstagramRefreshIndicatorState();
}

class _InstagramRefreshIndicatorState extends State<InstagramRefreshIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    if (widget.isRefreshing) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(InstagramRefreshIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isRefreshing && !oldWidget.isRefreshing) {
      _controller.repeat();
    } else if (!widget.isRefreshing && oldWidget.isRefreshing) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate opacity based on pull progress or refreshing state
    final opacity =
        widget.isRefreshing ? 1.0 : widget.pullProgress.clamp(0.0, 1.0);

    if (opacity == 0) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final rotation = widget.isRefreshing
            ? _controller.value * 2 * math.pi
            : widget.pullProgress * math.pi; // Partial rotation on pull

        return Opacity(
          opacity: opacity,
          child: Transform.rotate(
            angle: rotation,
            child: CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _InstagramSpinnerPainter(
                color: NovaColors.textSecondary(context),
                progress: widget.isRefreshing ? 1.0 : widget.pullProgress,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Custom painter for Instagram-style spinner (8 lines radiating from center)
class _InstagramSpinnerPainter extends CustomPainter {
  final Color color;
  final double progress;

  _InstagramSpinnerPainter({
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Number of lines (like Instagram's snowflake pattern)
    const lineCount = 8;
    final angleStep = (2 * math.pi) / lineCount;

    for (int i = 0; i < lineCount; i++) {
      // Vary opacity for each line (creates the gradient effect)
      final lineOpacity =
          (0.3 + (0.7 * ((lineCount - i) / lineCount))).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = color.withValues(alpha: lineOpacity * progress)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      final angle = i * angleStep - math.pi / 2; // Start from top

      // Inner point (gap from center)
      final innerRadius = radius * 0.25;
      final innerPoint = Offset(
        center.dx + innerRadius * math.cos(angle),
        center.dy + innerRadius * math.sin(angle),
      );

      // Outer point
      final outerRadius = radius * 0.85;
      final outerPoint = Offset(
        center.dx + outerRadius * math.cos(angle),
        center.dy + outerRadius * math.sin(angle),
      );

      canvas.drawLine(innerPoint, outerPoint, paint);
    }
  }

  @override
  bool shouldRepaint(_InstagramSpinnerPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}

/// Custom RefreshIndicator that shows Instagram-style spinner
/// Use this as a wrapper around scrollable content
class InstagramRefreshWrapper extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  /// Optional: Callback to track refresh state externally
  final ValueChanged<bool>? onRefreshStateChanged;

  const InstagramRefreshWrapper({
    super.key,
    required this.child,
    required this.onRefresh,
    this.onRefreshStateChanged,
  });

  @override
  State<InstagramRefreshWrapper> createState() =>
      _InstagramRefreshWrapperState();
}

class _InstagramRefreshWrapperState extends State<InstagramRefreshWrapper> {
  bool _isRefreshing = false;
  double _pullProgress = 0.0;

  static const double _refreshTriggerDistance = 80.0;
  static const double _indicatorOffset = 60.0;

  Future<void> _handleRefresh() async {
    setState(() {
      _isRefreshing = true;
    });
    widget.onRefreshStateChanged?.call(true);

    try {
      await widget.onRefresh();
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
          _pullProgress = 0.0;
        });
        widget.onRefreshStateChanged?.call(false);
      }
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (_isRefreshing) return false;

    if (notification is ScrollUpdateNotification) {
      if (notification.metrics.pixels < 0) {
        // Pulling down (overscroll)
        final overscroll = -notification.metrics.pixels;
        setState(() {
          _pullProgress =
              (overscroll / _refreshTriggerDistance).clamp(0.0, 1.0);
        });
      } else if (_pullProgress > 0) {
        setState(() {
          _pullProgress = 0.0;
        });
      }
    } else if (notification is ScrollEndNotification) {
      if (_pullProgress >= 1.0) {
        // Trigger refresh
        _handleRefresh();
      } else if (_pullProgress > 0) {
        // Reset if not pulled enough
        setState(() {
          _pullProgress = 0.0;
        });
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: Stack(
        children: [
          widget.child,

          // Instagram-style indicator (positioned below app bar)
          if (_isRefreshing || _pullProgress > 0)
            Positioned(
              top: _indicatorOffset -
                  (_pullProgress * 20), // Slight bounce effect
              left: 0,
              right: 0,
              child: Center(
                child: InstagramRefreshIndicator(
                  size: 24,
                  isRefreshing: _isRefreshing,
                  pullProgress: _pullProgress,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
