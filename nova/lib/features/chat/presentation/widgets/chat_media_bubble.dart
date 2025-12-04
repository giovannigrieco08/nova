import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';

/// A bubble widget displaying ephemeral media (photo/video/audio) with view status.
///
/// Shows different states:
/// - Not viewed: Clickable with "Foto" label and view count indicator
/// - Partially viewed (for 2x): Shows remaining views
/// - Fully viewed: "Aperta" label with checkmark
/// - Expired: "Scaduta" label
class ChatMediaBubble extends ConsumerWidget {
  final ChatMediaInfo media;
  final bool isOwnMessage;
  final VoidCallback? onTap;

  const ChatMediaBubble({
    super.key,
    required this.media,
    required this.isOwnMessage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canView = media.canView;
    final isExpired = media.isExpired;
    final isViewed = media.isViewed;

    return GestureDetector(
      onTap: canView ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.m,
          vertical: NovaSpacing.s,
        ),
        decoration: BoxDecoration(
          color: _getBackgroundColor(context, isOwnMessage, canView, isViewed),
          borderRadius: BorderRadius.circular(20),
          border: canView
              ? Border.all(
                  color: isOwnMessage
                      ? Colors.white.withOpacity(0.3)
                      : NovaColors.primary(context).withOpacity(0.3),
                  width: 1.5,
                )
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            _buildIcon(context, isOwnMessage, canView, isViewed, isExpired),
            SizedBox(width: NovaSpacing.s),

            // Label
            Text(
              _getLabel(isExpired, isViewed, canView),
              style: NovaTypography.bodyMedium.copyWith(
                color: _getTextColor(context, isOwnMessage, canView, isViewed),
                fontWeight: FontWeight.w600,
              ),
            ),

            // View count indicator (only for available media with multiple views)
            if (canView && media.maxViews > 1) ...[
              SizedBox(width: NovaSpacing.xs),
              _buildViewCountBadge(context, isOwnMessage),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(
    BuildContext context,
    bool isOwnMessage,
    bool canView,
    bool isViewed,
    bool isExpired,
  ) {
    IconData icon;
    Color color;

    if (isExpired) {
      icon = Icons.timer_off_outlined;
      color = isOwnMessage ? Colors.white54 : NovaColors.textTertiary(context);
    } else if (isViewed) {
      icon = Icons.check_circle_outline;
      color = isOwnMessage ? Colors.white70 : NovaColors.textSecondary(context);
    } else {
      // Can view - show media type icon
      icon = _getMediaTypeIcon();
      color = isOwnMessage ? Colors.white : NovaColors.primary(context);
    }

    // Wrap in a circle container for better visibility
    if (canView) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: (isOwnMessage ? Colors.white : NovaColors.primary(context))
              .withOpacity(0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      );
    }

    return Icon(icon, size: 18, color: color);
  }

  IconData _getMediaTypeIcon() {
    switch (media.mediaType) {
      case ChatMediaType.image:
        return Icons.photo_camera_outlined;
      case ChatMediaType.video:
        return Icons.videocam_outlined;
      case ChatMediaType.audio:
        return Icons.mic_outlined;
    }
  }

  Widget _buildViewCountBadge(BuildContext context, bool isOwnMessage) {
    final remaining = media.remainingViews;
    final total = media.maxViews;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: (isOwnMessage ? Colors.white : NovaColors.primary(context))
            .withOpacity(0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$remaining/$total',
        style: NovaTypography.bodySmall.copyWith(
          color: isOwnMessage ? Colors.white : NovaColors.primary(context),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  String _getLabel(bool isExpired, bool isViewed, bool canView) {
    if (isExpired) return 'Scaduta';
    if (isViewed) return 'Aperta';

    // Can view
    switch (media.mediaType) {
      case ChatMediaType.image:
        return 'Foto';
      case ChatMediaType.video:
        return 'Video';
      case ChatMediaType.audio:
        return 'Audio';
    }
  }

  Color _getBackgroundColor(
    BuildContext context,
    bool isOwnMessage,
    bool canView,
    bool isViewed,
  ) {
    if (canView) {
      // Slightly different background for available media
      return isOwnMessage
          ? Colors.white.withOpacity(0.15)
          : NovaColors.primary(context).withOpacity(0.1);
    }

    // Viewed or expired - use normal bubble background
    return isOwnMessage
        ? NovaColors.primary(context)
        : NovaColors.card(context);
  }

  Color _getTextColor(
    BuildContext context,
    bool isOwnMessage,
    bool canView,
    bool isViewed,
  ) {
    if (canView) {
      return isOwnMessage ? Colors.white : NovaColors.primary(context);
    }

    // Viewed or expired - muted text
    return isOwnMessage
        ? Colors.white70
        : NovaColors.textSecondary(context);
  }
}
