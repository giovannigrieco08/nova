// Shared Widget: ParticipantBadge
// Feature: 003-events-feed
// Purpose: Green checkmark badge indicating user participation

import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';

class ParticipantBadge extends StatelessWidget {
  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final bool showBorder;

  const ParticipantBadge({
    super.key,
    this.size = 20.0,
    this.backgroundColor = NovaColors.successLight, // Green
    this.iconColor = Colors.white,
    this.showBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        border: showBorder
            ? Border.all(
                color: Colors.white,
                width: 2,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Icon(
          Icons.check,
          color: iconColor,
          size: size * 0.65,
        ),
      ),
    );
  }
}

/// Participant badge overlay (for avatar stacks)
/// Shows checkmark on top-right of avatar
class ParticipantBadgeOverlay extends StatelessWidget {
  final Widget child; // Avatar widget
  final bool isParticipating; // Show badge?
  final double badgeSize;

  const ParticipantBadgeOverlay({
    super.key,
    required this.child,
    required this.isParticipating,
    this.badgeSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    if (!isParticipating) {
      return child;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -4,
          top: -4,
          child: ParticipantBadge(size: badgeSize),
        ),
      ],
    );
  }
}
