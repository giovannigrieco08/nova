// Widget: ModeratorBadge
// Feature: 006-user-profile (User Story 5 - T082)
// Purpose: Visual badge for moderators (transparency + community trust)

import 'package:flutter/material.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';

/// Moderator badge widget ("Moderatore 🛡️")
///
/// **Design**:
/// - Badge text: "Moderatore 🛡️" (shield emoji for trust)
/// - Color: NovaColors.brandViolet (purple brand color)
/// - Padding: 4×8px (compact)
/// - Border radius: NovaRadius.small (standard)
/// - Font: NovaTypography.bodySmall with semi-bold weight
///
/// **Philosophy** (from Constitution):
/// - Transparency: Moderators are publicly visible to build community trust
/// - No power hiding: Students know who reviews their content
/// - Accountability: Moderator badge = responsibility, not status symbol
///
/// **Usage**:
/// ```dart
/// // In ProfileHeader widget
/// if (profile.isModerator) {
///   ModeratorBadge(),
/// }
/// ```
class ModeratorBadge extends StatelessWidget {
  const ModeratorBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.small,
        vertical: NovaSpacing.xsmall,
      ),
      decoration: BoxDecoration(
        color: NovaColors.brandViolet.withOpacity(0.1), // Subtle background
        borderRadius: BorderRadius.circular(NovaRadius.small),
        border: Border.all(
          color: NovaColors.brandViolet,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Moderatore',
            style: NovaTypography.bodySmall.copyWith(
              color: NovaColors.brandViolet,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '🛡️',
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
