import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';

/// Dialog action configuration
class AdaptiveDialogAction {
  /// Action text
  final String text;

  /// Tap callback
  final VoidCallback onPressed;

  /// iOS only: Mark as default action (bold)
  final bool isDefaultAction;

  /// Mark as destructive action (red)
  final bool isDestructiveAction;

  const AdaptiveDialogAction({
    required this.text,
    required this.onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
  });
}

/// Platform-adaptive dialog.
///
/// - iOS: [CupertinoAlertDialog]
/// - Android: [AlertDialog] Material
///
/// Example:
/// ```dart
/// AdaptiveDialog.show(
///   context: context,
///   title: 'Delete Event',
///   content: 'Are you sure?',
///   actions: [
///     AdaptiveDialogAction(
///       text: 'Cancel',
///       onPressed: () {},
///     ),
///     AdaptiveDialogAction(
///       text: 'Delete',
///       isDestructiveAction: true,
///       onPressed: () => _deleteEvent(),
///     ),
///   ],
/// )
/// ```
class AdaptiveDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? content,
    required List<AdaptiveDialogAction> actions,
  }) {
    if (context.isIOS) {
      // iOS: CupertinoAlertDialog
      return showCupertinoDialog<T>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: Text(title),
          content: content != null ? Text(content) : null,
          actions: actions.map((action) {
            return CupertinoDialogAction(
              onPressed: () {
                Navigator.of(context).pop();
                action.onPressed();
              },
              isDefaultAction: action.isDefaultAction,
              isDestructiveAction: action.isDestructiveAction,
              child: Text(action.text),
            );
          }).toList(),
        ),
      );
    }

    // Android: Material AlertDialog
    return showDialog<T>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: content != null ? Text(content) : null,
        actions: actions.map((action) {
          return TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              action.onPressed();
            },
            style: action.isDestructiveAction
                ? TextButton.styleFrom(
                    foregroundColor: NovaColors.error(context),
                  )
                : null,
            child: Text(action.text),
          );
        }).toList(),
      ),
    );
  }
}
