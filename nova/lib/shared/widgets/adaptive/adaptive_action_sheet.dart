import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_dialog.dart';

/// Platform-adaptive action sheet.
///
/// - iOS: [CupertinoActionSheet] (native bottom sheet)
/// - Android: [AlertDialog] (falls back to dialog)
///
/// Example:
/// ```dart
/// AdaptiveActionSheet.show(
///   context: context,
///   title: 'Choose Action',
///   actions: [
///     AdaptiveDialogAction(
///       text: 'Edit',
///       onPressed: () => _edit(),
///     ),
///     AdaptiveDialogAction(
///       text: 'Delete',
///       isDestructiveAction: true,
///       onPressed: () => _delete(),
///     ),
///   ],
///   cancelAction: AdaptiveDialogAction(
///     text: 'Cancel',
///     onPressed: () {},
///   ),
/// )
/// ```
class AdaptiveActionSheet {
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    String? message,
    required List<AdaptiveDialogAction> actions,
    AdaptiveDialogAction? cancelAction,
  }) {
    if (context.isIOS) {
      // iOS: CupertinoActionSheet
      return showCupertinoModalPopup<T>(
        context: context,
        builder: (context) => CupertinoActionSheet(
          title: title != null ? Text(title) : null,
          message: message != null ? Text(message) : null,
          actions: actions.map((action) {
            return CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(context).pop();
                action.onPressed();
              },
              isDestructiveAction: action.isDestructiveAction,
              child: Text(action.text),
            );
          }).toList(),
          cancelButton: cancelAction != null
              ? CupertinoActionSheetAction(
                  onPressed: () {
                    Navigator.of(context).pop();
                    cancelAction.onPressed();
                  },
                  child: Text(cancelAction.text),
                )
              : null,
        ),
      );
    }

    // Android: Falls back to AlertDialog
    return AdaptiveDialog.show<T>(
      context: context,
      title: title ?? '',
      content: message,
      actions: [
        ...actions,
        if (cancelAction != null) cancelAction,
      ],
    );
  }
}
