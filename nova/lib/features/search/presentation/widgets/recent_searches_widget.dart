/// Recent searches widget
///
/// Displays recent search queries as tappable chips.
/// Allows deletion of individual queries or clearing all history.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import '../providers/search_history_provider.dart';

/// Widget showing recent search queries as chips
class RecentSearchesWidget extends ConsumerWidget {
  final ValueChanged<String> onQuerySelected;
  final VoidCallback? onClearAll;

  const RecentSearchesWidget({
    super.key,
    required this.onQuerySelected,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(searchHistoryProvider);
    final notifier = ref.read(searchHistoryProvider.notifier);

    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.l,
            vertical: NovaSpacing.s,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ricerche recenti',
                style: NovaTextStyles.bodyBold.copyWith(
                  color: NovaColors.textPrimaryStatic,
                ),
              ),
              if (onClearAll != null)
                TextButton(
                  onPressed: () {
                    notifier.clearHistory();
                    onClearAll?.call();
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Cancella tutto',
                    style: NovaTextStyles.caption.copyWith(
                      color: NovaColors.primaryStatic,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Chips
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: NovaSpacing.l),
          child: Wrap(
            spacing: NovaSpacing.xs,
            runSpacing: NovaSpacing.xs,
            children: history.map((query) {
              return _SearchChip(
                query: query,
                onTap: () => onQuerySelected(query),
                onDelete: () => notifier.removeQuery(query),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: NovaSpacing.m),
      ],
    );
  }
}

/// Individual search chip with delete button
class _SearchChip extends StatelessWidget {
  final String query;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SearchChip({
    required this.query,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: NovaColors.surfaceLight,
      borderRadius: NovaRadius.circularM,
      child: InkWell(
        onTap: onTap,
        borderRadius: NovaRadius.circularM,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.m,
            vertical: NovaSpacing.xs,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: NovaColors.borderLight,
              width: 1,
            ),
            borderRadius: NovaRadius.circularM,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history,
                size: 16,
                color: NovaColors.textSecondaryStatic,
              ),
              const SizedBox(width: NovaSpacing.xs),
              Text(
                query,
                style: NovaTextStyles.caption.copyWith(
                  color: NovaColors.textPrimaryStatic,
                ),
              ),
              const SizedBox(width: NovaSpacing.xs),
              GestureDetector(
                onTap: onDelete,
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: NovaColors.textTertiaryStatic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
