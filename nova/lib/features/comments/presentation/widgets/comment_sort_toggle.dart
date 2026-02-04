import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/repositories/comments_repository_interface.dart';

/// CommentSortToggle Widget
///
/// Platform-adaptive toggle for comment sorting order.
///
/// **T098**: Platform-specific controls
///   - iOS: CupertinoSegmentedControl
///   - Android: Material 3 SegmentedButton
///
/// Sorting Options:
/// - Recenti (recent): created_at DESC (default)
/// - Popolari (popular): like_count DESC, created_at DESC
///
/// Usage:
/// ```dart
/// CommentSortToggle(
///   currentSort: CommentSortOrder.recent,
///   onSortChanged: (newSort) => handleSortChange(newSort),
///   isLoading: false,
/// )
/// ```
class CommentSortToggle extends StatelessWidget {
  final CommentSortOrder currentSort;
  final ValueChanged<CommentSortOrder> onSortChanged;
  final bool isLoading;

  const CommentSortToggle({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      child: Row(
        children: [
          // Sort icon
          Icon(
            Icons.sort,
            size: 18,
            color: NovaColors.textSecondaryLight,
          ),

          SizedBox(width: NovaSpacing.s),

          // Platform-specific toggle
          Expanded(
            child: Platform.isIOS
                ? _buildIOSToggle(context)
                : _buildAndroidToggle(context),
          ),

          // Loading indicator (T103)
          if (isLoading)
            Padding(
              padding: EdgeInsets.only(left: NovaSpacing.s),
              child: SizedBox(
                width: 16,
                height: 16,
                child: Platform.isIOS
                    ? const CupertinoActivityIndicator(radius: 8)
                    : const CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  /// Build iOS-style segmented control
  Widget _buildIOSToggle(BuildContext context) {
    return AbsorbPointer(
      absorbing: isLoading,
      child: Opacity(
        opacity: isLoading ? 0.5 : 1.0,
        child: CupertinoSlidingSegmentedControl<CommentSortOrder>(
          groupValue: currentSort,
          onValueChanged: (value) {
            if (value != null && !isLoading) {
              onSortChanged(value);
            }
          },
          thumbColor: CupertinoColors.white,
          backgroundColor: CupertinoColors.systemGrey5,
          children: {
            CommentSortOrder.recent: Padding(
              padding: EdgeInsets.symmetric(horizontal: NovaSpacing.m),
              child: Text(
                'Recenti',
                style: NovaTextStyles.bodyBold.copyWith(
                  fontSize: 13,
                  color: currentSort == CommentSortOrder.recent
                      ? NovaColors.primaryLight
                      : NovaColors.textSecondaryLight,
                ),
              ),
            ),
            CommentSortOrder.popular: Padding(
              padding: EdgeInsets.symmetric(horizontal: NovaSpacing.m),
              child: Text(
                'Popolari',
                style: NovaTextStyles.bodyBold.copyWith(
                  fontSize: 13,
                  color: currentSort == CommentSortOrder.popular
                      ? NovaColors.primaryLight
                      : NovaColors.textSecondaryLight,
                ),
              ),
            ),
          },
        ),
      ),
    );
  }

  /// Build Android-style segmented button (Material 3)
  Widget _buildAndroidToggle(BuildContext context) {
    return SegmentedButton<CommentSortOrder>(
      segments: const [
        ButtonSegment<CommentSortOrder>(
          value: CommentSortOrder.recent,
          label: Text('Recenti'),
          icon: Icon(Icons.access_time, size: 16),
        ),
        ButtonSegment<CommentSortOrder>(
          value: CommentSortOrder.popular,
          label: Text('Popolari'),
          icon: Icon(Icons.favorite, size: 16),
        ),
      ],
      selected: {currentSort},
      onSelectionChanged: isLoading
          ? null
          : (selected) {
              if (selected.isNotEmpty) {
                onSortChanged(selected.first);
              }
            },
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        textStyle: WidgetStateProperty.all(
          NovaTextStyles.bodyBold.copyWith(fontSize: 13),
        ),
      ),
    );
  }
}

/// Compact sort toggle for limited space
///
/// Uses simple text buttons with underline indicator
class CommentSortToggleCompact extends StatelessWidget {
  final CommentSortOrder currentSort;
  final ValueChanged<CommentSortOrder> onSortChanged;
  final bool isLoading;

  const CommentSortToggleCompact({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSortOption(
          context,
          CommentSortOrder.recent,
          'Recenti',
        ),
        SizedBox(width: NovaSpacing.m),
        _buildSortOption(
          context,
          CommentSortOrder.popular,
          'Popolari',
        ),
        if (isLoading) ...[
          SizedBox(width: NovaSpacing.s),
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: NovaColors.primaryLight,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSortOption(
    BuildContext context,
    CommentSortOrder sort,
    String label,
  ) {
    final isSelected = currentSort == sort;

    return GestureDetector(
      onTap: isLoading ? null : () => onSortChanged(sort),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.xs,
          vertical: NovaSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? NovaColors.primaryLight : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: NovaTextStyles.bodyBold.copyWith(
            fontSize: 13,
            color: isSelected
                ? NovaColors.primaryLight
                : NovaColors.textSecondaryLight,
          ),
        ),
      ),
    );
  }
}
