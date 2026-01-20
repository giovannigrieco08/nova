// Shared Widget: NovaToast
// Feature: 002-profile-setup (and reusable across features)
// Purpose: Success/error toast notifications (Cupertino-compatible)

import 'package:flutter/cupertino.dart';
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
/// Uses overlay-based approach for Cupertino compatibility
class NovaToast {
  static OverlayEntry? _currentToast;

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

  /// Internal method to show toast using Overlay (Cupertino-compatible)
  static void _show(BuildContext context, String message, ToastType type, {Duration duration = const Duration(seconds: 2)}) {
    // Remove any existing toast
    _currentToast?.remove();
    _currentToast = null;

    final overlay = Overlay.of(context);
    final backgroundColor = _getBackgroundColor(context, type);
    final iconData = _getIcon(type);

    _currentToast = OverlayEntry(
      builder: (context) => _ToastWidget(
        message: message,
        backgroundColor: backgroundColor,
        iconData: iconData,
        duration: duration,
        onDismiss: () {
          _currentToast?.remove();
          _currentToast = null;
        },
      ),
    );

    overlay.insert(_currentToast!);
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
        return CupertinoIcons.check_mark_circled_solid;
      case ToastType.error:
        return CupertinoIcons.xmark_circle_fill;
      case ToastType.info:
        return CupertinoIcons.info_circle_fill;
    }
  }
}

/// Internal toast widget with animation
class _ToastWidget extends StatefulWidget {
  final String message;
  final Color backgroundColor;
  final IconData iconData;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ToastWidget({
    required this.message,
    required this.backgroundColor,
    required this.iconData,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _controller.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + NovaSpacing.l,
      left: NovaSpacing.xl,
      right: NovaSpacing.xl,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: NovaSpacing.l,
                vertical: NovaSpacing.m,
              ),
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: BorderRadius.circular(NovaRadius.l),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    widget.iconData,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: NovaSpacing.m),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: NovaTextStyles.body.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Example usage:
/// ```dart
/// NovaToast.showSuccess(context, 'Profilo aggiornato ✓');
/// NovaToast.showError(context, 'Errore nel salvataggio');
/// NovaToast.showInfo(context, 'Modifiche salvate offline');
/// ```
