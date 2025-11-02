// Widget: IncompleteProfileBanner
// Feature: 002-profile-setup
// Purpose: Reminder banner for users with incomplete profiles

import 'package:flutter/material.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';

/// Banner shown to users with incomplete profiles
///
/// Displays at top of Feed screen to remind users to complete their profile
/// Features:
/// - Dismissible (swipe to dismiss)
/// - Prominent warning color
/// - Clear CTA button
/// - Persistent until profile completed
class IncompleteProfileBanner extends StatelessWidget {
  final VoidCallback onCompleteProfile;
  final VoidCallback? onDismiss;

  const IncompleteProfileBanner({
    super.key,
    required this.onCompleteProfile,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: const Key('incomplete_profile_banner'),
      direction: onDismiss != null
          ? DismissDirection.horizontal
          : DismissDirection.none,
      onDismissed: (direction) {
        onDismiss?.call();
      },
      child: Container(
        margin: EdgeInsets.all(NovaSpacing.m),
        padding: EdgeInsets.all(NovaSpacing.l),
        decoration: BoxDecoration(
          color: NovaColors.warning(context).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(NovaRadius.l),
          border: Border.all(
            color: NovaColors.warning(context),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Warning icon
            Icon(
              Icons.info_outline,
              color: NovaColors.warning(context),
              size: 24,
            ),

            SizedBox(width: NovaSpacing.m),

            // Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Profilo incompleto',
                    style: NovaTextStyles.bodyBold.copyWith(
                      color: NovaColors.textPrimary(context),
                    ),
                  ),
                  SizedBox(height: NovaSpacing.xs),
                  Text(
                    'Completa il tuo profilo per usare tutte le funzioni',
                    style: NovaTextStyles.caption.copyWith(
                      color: NovaColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(width: NovaSpacing.m),

            // CTA button
            ElevatedButton(
              onPressed: onCompleteProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: NovaColors.primary(context),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.l,
                  vertical: NovaSpacing.s,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(NovaRadius.m),
                ),
              ),
              child: Text(
                'Completa',
                style: NovaTextStyles.button.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
