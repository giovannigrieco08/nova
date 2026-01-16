import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';

/// Shows a platform-adaptive time picker.
///
/// - iOS: [CupertinoDatePicker] in time mode in a modal bottom sheet (native iOS wheel picker)
/// - Android: [showTimePicker] Material dialog
///
/// Returns the selected [TimeOfDay] or null if cancelled.
///
/// Example:
/// ```dart
/// final time = await showAdaptiveTimePicker(
///   context: context,
///   initialTime: TimeOfDay.now(),
/// );
/// ```
Future<TimeOfDay?> showAdaptiveTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  if (context.isIOS) {
    return _showCupertinoTimePicker(
      context: context,
      initialTime: initialTime,
    );
  }

  return showTimePicker(
    context: context,
    initialTime: initialTime,
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

/// iOS: Shows CupertinoDatePicker in time mode in a modal bottom sheet
Future<TimeOfDay?> _showCupertinoTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
}) async {
  // Convert TimeOfDay to DateTime for CupertinoDatePicker
  final now = DateTime.now();
  DateTime selectedDateTime = DateTime(
    now.year,
    now.month,
    now.day,
    initialTime.hour,
    initialTime.minute,
  );

  final result = await showCupertinoModalPopup<TimeOfDay>(
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
                    'Seleziona ora',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: CupertinoColors.label.resolveFrom(context),
                    ),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(
                      context,
                      TimeOfDay(
                        hour: selectedDateTime.hour,
                        minute: selectedDateTime.minute,
                      ),
                    ),
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
            // Time picker wheel
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                initialDateTime: selectedDateTime,
                use24hFormat: true,
                onDateTimeChanged: (dateTime) {
                  selectedDateTime = dateTime;
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
