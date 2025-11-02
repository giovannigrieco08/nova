// Shared Widget: NovaBottomSheet
// Feature: 002-profile-setup (and reusable across features)
// Purpose: DraggableScrollableSheet with glass effect and consistent styling

import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_radius.dart';
import '../../core/widgets/nova_glass.dart';

/// Helper class for showing bottom sheets with consistent styling
class NovaBottomSheet {
  /// Show modal bottom sheet with glass effect
  ///
  /// Parameters:
  /// - [context]: BuildContext
  /// - [builder]: Widget builder for sheet content
  /// - [initialChildSize]: Initial height as fraction of screen (default 0.7)
  /// - [minChildSize]: Minimum height when dragged down (default 0.3)
  /// - [maxChildSize]: Maximum height when dragged up (default 0.95)
  /// - [isDismissible]: Can be dismissed by tapping outside (default true)
  /// - [showDragHandle]: Show drag handle bar at top (default true)
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget Function(BuildContext, ScrollController) builder,
    double initialChildSize = 0.7,
    double minChildSize = 0.3,
    double maxChildSize = 0.95,
    bool isDismissible = true,
    bool showDragHandle = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NovaRadius.xl),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: initialChildSize,
          minChildSize: minChildSize,
          maxChildSize: maxChildSize,
          builder: (context, scrollController) {
            return NovaGlassCard(
              level: GlassLevel.medium,
              borderRadius: NovaRadius.xl,
              child: Column(
                children: [
                  // Drag handle (if enabled)
                  if (showDragHandle) _buildDragHandle(),

                  // Content
                  Expanded(
                    child: builder(context, scrollController),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Build drag handle bar
  static Widget _buildDragHandle() {
    return Builder(
      builder: (context) => Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: NovaSpacing.m,
          bottom: NovaSpacing.s,
        ),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: NovaColors.textSecondary(context).withOpacity(0.5),
              borderRadius: BorderRadius.circular(NovaRadius.s),
            ),
          ),
        ),
      ),
    );
  }

  /// Show simple bottom sheet with title and content
  ///
  /// Convenience method for common pattern: title + scrollable list
  static Future<T?> showWithTitle<T>({
    required BuildContext context,
    required String title,
    required Widget content,
    double initialChildSize = 0.7,
    double minChildSize = 0.3,
    double maxChildSize = 0.95,
    bool isDismissible = true,
  }) {
    return show<T>(
      context: context,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      isDismissible: isDismissible,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Title
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: NovaSpacing.xl,
                vertical: NovaSpacing.l,
              ),
              child: Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: NovaColors.textPrimary(context),
                    ),
              ),
            ),

            // Divider
            Divider(
              height: 1,
              color: NovaColors.textSecondary(context).withOpacity(0.2),
            ),

            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.all(NovaSpacing.xl),
                child: content,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Example usage:
/// ```dart
/// NovaBottomSheet.show(
///   context: context,
///   builder: (context, scrollController) {
///     return ListView(
///       controller: scrollController,
///       children: [
///         ListTile(title: Text('Item 1')),
///         ListTile(title: Text('Item 2')),
///       ],
///     );
///   },
/// );
///
/// // Or with title:
/// NovaBottomSheet.showWithTitle(
///   context: context,
///   title: 'Seleziona classe',
///   content: ClassPickerList(),
/// );
/// ```
