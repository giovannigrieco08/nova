// Widget: OfflineBanner
// Feature: 003-events-feed
// Purpose: Dismissible banner shown when user is offline (FR-009)

import 'package:flutter/material.dart';

class OfflineBanner extends StatefulWidget {
  final bool isOffline; // Show banner when true
  final VoidCallback? onDismiss; // Callback when user dismisses
  final String message; // Custom message (optional)

  const OfflineBanner({
    super.key,
    required this.isOffline,
    this.onDismiss,
    this.message = 'You\'re offline. Viewing cached events.',
  });

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner>
    with SingleTickerProviderStateMixin {
  bool _isDismissed = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Slide animation for banner appearance
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );

    // Show banner if offline
    if (widget.isOffline) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(OfflineBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Show banner when going offline
    if (widget.isOffline && !oldWidget.isOffline) {
      setState(() {
        _isDismissed = false;
      });
      _animationController.forward();
    }

    // Hide banner when going online
    if (!widget.isOffline && oldWidget.isOffline) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    setState(() {
      _isDismissed = true;
    });
    _animationController.reverse();
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if dismissed or online
    if (_isDismissed || !widget.isOffline) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation.drive(
        Tween<Offset>(
          begin: const Offset(0, -1),
          end: const Offset(0, 0),
        ),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange[700],
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              // Offline icon
              Icon(
                Icons.cloud_off,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 12),

              // Message
              Expanded(
                child: Text(
                  widget.message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Dismiss button
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 18),
                onPressed: _handleDismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Dismiss',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Persistent offline banner (stays visible, not dismissible)
/// Used for critical offline state indicators
class PersistentOfflineBanner extends StatelessWidget {
  final String message;
  final Color? backgroundColor;
  final Color? textColor;
  final IconData? icon;

  const PersistentOfflineBanner({
    super.key,
    this.message = 'No internet connection',
    this.backgroundColor,
    this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.red[700],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.wifi_off,
              color: textColor ?? Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              message,
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
