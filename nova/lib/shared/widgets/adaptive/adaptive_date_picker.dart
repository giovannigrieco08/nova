import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';

/// Shows a platform-adaptive date picker.
///
/// - iOS: [CupertinoDatePicker] in a modal bottom sheet (native iOS wheel picker)
/// - Android: [showDatePicker] Material dialog
///
/// Returns the selected [DateTime] or null if cancelled.
///
/// Example:
/// ```dart
/// final date = await showAdaptiveDatePicker(
///   context: context,
///   initialDate: DateTime.now(),
///   firstDate: DateTime.now(),
///   lastDate: DateTime.now().add(Duration(days: 365)),
/// );
/// ```
Future<DateTime?> showAdaptiveDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  if (context.isIOS) {
    return _showCupertinoDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }

  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: lastDate,
    builder: (context, child) {
      return Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: NovaColors.primary(context),
          ),
        ),
        child: child!,
      );
    },
  );
}

/// iOS: Shows CupertinoDatePicker in a modal bottom sheet
Future<DateTime?> _showCupertinoDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) async {
  DateTime selectedDate = initialDate;

  final result = await showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (context) => Container(
      height: 300,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Header with Cancel/Done buttons
            Container(
              padding: EdgeInsets.symmetric(horizontal: NovaSpacing.m),
              decoration: BoxDecoration(
                color: CupertinoColors.systemBackground.resolveFrom(context),
                border: Border(
                  bottom: BorderSide(
                    color: CupertinoColors.separator.resolveFrom(context),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context, null),
                    child: Text(
                      'Annulla',
                      style: TextStyle(
                        color: CupertinoColors.systemBlue.resolveFrom(context),
                        fontSize: 17,
                      ),
                    ),
                  ),
                  Text(
                    'Seleziona data',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context, selectedDate),
                    child: Text(
                      'Fine',
                      style: TextStyle(
                        color: CupertinoColors.systemBlue.resolveFrom(context),
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Date picker wheel
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.date,
                initialDateTime: initialDate,
                minimumDate: firstDate,
                maximumDate: lastDate,
                onDateTimeChanged: (date) {
                  selectedDate = date;
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );

  return result;
}
