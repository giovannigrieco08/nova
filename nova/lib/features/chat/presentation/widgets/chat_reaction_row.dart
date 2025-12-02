import 'package:flutter/material.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Row of reaction chips below a message.
///
/// Displays emoji reactions with counts.
/// Highlights reactions from the current user.
/// Tappable to toggle reactions.
class ChatReactionRow extends StatelessWidget {
  final Map<String, int> reactionCounts;
  final Set<String> currentUserReactions;
  final void Function(String emoji)? onTap;

  const ChatReactionRow({
    super.key,
    required this.reactionCounts,
    required this.currentUserReactions,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Sort by count (highest first)
    final sortedEntries = reactionCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: NovaSpacing.xs,
      runSpacing: NovaSpacing.xs,
      children: sortedEntries.map((entry) {
        final emoji = entry.key;
        final count = entry.value;
        final isSelected = currentUserReactions.contains(emoji);

        return _ReactionChip(
          emoji: emoji,
          count: count,
          isSelected: isSelected,
          onTap: onTap != null ? () => onTap!(emoji) : null,
        );
      }).toList(),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  final String emoji;
  final int count;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ReactionChip({
    required this.emoji,
    required this.count,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.xs,
          vertical: NovaSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? NovaColors.primary(context).withOpacity(0.15)
              : NovaColors.card(context),
          borderRadius: BorderRadius.circular(NovaRadius.full),
          border: Border.all(
            color: isSelected
                ? NovaColors.primary(context).withOpacity(0.3)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 14),
            ),
            SizedBox(width: NovaSpacing.xxs),
            Text(
              count.toString(),
              style: NovaTypography.bodySmall.copyWith(
                color: isSelected
                    ? NovaColors.primary(context)
                    : NovaColors.textSecondary(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
