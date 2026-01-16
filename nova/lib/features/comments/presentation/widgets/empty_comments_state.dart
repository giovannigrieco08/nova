import 'package:flutter/material.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

/// EmptyCommentsState Widget
///
/// Displayed when no comments exist for an event.
/// Platform-adaptive design with centered content.
///
/// Layout:
/// - Icon: chat bubble (Material Icons)
/// - Title: "Nessun commento ancora"
/// - Subtitle: "Sii il primo a commentare!"
///
/// Constitutional Principle 6 (DESIGN_SYSTEM_STRICT):
/// - All colors from NovaColors
/// - All spacing from NovaSpacing
/// - All typography from NovaTypography
class EmptyCommentsState extends StatelessWidget {
  const EmptyCommentsState({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Nessun commento ancora, sii il primo a commentare',
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(NovaSpacing.xxl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon - using Material Icons for cross-platform compatibility
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 64,
                color: NovaColors.textTertiary(context),
              ),

              SizedBox(height: NovaSpacing.m),

              // Title
              Text(
                'Nessun commento ancora',
                style: NovaTextStyles.h3.copyWith(
                  color: NovaColors.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: NovaSpacing.s),

              // Subtitle
              Text(
                'Sii il primo a commentare!',
                style: NovaTextStyles.body.copyWith(
                  color: NovaColors.textTertiary(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
