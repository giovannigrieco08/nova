import 'package:flutter/material.dart';
import 'package:cupertino_native/cupertino_native.dart';
import 'package:nova/core/utils/platform_utils.dart';

/// Platform-adaptive segmented control.
///
/// - iOS: [CNSegmentedControl] (native UIKit segmented control from cupertino_native)
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
class AdaptiveSegmentedControl<T> extends StatelessWidget {
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
      // iOS: Native CNSegmentedControl from cupertino_native
      // Convert Map<T, String> to List<String> and index-based selection
      final labels = children.values.toList();
      final values = children.keys.toList();
      final selectedIndex = groupValue != null
          ? values.indexOf(groupValue as T)
          : 0;

      return CNSegmentedControl(
        labels: labels,
        selectedIndex: selectedIndex >= 0 ? selectedIndex : 0,
        onValueChanged: (index) {
          if (index >= 0 && index < values.length && onValueChanged != null) {
            onValueChanged!(values[index]);
          }
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
