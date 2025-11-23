import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

/// EmptyCommentsState Widget
///
/// Displayed when no comments exist for an event.
/// Platform-adaptive design with centered content.
///
/// Layout:
/// - Icon: 💬 (chat bubble emoji or platform icon)
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
          padding: EdgeInsets.all(NovaSpacing.xxLarge),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              _buildIcon(context),

              SizedBox(height: NovaSpacing.medium),

              // Title
              Text(
                'Nessun commento ancora',
                style: NovaTypography.headingSmall.copyWith(
                  color: NovaColors.textSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),

              SizedBox(height: NovaSpacing.small),

              // Subtitle
              Text(
                'Sii il primo a commentare!',
                style: NovaTypography.bodyMedium.copyWith(
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

  /// Build platform-adaptive icon
  ///
  /// iOS: CupertinoIcons.chat_bubble_2
  /// Android: Icons.comment_outlined
  Widget _buildIcon(BuildContext context) {
    if (Platform.isIOS) {
      return Icon(
        CupertinoIcons.chat_bubble_2,
        size: 64,
        color: NovaColors.textTertiary(context),
      );
    } else {
      return Icon(
        Icons.comment_outlined,
        size: 64,
        color: NovaColors.textTertiary(context),
      );
    }
  }
}
