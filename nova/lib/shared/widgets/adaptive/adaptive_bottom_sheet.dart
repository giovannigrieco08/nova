import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Platform-adaptive bottom sheet.
///
/// - iOS: [CupertinoModalPopup] or fullscreen modal
/// - Android: [showModalBottomSheet] with DraggableScrollableSheet
///
/// Example:
/// ```dart
/// AdaptiveBottomSheet.show(
///   context: context,
///   title: 'Options',
///   child: ListView(...),
/// )
/// ```
class AdaptiveBottomSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    bool fullScreen = false,
    String? title,
  }) {
    if (context.isIOS) {
      if (fullScreen) {
        // iOS: Fullscreen modal
        return Navigator.of(context).push<T>(
          CupertinoPageRoute(
            fullscreenDialog: true,
            builder: (context) => child,
          ),
        );
      }

      // iOS: CupertinoModalPopup
      return showCupertinoModalPopup<T>(
        context: context,
        builder: (context) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: NovaColors.backgroundPrimary(context),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(NovaRadius.xl),
            ),
          ),
          child: Column(
            children: [
              // Drag handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: NovaSpacing.m),
                width: 36,
                height: 5,
                decoration: BoxDecoration(
                  color: NovaColors.textTertiary(context),
                  borderRadius: BorderRadius.circular(NovaRadius.full),
                ),
              ),
              if (title != null) ...[
                Text(title, style: NovaTypography.h3),
                const Divider(),
              ],
              Expanded(child: child),
            ],
          ),
        ),
      );
    }

    // Android: Material bottom sheet
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: NovaColors.backgroundPrimary(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NovaRadius.xl),
        ),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: NovaSpacing.m),
              width: 36,
              height: 5,
              decoration: BoxDecoration(
                color: NovaColors.textTertiary(context),
                borderRadius: BorderRadius.circular(NovaRadius.full),
              ),
            ),
            if (title != null) ...[
              Text(title, style: NovaTypography.h3),
              const Divider(),
            ],
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [child],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
