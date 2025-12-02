import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../domain/entities/notification.dart' as domain;
import '../../domain/entities/notification_channel.dart';

/// Individual notification tile widget
///
/// Features:
/// - Swipe left to delete (flutter_slidable)
/// - Tap to navigate to target
/// - Visual distinction for unread notifications
/// - Relative timestamp (timeago)
/// - Channel-specific icons
class NotificationTile extends StatelessWidget {
  final domain.Notification notification;
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
          if (notification.isUnread) {
            onMarkAsRead?.call();
          }
          onTap?.call();
        },
        child: Container(
          padding: EdgeInsets.all(NovaSpacing.m),
          decoration: BoxDecoration(
            color: notification.isUnread
                ? NovaColors.primary(context).withOpacity(0.05)
                : NovaColors.card(context),
            border: Border(
              bottom: BorderSide(
                color: NovaColors.divider(context),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Channel icon
              _buildIcon(context),
              SizedBox(width: NovaSpacing.m),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      notification.title,
                      style: NovaTextStyles.bodyBold.copyWith(
                        color: NovaColors.textPrimary(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: NovaSpacing.xs),

                    // Description
                    Text(
                      notification.description,
                      style: NovaTextStyles.body.copyWith(
                        color: NovaColors.textSecondary(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: NovaSpacing.xs),

                    // Timestamp
                    Text(
                      _formatTimeAgo(notification.createdAt),
                      style: NovaTextStyles.caption.copyWith(
                        color: NovaColors.textTertiary(context),
                      ),
                    ),
                  ],
                ),
              ),

              // Unread indicator
              if (notification.isUnread) ...[
                SizedBox(width: NovaSpacing.s),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: NovaColors.primary(context),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Build channel-specific icon
  Widget _buildIcon(BuildContext context) {
    final IconData icon;
    final Color iconColor;

    switch (notification.type) {
      case NotificationChannel.eventModeration:
        icon = Icons.verified_outlined;
        iconColor = NovaColors.success(context);
        break;
      case NotificationChannel.newComment:
        icon = Icons.chat_bubble_outline;
        iconColor = NovaColors.info(context);
        break;
      case NotificationChannel.commentReply:
        icon = Icons.reply_outlined;
        iconColor = NovaColors.info(context);
        break;
      case NotificationChannel.eventLike:
        icon = Icons.favorite_outline;
        iconColor = NovaColors.instagramRed;
        break;
      case NotificationChannel.eventParticipation:
        icon = Icons.people_outline;
        iconColor = NovaColors.primary(context);
        break;
      case NotificationChannel.coorganizerUpdate:
        icon = Icons.edit_outlined;
        iconColor = NovaColors.warning(context);
        break;
      case NotificationChannel.moderatorAlert:
        icon = Icons.admin_panel_settings_outlined;
        iconColor = NovaColors.error(context);
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.1),
        borderRadius: NovaRadius.circularFull,
      ),
      child: Icon(
        icon,
        size: 20,
        color: iconColor,
      ),
    );
  }

  /// Format timestamp as relative time in Italian
  String _formatTimeAgo(DateTime dateTime) {
    // Set Italian locale for timeago
    timeago.setLocaleMessages('it', timeago.ItMessages());
    return timeago.format(dateTime, locale: 'it');
  }
}
