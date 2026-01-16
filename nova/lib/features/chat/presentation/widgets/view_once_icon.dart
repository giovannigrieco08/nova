import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';

/// View-once icon for ephemeral photo messages.
///
/// Shows 2 states:
/// - Viewable: Solid white outline circle
/// - Not viewable: Dashed circle with high contrast color based on background
class ViewOnceIcon extends StatelessWidget {
  /// Whether the media can still be viewed
  final bool isViewable;

  /// Whether this is displayed on the current user's message (purple background)
  final bool isOwnMessage;

  /// Size of the icon
  final double size;

  const ViewOnceIcon({
    super.key,
    required this.isViewable,
    this.isOwnMessage = true,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    if (isViewable) {
      // Viewable: filled white circle
      return _buildFilledCircle(NovaColors.onPrimaryLight);
    } else {
      // Not viewable: dashed circle with high contrast color
      // Own message (purple bg): light color for contrast
      // Other message (light bg): dark gray for contrast
      final color = isOwnMessage
          ? NovaColors.onPrimaryLight.withValues(alpha: 0.7)
          : NovaColors.textSecondary(context);
      return _buildDashedCircle(color);
    }
  }

  /// Filled circle - for viewable photos
  Widget _buildFilledCircle(Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '1',
          style: TextStyle(
            color: NovaColors.textPrimaryLight.withValues(alpha: 0.8),
            fontSize: size * 0.5,
            fontWeight: FontWeight.w600,
            height: 1,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }

  /// Dashed circle - for photos that can no longer be viewed
  Widget _buildDashedCircle(Color color) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _DashedCirclePainter(
              color: color,
              strokeWidth: size * 0.08,
              dashCount: 12,
            ),
          ),
          Text(
            '1',
            style: TextStyle(
              color: color,
              fontSize: size * 0.5,
              fontWeight: FontWeight.w600,
              height: 1,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for drawing a dashed circle
class _DashedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  _DashedCirclePainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Calculate dash and gap angles
    final totalAngle = 2 * math.pi;
    final dashAngle = totalAngle / dashCount * 0.6; // 60% dash
    final gapAngle = totalAngle / dashCount * 0.4;  // 40% gap

    // Draw each dash
    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * (dashAngle + gapAngle) - math.pi / 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashCount != dashCount;
  }
}
