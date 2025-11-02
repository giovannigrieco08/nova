// Shared Widget: NovaToast
// Feature: 002-profile-setup (and reusable across features)
// Purpose: Success/error toast notifications

import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_spacing.dart';
import '../../core/theme/nova_radius.dart';
import '../../core/theme/nova_typography.dart';

/// Toast notification types
enum ToastType {
  success,
  error,
  info,
}

/// Static helper class for showing toast notifications
class NovaToast {
  /// Show success toast (green)
  static void showSuccess(BuildContext context, String message) {
    _show(context, message, ToastType.success);
  }

  /// Show error toast (red)
  static void showError(BuildContext context, String message) {
    _show(context, message, ToastType.error);
  }

  /// Show info toast (blue)
  static void showInfo(BuildContext context, String message) {
    _show(context, message, ToastType.info);
  }

  /// Internal method to show toast using ScaffoldMessenger
  static void _show(BuildContext context, String message, ToastType type) {
    // Get colors based on type
    final backgroundColor = _getBackgroundColor(context, type);
    final iconData = _getIcon(type);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              iconData,
              color: Colors.white,
              size: 20,
            ),
            SizedBox(width: NovaSpacing.m),
            Expanded(
              child: Text(
                message,
                style: NovaTextStyles.body.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NovaRadius.l),
        ),
        margin: EdgeInsets.symmetric(
          horizontal: NovaSpacing.xl,
          vertical: NovaSpacing.l,
        ),
        duration: const Duration(seconds: 2),
        elevation: 4,
      ),
    );
  }

  /// Get background color based on toast type
  static Color _getBackgroundColor(BuildContext context, ToastType type) {
    switch (type) {
      case ToastType.success:
        return NovaColors.success(context);
      case ToastType.error:
        return NovaColors.error(context);
      case ToastType.info:
        return NovaColors.info(context);
    }
  }

  /// Get icon based on toast type
  static IconData _getIcon(ToastType type) {
    switch (type) {
      case ToastType.success:
        return Icons.check_circle;
      case ToastType.error:
        return Icons.error;
      case ToastType.info:
        return Icons.info;
    }
  }
}

/// Example usage:
/// ```dart
/// NovaToast.showSuccess(context, 'Profilo aggiornato ✓');
/// NovaToast.showError(context, 'Errore nel salvataggio');
/// NovaToast.showInfo(context, 'Modifiche salvate offline');
/// ```
