import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';

/// Platform-adaptive segmented control.
///
/// - iOS: [CupertinoSegmentedControl] (standard Cupertino segmented control)
/// - Android: [SegmentedButton] Material 3
///
/// Example:
/// ```dart
/// AdaptiveSegmentedControl<String>(
///   groupValue: _selected,
///   onValueChanged: (value) => setState(() => _selected = value),
///   children: {
///     'option1': 'Option 1',
///     'option2': 'Option 2',
///   },
/// )
/// ```
class AdaptiveSegmentedControl<T extends Object> extends StatelessWidget {
  /// Segment options (value -> label)
  final Map<T, String> children;

  /// Currently selected value
  final T? groupValue;

  /// Value changed callback
  final ValueChanged<T>? onValueChanged;

  const AdaptiveSegmentedControl({
    super.key,
    required this.children,
    required this.groupValue,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isIOS) {
      // iOS: Standard CupertinoSegmentedControl
      return CupertinoSegmentedControl<T>(
        children: children.map((key, value) => MapEntry(
          key,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(value),
          ),
        )),
        groupValue: groupValue,
        onValueChanged: (T value) {
          onValueChanged?.call(value);
        },
      );
    }

    // Android: Material 3 SegmentedButton
    return SegmentedButton<T>(
      segments: children.entries.map((entry) {
        return ButtonSegment<T>(
          value: entry.key,
          label: Text(entry.value),
        );
      }).toList(),
      selected: {if (groupValue != null) groupValue!},
      onSelectionChanged: (Set<T> selected) {
        if (selected.isNotEmpty && onValueChanged != null) {
          onValueChanged!(selected.first);
        }
      },
    );
  }
}
