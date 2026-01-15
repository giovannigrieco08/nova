import 'package:flutter/material.dart';
import '../utils/platform_utils.dart';

/// Platform-adaptive animation curves and durations.
///
/// iOS uses spring-based, fluid curves while Android uses Material motion curves.
/// This ensures animations feel native to each platform.
class NovaAnimations {
  // iOS-style animation parameters (spring-based, fluid)
  static const Curve iosCurve = Curves.easeInOut;
  static const Duration iosDuration = Duration(milliseconds: 350);

  // Android-style animation parameters (Material motion)
  static const Curve androidCurve = Curves.easeInOutCubic;
  static const Duration androidDuration = Duration(milliseconds: 300);

  /// Returns platform-appropriate animation curve
  ///
  /// - iOS: [Curves.easeInOut] (spring-based)
  /// - Android: [Curves.easeInOutCubic] (Material)
  static Curve platformCurve(BuildContext context) {
    return context.isIOS ? iosCurve : androidCurve;
  }

  /// Returns platform-appropriate animation duration
  ///
  /// - iOS: 350ms
  /// - Android: 300ms
  static Duration platformDuration(BuildContext context) {
    return context.isIOS ? iosDuration : androidDuration;
  }

  /// Returns platform-appropriate page transition builder
  ///
  /// - iOS: [CupertinoPageTransitionsBuilder] (slide from right)
  /// - Android: [FadeUpwardsPageTransitionsBuilder] (fade + scale)
  static PageTransitionsBuilder get platformTransition {
    return PlatformUtils.isIOS
        ? const CupertinoPageTransitionsBuilder()
        : const FadeUpwardsPageTransitionsBuilder();
  }

  /// Page transitions theme for both platforms
  static PageTransitionsTheme get pageTransitionsTheme {
    return PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: const CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: const FadeUpwardsPageTransitionsBuilder(),
      },
    );
  }
}
