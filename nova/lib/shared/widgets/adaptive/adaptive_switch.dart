import 'package:flutter/material.dart';
import 'package:cupertino_native/cupertino_native.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';

/// Platform-adaptive switch.
///
/// - iOS: [CNSwitch] (native UIKit switch from cupertino_native)
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
      // iOS: Native CNSwitch from cupertino_native
      return CNSwitch(
        value: value,
        onChanged: onChanged ?? (_) {},
      );
    }

    // Android: Material Switch
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: activeColor ?? NovaColors.primary(context),
    );
  }
}
