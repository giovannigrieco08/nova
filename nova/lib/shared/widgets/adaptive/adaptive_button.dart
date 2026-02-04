import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';

/// Button type for adaptive styling
enum AdaptiveButtonType {
  /// Primary filled button (default)
  primary,

  /// Secondary outlined button
  secondary,

  /// Destructive action (red/warning)
  destructive,

  /// Text-only button (no background)
  text,
}

/// Platform-adaptive button.
///
/// - iOS: [CupertinoButton] (will use CNButton from cupertino_native in future)
/// - Android: [FilledButton] / [OutlinedButton] / [TextButton]
///
/// Example:
/// ```dart
/// AdaptiveButton(
///   type: AdaptiveButtonType.primary,
///   onPressed: () => print('Pressed'),
///   child: Text('Save'),
/// )
/// ```
class AdaptiveButton extends StatelessWidget {
  /// Button content
  final Widget child;

  /// Tap callback
  final VoidCallback? onPressed;

  /// Button style type
  final AdaptiveButtonType type;

  /// Whether button has filled background
  final bool filled;

  /// Minimum height (defaults to 48px)
  final double? minHeight;

  /// iOS only: SF Symbol icon name (for icon buttons)
  final String? iconSystemName;

  /// Android only: Material icon
  final IconData? androidIcon;

  const AdaptiveButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.type = AdaptiveButtonType.primary,
    this.filled = true,
    this.minHeight,
    this.iconSystemName,
    this.androidIcon,
  });

  @override
  Widget build(BuildContext context) {
    final height = minHeight ?? 48.0;

    if (context.isIOS) {
      // iOS: CupertinoButton (TODO: Migrate to CNButton from cupertino_native)
      Color? buttonColor;

      switch (type) {
        case AdaptiveButtonType.primary:
          buttonColor = filled ? NovaColors.primary(context) : null;
          break;
        case AdaptiveButtonType.destructive:
          buttonColor = filled ? CupertinoColors.destructiveRed : null;
          break;
        case AdaptiveButtonType.secondary:
        case AdaptiveButtonType.text:
          buttonColor = null;
          break;
      }

      return CupertinoButton(
        onPressed: onPressed,
        color: buttonColor,
        borderRadius: NovaRadius.circularL,
        padding: const EdgeInsets.symmetric(
          horizontal: NovaSpacing.l,
          vertical: NovaSpacing.m,
        ),
        minimumSize: Size(height, height),
        child: child,
      );
    }

    // Android: Material 3 buttons
    Widget button;

    switch (type) {
      case AdaptiveButtonType.primary:
        button = FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(height),
          ),
          child: androidIcon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(androidIcon),
                    const SizedBox(width: NovaSpacing.xs),
                    child,
                  ],
                )
              : child,
        );
        break;

      case AdaptiveButtonType.secondary:
        button = OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            minimumSize: Size.fromHeight(height),
          ),
          child: androidIcon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(androidIcon),
                    const SizedBox(width: NovaSpacing.xs),
                    child,
                  ],
                )
              : child,
        );
        break;

      case AdaptiveButtonType.destructive:
        button = FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            minimumSize: Size.fromHeight(height),
            backgroundColor: NovaColors.error(context),
          ),
          child: child,
        );
        break;

      case AdaptiveButtonType.text:
        button = TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            minimumSize: Size.fromHeight(height),
          ),
          child: child,
        );
        break;
    }

    return button;
  }
}
