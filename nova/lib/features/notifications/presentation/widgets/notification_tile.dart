import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../profile/presentation/widgets/avatar_initials.dart';
import '../../domain/entities/notification.dart' as domain;

/// Individual notification tile widget (Instagram-style)
///
/// Features:
/// - Swipe left to delete (flutter_slidable)
/// - Tap to navigate to target
/// - Avatar of actor (user who triggered notification)
/// - Blue dot for unread notifications
/// - CTA button on the RIGHT side (filled, colored)
/// - Relative timestamp inline with text
class NotificationTile extends StatelessWidget {
  final domain.AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onMarkAsRead;

  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onDelete,
    this.onMarkAsRead,
  });

  @override
  Widget build(BuildContext context) {
    return Slidable(
      key: ValueKey(notification.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        dismissible: DismissiblePane(onDismissed: () => onDelete?.call()),
        children: [
          SlidableAction(
            onPressed: (_) => onDelete?.call(),
            backgroundColor: NovaColors.error(context),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Elimina',
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(NovaRadius.m),
              bottomRight: Radius.circular(NovaRadius.m),
            ),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          if (!notification.isRead) {
            onMarkAsRead?.call();
          }
          onTap?.call();
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.l,
            vertical: NovaSpacing.m,
          ),
          decoration: BoxDecoration(
            color: NovaColors.background(context),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with unread badge
              _buildAvatarWithBadge(context),
              SizedBox(width: NovaSpacing.m),

              // Content (text + timestamp inline)
              Expanded(
                child: _buildNotificationContent(context),
              ),

              // CTA Button on RIGHT (if applicable)
              if (notification.hasAction) ...[
                SizedBox(width: NovaSpacing.s),
                _buildCTAButton(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build avatar with blue unread badge
  Widget _buildAvatarWithBadge(BuildContext context) {
    return Stack(
      children: [
        _buildAvatar(context),
        // Blue dot badge for unread notifications
        if (!notification.isRead)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: NovaColors.primary(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: NovaColors.background(context),
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Build actor avatar (40x40 circle)
  Widget _buildAvatar(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: ClipOval(
        child: notification.actorAvatarUrl != null &&
                notification.actorAvatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: notification.actorAvatarUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: NovaColors.surface(context),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => AvatarInitials(
                  fullName: notification.actorName ?? 'U',
                  size: 40,
                ),
              )
            : AvatarInitials(
                fullName: notification.actorName ?? 'Nova',
                size: 40,
              ),
      ),
    );
  }

  /// Build notification content (text + timestamp inline, Instagram-style)
  Widget _buildNotificationContent(BuildContext context) {
    final relativeTime = _formatTimeAgo(notification.createdAt);

    // Use body (full description) if available, otherwise fall back to title
    // body contains "Nome ha messo like al tuo evento"
    // title contains just "Nuovo like"
    final displayText = notification.body.isNotEmpty
        ? notification.body
        : notification.title;

    // Instagram style: "Description text timestamp"
    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: NovaTextStyles.body.copyWith(
          color: NovaColors.textPrimary(context),
          height: 1.35,
        ),
        children: [
          // Main notification text
          TextSpan(
            text: displayText,
          ),
          // Timestamp in tertiary color (single space before)
          TextSpan(
            text: ' $relativeTime',
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textTertiary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Build CTA button (filled, colored, on right side - Instagram style)
  Widget _buildCTAButton(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ElevatedButton(
        onPressed: () {
          if (!notification.isRead) {
            onMarkAsRead?.call();
          }
          onTap?.call();
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: NovaColors.primary(context),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.m,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(NovaRadius.s),
          ),
        ),
        child: Text(
          notification.ctaLabel,
          style: NovaTextStyles.caption.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  /// Format timestamp as relative time in Italian (short format)
  String _formatTimeAgo(DateTime dateTime) {
    timeago.setLocaleMessages('it_short', timeago.ItShortMessages());
    return timeago.format(dateTime, locale: 'it_short');
  }
}
