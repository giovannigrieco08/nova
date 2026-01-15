import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';
import '../providers/notification_providers.dart';

/// Notification badge widget for displaying unread count
///
/// Shows a red badge with unread count on top of the bell icon.
/// Updates in real-time via Supabase Realtime subscription.
///
/// Usage:
/// ```dart
/// IconButton(
///   icon: NotificationBadge(
///     child: Icon(Icons.notifications_outlined),
///   ),
///   onPressed: () => Navigator.pushNamed(context, '/notifications'),
/// )
/// ```
class NotificationBadge extends ConsumerWidget {
  /// The child widget (usually an icon)
  final Widget child;

  /// Maximum count to display (shows "99+" if exceeded)
  final int maxCount;

  const NotificationBadge({
    super.key,
    required this.child,
    this.maxCount = 99,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);
    return _buildBadge(context, unreadCount);
  }

  Widget _buildBadge(BuildContext context, int count) {
    if (count == 0) {
      return child;
    }

    final displayText = count > maxCount ? '$maxCount+' : '$count';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -6,
          top: -4,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: count > 9 ? 4 : 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: NovaColors.instagramRed,
              borderRadius: NovaRadius.circularXs,
              border: Border.all(
                color: NovaColors.card(context),
                width: 1.5,
              ),
            ),
            constraints: const BoxConstraints(
              minWidth: 18,
              minHeight: 18,
            ),
            child: Text(
              displayText,
              style: NovaTextStyles.small.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

/// Simple notification dot indicator (no count)
///
/// Shows a small dot when there are unread notifications.
/// More subtle than the full badge.
class NotificationDot extends ConsumerWidget {
  /// The child widget (usually an icon)
  final Widget child;

  /// Dot size
  final double size;

  const NotificationDot({
    super.key,
    required this.child,
    this.size = 8,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadCountProvider);
    return unreadCount > 0 ? _buildDot(context) : child;
  }

  Widget _buildDot(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: 0,
          top: 0,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: NovaColors.instagramRed,
              shape: BoxShape.circle,
              border: Border.all(
                color: NovaColors.card(context),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
