import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cupertino_native/cupertino_native.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';

/// Platform-adaptive slider.
///
/// - iOS: [CNSlider] (native UIKit slider from cupertino_native)
/// - Android: [Slider] Material
///
/// Example:
/// ```dart
/// AdaptiveSlider(
///   value: _volume,
///   min: 0,
///   max: 100,
///   onChanged: (value) => setState(() => _volume = value),
/// )
/// ```
class AdaptiveSlider extends StatelessWidget {
  /// Current value
  final double value;

  /// Value changed callback
  final ValueChanged<double>? onChanged;

  /// Minimum value
  final double min;

  /// Maximum value
  final double max;

  /// Number of discrete divisions
  final int? divisions;

  const AdaptiveSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isIOS) {
      // iOS: Native CNSlider from cupertino_native
      return CNSlider(
        value: value,
        min: min,
        max: max,
        onChanged: onChanged,
      );
    }

    // Android: Material Slider
    return Slider(
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      onChanged: onChanged,
      activeColor: NovaColors.primary(context),
    );
  }
}
