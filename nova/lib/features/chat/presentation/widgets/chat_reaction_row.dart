import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Row of reaction chips below a message.
///
/// Displays emoji reactions with counts.
/// Highlights reactions from the current user.
/// Tappable to toggle reactions with haptic feedback.
/// Long-press to see who reacted.
/// Animated scale + bounce on add/remove.
class ChatReactionRow extends StatefulWidget {
  final String messageId;
  final Map<String, int> reactionCounts;
  final Set<String> currentUserReactions;
  final void Function(String emoji)? onTap;
  final VoidCallback? onLongPress;

  const ChatReactionRow({
    super.key,
    required this.messageId,
    required this.reactionCounts,
    required this.currentUserReactions,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<ChatReactionRow> createState() => _ChatReactionRowState();
}

class _ChatReactionRowState extends State<ChatReactionRow> {
  Set<String> _previousReactions = {};

  @override
  void initState() {
    super.initState();
    _previousReactions = Set.from(widget.currentUserReactions);
  }

  @override
  void didUpdateWidget(ChatReactionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update previous reactions for next comparison
    _previousReactions = Set.from(oldWidget.currentUserReactions);
  }

  @override
  Widget build(BuildContext context) {
    // Sort by count (highest first)
    final sortedEntries = widget.reactionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: NovaSpacing.xs,
      runSpacing: NovaSpacing.xs,
      children: sortedEntries.map((entry) {
        final emoji = entry.key;
        final count = entry.value;
        final isSelected = widget.currentUserReactions.contains(emoji);

        // Check if this is a newly added reaction by current user
        final wasSelected = _previousReactions.contains(emoji);
        final isNewlyAdded = isSelected && !wasSelected;

        return _ReactionChip(
          key: ValueKey('${widget.messageId}_$emoji'),
          emoji: emoji,
          count: count,
          isSelected: isSelected,
          animateIn: isNewlyAdded,
          onTap: widget.onTap != null
              ? () {
                  HapticFeedback.lightImpact();
                  widget.onTap!(emoji);
                }
              : null,
          onLongPress: widget.onLongPress,
        );
      }).toList(),
    );
  }
}

class _ReactionChip extends StatefulWidget {
  final String emoji;
  final int count;
  final bool isSelected;
  final bool animateIn;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _ReactionChip({
    super.key,
    required this.emoji,
    required this.count,
    required this.isSelected,
    this.animateIn = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<_ReactionChip> createState() => _ReactionChipState();
}

class _ReactionChipState extends State<_ReactionChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 0.9)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.elasticOut)),
        weight: 25,
      ),
    ]).animate(_controller);

    _bounceAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    if (widget.animateIn) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_ReactionChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateIn && !oldWidget.animateIn) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.animateIn ? _scaleAnimation.value : 1.0,
          child: child,
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.xs,
            vertical: NovaSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? NovaColors.primary(context).withValues(alpha: 0.15)
                : NovaColors.card(context),
            borderRadius: BorderRadius.circular(NovaRadius.full),
            border: Border.all(
              color: widget.isSelected
                  ? NovaColors.primary(context).withValues(alpha: 0.3)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.emoji,
                style: TextStyle(
                  fontSize: 14,
                  decoration: TextDecoration.none,
                  // Explicit color to ensure visibility regardless of inherited styles
                  color: NovaColors.textPrimary(context),
                ),
              ),
              SizedBox(width: NovaSpacing.xxs),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: NovaTypography.bodySmall.copyWith(
                  color: widget.isSelected
                      ? NovaColors.primary(context)
                      : NovaColors.textSecondary(context),
                  fontWeight:
                      widget.isSelected ? FontWeight.w600 : FontWeight.normal,
                  decoration: TextDecoration.none,
                ),
                child: Text(widget.count.toString()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
