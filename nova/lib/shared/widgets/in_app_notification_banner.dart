// Widget: InAppNotificationBanner
// Purpose: Shows a banner when a notification arrives while app is open
// Style: Instagram/WhatsApp-like slide-down banner

import 'package:flutter/material.dart';
import '../../core/theme/nova_colors.dart';
import '../../core/theme/nova_radius.dart';
import '../../core/theme/nova_spacing.dart';

/// In-app notification banner that slides down from top
///
/// Usage:
/// ```dart
/// InAppNotificationBanner.show(
///   context: context,
///   title: 'Nuovo commento',
///   body: 'Mario ha commentato il tuo evento',
///   onTap: () => Navigator.push(...),
/// );
/// ```
class InAppNotificationBanner {
  static OverlayEntry? _currentEntry;
  static bool _isShowing = false;

  /// Show the notification banner
  static void show({
    required BuildContext context,
    required String title,
    required String body,
    String? avatarUrl,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Don't show if already showing
    if (_isShowing) {
      dismiss();
    }

    _isShowing = true;

    final overlay = Overlay.of(context);

    _currentEntry = OverlayEntry(
      builder: (context) => _NotificationBannerWidget(
        title: title,
        body: body,
        avatarUrl: avatarUrl,
        onTap: () {
          dismiss();
          onTap?.call();
        },
        onDismiss: dismiss,
        duration: duration,
      ),
    );

    overlay.insert(_currentEntry!);
  }

  /// Dismiss the current banner
  static void dismiss() {
    _currentEntry?.remove();
    _currentEntry = null;
    _isShowing = false;
  }
}

class _NotificationBannerWidget extends StatefulWidget {
  final String title;
  final String body;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final VoidCallback onDismiss;
  final Duration duration;

  const _NotificationBannerWidget({
    required this.title,
    required this.body,
    this.avatarUrl,
    this.onTap,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_NotificationBannerWidget> createState() =>
      _NotificationBannerWidgetState();
}

class _NotificationBannerWidgetState extends State<_NotificationBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    // Start animation
    _controller.forward();

    // Auto dismiss after duration
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismissWithAnimation();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismissWithAnimation() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragEnd: (details) {
              // Swipe up to dismiss
              if (details.velocity.pixelsPerSecond.dy < -100) {
                _dismissWithAnimation();
              }
            },
            child: Container(
              margin: EdgeInsets.fromLTRB(
                NovaSpacing.m,
                topPadding + NovaSpacing.s,
                NovaSpacing.m,
                0,
              ),
              padding: EdgeInsets.all(NovaSpacing.m),
              decoration: BoxDecoration(
                color: NovaColors.surface(context),
                borderRadius: BorderRadius.circular(NovaRadius.l),
                boxShadow: [
                  BoxShadow(
                    color: NovaColors.backgroundDark.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: NovaColors.border(context),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  // Avatar or icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: NovaColors.primary(context).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: widget.avatarUrl != null
                        ? ClipOval(
                            child: Image.network(
                              widget.avatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                Icons.notifications,
                                color: NovaColors.primary(context),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.notifications,
                            color: NovaColors.primary(context),
                          ),
                  ),
                  SizedBox(width: NovaSpacing.m),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: NovaColors.textPrimary(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          widget.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: NovaColors.textSecondary(context),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: NovaSpacing.s),
                  // Close button
                  GestureDetector(
                    onTap: _dismissWithAnimation,
                    child: Icon(
                      Icons.close,
                      size: 20,
                      color: NovaColors.textTertiary(context),
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
