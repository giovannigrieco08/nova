// Widget: AvatarInitials
// Feature: 002-profile-setup
// Purpose: Colored initials fallback for avatars

import 'package:flutter/material.dart';
import '../../../../core/utils/avatar_initials_generator.dart';
import '../../../../core/theme/nova_shadows.dart';

/// Colored initials avatar fallback
///
/// Displays user's initials in a colored circle
/// Uses deterministic Material Design 500 colors based on first letter
/// Example: "Giovanni Rossi" → "GR" on red background
class AvatarInitials extends StatelessWidget {
  final String fullName;
  final double size;

  const AvatarInitials({
    super.key,
    required this.fullName,
    this.size = 150.0,
  });

  @override
  Widget build(BuildContext context) {
    final initials = AvatarInitialsGenerator.getInitials(fullName);
    final color = AvatarInitialsGenerator.getColor(fullName);

    // Calculate font size (32% of avatar size)
    final fontSize = size * 0.32;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: NovaShadows.small,
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }
}
