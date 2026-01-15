// Shared Widget: NovaBottomSheet
// Feature: 002-profile-setup (and reusable across features)
// Purpose: Platform-aware bottom sheet (glass on iOS, Material on Android)

import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_radius.dart';
import '../../core/widgets/nova_glass.dart';

/// Helper class for showing bottom sheets with platform-aware styling
/// - iOS: Glassmorphism effect (frosted glass)
/// - Android: Standard Material Design (solid background)
class NovaBottomSheet {
  /// Show modal bottom sheet with platform-aware styling
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
    final isIOS = Platform.isIOS;

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: isDismissible,
      enableDrag: true,
      // Transparent on iOS for glass effect, solid on Android
      backgroundColor: isIOS ? Colors.transparent : NovaColors.background(context),
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
          expand: false,
          builder: (context, scrollController) {
            final content = Column(
              children: [
                // Drag handle (if enabled)
                if (showDragHandle) _buildDragHandle(isIOS),

                // Content
                Expanded(
                  child: builder(context, scrollController),
                ),
              ],
            );

            // iOS: Use glass effect
            if (isIOS) {
              return NovaGlassCard(
                level: GlassLevel.medium,
                borderRadius: NovaRadius.xl,
                child: content,
              );
            }

            // Android: Use solid background
            return Container(
              decoration: BoxDecoration(
                color: NovaColors.background(context),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(NovaRadius.xl),
                ),
              ),
              child: content,
            );
          },
        );
      },
    );
  }

  /// Build drag handle bar (adapts to platform styling)
  static Widget _buildDragHandle(bool isIOS) {
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
              // Slightly more visible on iOS glass background
              color: isIOS
                  ? Colors.white.withValues(alpha: 0.6)
                  : NovaColors.textSecondary(context).withValues(alpha: 0.5),
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
              color: NovaColors.textSecondary(context).withValues(alpha: 0.2),
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
