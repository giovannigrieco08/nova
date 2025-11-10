import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Platform detection utilities for adaptive UI rendering.
///
/// Provides helpers to detect iOS/Android and select platform-appropriate values.
/// Use [BuildContextPlatform] extension for context-aware platform checks.
class PlatformUtils {
  /// Returns true if running on iOS (not web)
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Returns true if running on Android (not web)
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Returns true if should use Cupertino Native components (iOS)
  static bool get isCupertinoNative => isIOS;

  /// Returns true if should use Material components (Android)
  static bool get isMaterial => isAndroid;

  /// Select platform-appropriate value
  ///
  /// Example:
  /// ```dart
  /// final color = PlatformUtils.adaptiveValue(
  ///   CupertinoColors.activeBlue,  // iOS
  ///   Colors.blue,                  // Android
  /// );
  /// ```
  static T adaptiveValue<T>(T ios, T android) {
    return isIOS ? ios : android;
  }
}

/// Extension on [BuildContext] for quick platform checks
///
/// Usage:
/// ```dart
/// if (context.isIOS) {
///   return CupertinoButton(...);
/// }
/// return ElevatedButton(...);
/// ```
extension BuildContextPlatform on BuildContext {
  /// Returns true if running on iOS
  bool get isIOS => PlatformUtils.isIOS;

  /// Returns true if running on Android
  bool get isAndroid => PlatformUtils.isAndroid;

  /// Returns true if should use Cupertino Native components
  bool get isCupertinoNative => PlatformUtils.isCupertinoNative;

  /// Returns true if should use Material components
  bool get isMaterial => PlatformUtils.isMaterial;

  /// Select platform-appropriate value from context
  ///
  /// Example:
  /// ```dart
  /// final padding = context.adaptive(
  ///   EdgeInsets.all(8),   // iOS
  ///   EdgeInsets.all(16),  // Android
  /// );
  /// ```
  T adaptive<T>(T ios, T android) => PlatformUtils.adaptiveValue(ios, android);
}
