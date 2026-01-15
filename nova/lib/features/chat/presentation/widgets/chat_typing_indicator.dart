import 'package:flutter/material.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Shows who is currently typing in the chat.
///
/// Displayed above the compose bar.
/// Animated dots indicate typing activity.
class ChatTypingIndicator extends StatefulWidget {
  final String typingText;

  const ChatTypingIndicator({
    super.key,
    required this.typingText,
  });

  @override
  State<ChatTypingIndicator> createState() => _ChatTypingIndicatorState();
}

class _ChatTypingIndicatorState extends State<ChatTypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
          // Animated dots
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (index) {
                  final delay = index * 0.2;
                  final animation =
                      Tween<double>(begin: 0, end: 1).animate(
                    CurvedAnimation(
                      parent: _controller,
                      curve: Interval(delay, delay + 0.4, curve: Curves.easeInOut),
                    ),
                  );

                  return Padding(
                    padding: const EdgeInsets.only(right: 2),
                    child: Transform.translate(
                      offset: Offset(0, -4 * animation.value),
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: NovaColors.textTertiary(context),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          SizedBox(width: NovaSpacing.s),

          // Typing text
          Expanded(
            child: Text(
              widget.typingText,
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
