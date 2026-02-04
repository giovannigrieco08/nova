import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';

/// Platform-adaptive switch.
///
/// - iOS: [CupertinoSwitch] (standard Cupertino switch)
/// - Android: [Switch] Material
///
/// Example:
/// ```dart
/// AdaptiveSwitch(
///   value: _enabled,
///   onChanged: (value) => setState(() => _enabled = value),
/// )
/// ```
class AdaptiveSwitch extends StatelessWidget {
  /// Switch value
  final bool value;

  /// Value changed callback
  final ValueChanged<bool>? onChanged;

  /// Active color
  final Color? activeColor;

  const AdaptiveSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isIOS) {
      // iOS: Standard CupertinoSwitch
      return CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: activeColor ?? NovaColors.primary(context),
      );
    }

    // Android: Material Switch
    final thumbColorValue = activeColor ?? NovaColors.primary(context);
    return Switch(
      value: value,
      onChanged: onChanged,
      thumbColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.selected) ? thumbColorValue : null),
    );
  }
}
