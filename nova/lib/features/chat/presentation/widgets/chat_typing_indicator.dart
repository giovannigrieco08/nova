import 'package:flutter/material.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/presentation/widgets/chat_animations.dart';

/// Shows who is currently typing in the chat.
///
/// Displayed above the compose bar.
/// Uses BouncingDotsIndicator for smooth, staggered animation (Instagram style).
class ChatTypingIndicator extends StatelessWidget {
  final String typingText;

  const ChatTypingIndicator({
    super.key,
    required this.typingText,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: NovaColors.card(context),
        border: Border(
          top: BorderSide(color: NovaColors.border(context)),
        ),
      ),
      child: Row(
        children: [
          // Bouncing dots indicator (Instagram style)
          BouncingDotsIndicator(
            color: NovaColors.textTertiary(context),
            dotSize: 6,
          ),
          SizedBox(width: NovaSpacing.s),

          // Typing text
          Expanded(
            child: Text(
              typingText,
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.textTertiary(context),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
