// =====================================================================
// In-App Notification Banner - Push Notifications Feature (009)
// =====================================================================
// Purpose: Display non-intrusive banner when push arrives with app in foreground
// Features: Slide-in animation, auto-dismiss after 4s, tap to navigate, swipe to dismiss
// =====================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../domain/entities/push_payload.dart';

/// Overlay entry for managing the banner
OverlayEntry? _currentBanner;
Timer? _autoDismissTimer;

/// Show in-app notification banner
///
/// Displays a banner at the top of the screen with slide-in animation.
/// Auto-dismisses after 4 seconds.
///
/// [context] - BuildContext for overlay insertion
/// [payload] - Push notification payload
/// [onTap] - Callback when user taps the banner
void showInAppNotificationBanner({
  required BuildContext context,
  required PushPayload payload,
  VoidCallback? onTap,
}) {
  // Dismiss any existing banner
  hideInAppNotificationBanner();

  // Create overlay entry
  _currentBanner = OverlayEntry(
    builder: (context) => _InAppNotificationBanner(
      payload: payload,
      onTap: () {
        hideInAppNotificationBanner();
        onTap?.call();
      },
      onDismiss: hideInAppNotificationBanner,
    ),
  );

  // Insert into overlay
  Overlay.of(context).insert(_currentBanner!);

  // Auto-dismiss after 4 seconds
  _autoDismissTimer = Timer(const Duration(seconds: 4), () {
    hideInAppNotificationBanner();
  });
}

/// Hide the current notification banner
void hideInAppNotificationBanner() {
  _autoDismissTimer?.cancel();
  _autoDismissTimer = null;
  _currentBanner?.remove();
  _currentBanner = null;
}

/// In-app notification banner widget
class _InAppNotificationBanner extends StatefulWidget {
  final PushPayload payload;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _InAppNotificationBanner({
    required this.payload,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  State<_InAppNotificationBanner> createState() =>
      _InAppNotificationBannerState();
}

class _InAppNotificationBannerState extends State<_InAppNotificationBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animations
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

    // Start entrance animation
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Dismiss with animation
  Future<void> _dismissWithAnimation() async {
    await _controller.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: NovaSpacing.m,
      right: NovaSpacing.m,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: GestureDetector(
            onTap: widget.onTap,
            onVerticalDragEnd: (details) {
              // Swipe up to dismiss
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! < -100) {
                _dismissWithAnimation();
              }
            },
            child: _buildBannerContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerContent(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: NovaColors.card(context),
        borderRadius: BorderRadius.circular(NovaRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: NovaColors.border(context).withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.all(NovaSpacing.m),
          child: Row(
            children: [
              // Icon
              _buildIcon(context),
              SizedBox(width: NovaSpacing.m),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.payload.title,
                      style: NovaTextStyles.bodyBold.copyWith(
                        color: NovaColors.textPrimary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.payload.body.isNotEmpty) ...[
                      SizedBox(height: NovaSpacing.xxs),
                      Text(
                        widget.payload.body,
                        style: NovaTextStyles.caption.copyWith(
                          color: NovaColors.textSecondary(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Chevron
              SizedBox(width: NovaSpacing.s),
              Icon(
                Icons.chevron_right,
                color: NovaColors.textTertiary(context),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context) {
    // Choose icon based on notification type
    IconData icon;
    Color iconColor;

    switch (widget.payload.targetType) {
      case 'event':
        icon = Icons.event;
        iconColor = NovaColors.primary(context);
        break;
      case 'comment':
        icon = Icons.comment_outlined;
        iconColor = NovaColors.info(context);
        break;
      default:
        icon = Icons.notifications;
        iconColor = NovaColors.primary(context);
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(NovaRadius.medium),
      ),
      child: Icon(
        icon,
        color: iconColor,
        size: 20,
      ),
    );
  }
}
