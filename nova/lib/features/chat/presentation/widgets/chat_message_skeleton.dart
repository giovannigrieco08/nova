import 'package:flutter/material.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';

/// Skeleton placeholder for chat messages during loading.
///
/// Mimics the layout of ChatMessageTile with shimmer effect.
class ChatMessageSkeleton extends StatelessWidget {
  final bool isOwnMessage;
  final bool showAvatar;

  const ChatMessageSkeleton({
    super.key,
    this.isOwnMessage = false,
    this.showAvatar = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: 3,
      ),
      child: Row(
        mainAxisAlignment:
            isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar placeholder (only for others' messages)
          if (!isOwnMessage && showAvatar) ...[
            _SkeletonBox(
              width: 28,
              height: 28,
              borderRadius: 14,
            ),
            SizedBox(width: NovaSpacing.xs),
          ],

          // Message bubble placeholder
          Column(
            crossAxisAlignment: isOwnMessage
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              _SkeletonBox(
                width: _getRandomWidth(),
                height: 36,
                borderRadius: 20,
                color: isOwnMessage
                    ? NovaColors.primary(context).withOpacity(0.3)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _getRandomWidth() {
    // Vary widths to look more natural
    final widths = [120.0, 180.0, 220.0, 160.0, 200.0];
    final index = hashCode % widths.length;
    return widths[index];
  }
}

/// Loading skeleton for entire chat message list.
///
/// Shows multiple skeleton messages to indicate loading.
class ChatMessageListSkeleton extends StatelessWidget {
  const ChatMessageListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      reverse: true,
      padding: EdgeInsets.symmetric(vertical: NovaSpacing.m),
      itemCount: 8,
      itemBuilder: (context, index) {
        // Alternate between own and others' messages
        final isOwn = index % 3 == 0;
        return ChatMessageSkeleton(
          key: ValueKey('skeleton_$index'),
          isOwnMessage: isOwn,
          showAvatar: !isOwn,
        );
      },
    );
  }
}

/// Generic skeleton box with shimmer animation.
class _SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;
  final Color? color;

  const _SkeletonBox({
    required this.width,
    required this.height,
    this.borderRadius = 4,
    this.color,
  });

  @override
  State<_SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<_SkeletonBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: widget.color ??
                NovaColors.card(context).withOpacity(_animation.value),
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        );
      },
    );
  }
}
