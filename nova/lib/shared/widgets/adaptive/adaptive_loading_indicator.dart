import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';

/// Platform-adaptive loading indicator.
///
/// - iOS: [CupertinoActivityIndicator]
/// - Android: [CircularProgressIndicator]
///
/// Example:
/// ```dart
/// AdaptiveLoadingIndicator()
/// ```
class AdaptiveLoadingIndicator extends StatelessWidget {
  /// Indicator radius/size
  final double? radius;

  /// Indicator color
  final Color? color;

  const AdaptiveLoadingIndicator({
    super.key,
    this.radius,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isIOS) {
      return CupertinoActivityIndicator(
        radius: radius ?? 12,
        color: color,
      );
    }

    return CircularProgressIndicator(
      strokeWidth: 3,
      color: color,
    );
  }
}
