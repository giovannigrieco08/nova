import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:nova/core/utils/platform_utils.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Platform-adaptive text field.
///
/// - iOS: [CupertinoTextField] native Cupertino text field
/// - Android: [TextField] Material with filled decoration
///
/// Example:
/// ```dart
/// AdaptiveTextField(
///   label: 'Email',
///   placeholder: 'Enter your email',
///   controller: _emailController,
///   keyboardType: TextInputType.emailAddress,
/// )
/// ```
class AdaptiveTextField extends StatelessWidget {
  /// Text editing controller
  final TextEditingController? controller;

  /// Placeholder text
  final String? placeholder;

  /// Label text (shown above field on iOS, inside on Android)
  final String? label;

  /// Keyboard type
  final TextInputType? keyboardType;

  /// Obscure text (for passwords)
  final bool obscureText;

  /// Maximum lines
  final int? maxLines;

  /// Error text
  final String? errorText;

  /// Prefix widget/icon
  final Widget? prefix;

  /// Suffix widget/icon
  final Widget? suffix;

  /// Value changed callback
  final ValueChanged<String>? onChanged;

  /// Tap callback
  final VoidCallback? onTap;

  /// Focus node
  final FocusNode? focusNode;

  /// Whether the text field is enabled
  final bool enabled;

  /// Validator function
  final String? Function(String?)? validator;

  const AdaptiveTextField({
    super.key,
    this.controller,
    this.placeholder,
    this.label,
    this.keyboardType,
    this.obscureText = false,
    this.maxLines,
    this.errorText,
    this.prefix,
    this.suffix,
    this.onChanged,
    this.onTap,
    this.focusNode,
    this.enabled = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    if (context.isIOS) {
      // iOS: Native CupertinoTextField with label above
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.xs),
          ],
          CupertinoTextField(
            controller: controller,
            placeholder: placeholder ?? '',
            keyboardType: keyboardType ?? TextInputType.text,
            obscureText: obscureText,
            onChanged: onChanged,
            onTap: onTap,
            focusNode: focusNode,
            maxLines: obscureText ? 1 : maxLines,
            padding: const EdgeInsets.all(NovaSpacing.m),
            enabled: enabled,
            decoration: BoxDecoration(
              color: NovaColors.surface(context),
              borderRadius: NovaRadius.circularM,
              border: Border.all(
                color: errorText != null
                    ? CupertinoColors.destructiveRed
                    : NovaColors.border(context),
                width: 1.0,
              ),
            ),
            prefix: prefix != null
                ? Padding(
                    padding: const EdgeInsets.only(left: NovaSpacing.s),
                    child: prefix,
                  )
                : null,
            suffix: suffix != null
                ? Padding(
                    padding: const EdgeInsets.only(right: NovaSpacing.s),
                    child: suffix,
                  )
                : null,
          ),
          if (errorText != null) ...[
            const SizedBox(height: NovaSpacing.xs),
            Text(
              errorText!,
              style: NovaTextStyles.caption.copyWith(
                color: CupertinoColors.destructiveRed,
              ),
            ),
          ],
        ],
      );
    }

    // Android: Material TextField
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: obscureText ? 1 : maxLines,
      onChanged: onChanged,
      onTap: onTap,
      focusNode: focusNode,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder,
        errorText: errorText,
        prefixIcon: prefix,
        suffixIcon: suffix,
        filled: true,
        fillColor: NovaColors.surface(context),
        border: OutlineInputBorder(
          borderRadius: NovaRadius.circularM,
          borderSide: BorderSide(color: NovaColors.border(context)),
        ),
      ),
    );
  }
}
