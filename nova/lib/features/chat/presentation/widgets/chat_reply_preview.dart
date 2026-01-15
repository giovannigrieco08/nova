import 'package:flutter/material.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';

/// Preview of a message being replied to.
///
/// Used in:
/// - ChatComposeBar: Shows the message being replied to with dismiss button
/// - ChatMessageTile: Shows the quoted message in Instagram style (above the bubble)
class ChatReplyPreview extends StatelessWidget {
  final ChatMessage replyTo;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final bool isCompact;
  /// Current user ID to determine if replying to own message
  final String? currentUserId;
  /// Whether the reply preview is for own message (affects alignment)
  final bool isOwnMessage;

  const ChatReplyPreview({
    super.key,
    required this.replyTo,
    this.onTap,
    this.onDismiss,
    this.isCompact = false,
    this.currentUserId,
    this.isOwnMessage = false,
  });

  @override
  Widget build(BuildContext context) {
    // Compose bar style (with dismiss button)
    if (onDismiss != null) {
      return _buildComposeBarStyle(context);
    }

    // Chat bubble style (Instagram-like, above the message)
    return _buildChatBubbleStyle(context);
  }

  /// Build the compose bar style (original style with dismiss button)
  Widget _buildComposeBarStyle(BuildContext context) {
    final isDeleted = replyTo.isHidden;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(NovaSpacing.s),
        decoration: BoxDecoration(
          color: NovaColors.card(context).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(NovaRadius.s),
          border: Border(
            left: BorderSide(
              color: NovaColors.primary(context),
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Author name
                  Text(
                    isDeleted
                        ? 'Messaggio eliminato'
                        : replyTo.author.fullName,
                    style: NovaTypography.bodySmall.copyWith(
                      color: NovaColors.primary(context),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: NovaSpacing.xxs),

                  // Message preview
                  Text(
                    isDeleted
                        ? '[Messaggio eliminato]'
                        : replyTo.content,
                    style: NovaTypography.bodySmall.copyWith(
                      color: isDeleted
                          ? NovaColors.textTertiary(context)
                          : NovaColors.textSecondary(context),
                      fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Dismiss button
            SizedBox(width: NovaSpacing.xs),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              onPressed: onDismiss,
              color: NovaColors.textTertiary(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the Instagram-style chat bubble reply preview
  Widget _buildChatBubbleStyle(BuildContext context) {
    final isDeleted = replyTo.isHidden;
    final isReplyToSelf = currentUserId != null && replyTo.userId == currentUserId;

    // Determine label text
    final String replyLabel;
    if (isDeleted) {
      replyLabel = 'Messaggio eliminato';
    } else if (isReplyToSelf) {
      replyLabel = 'Hai risposto al tuo messaggio';
    } else {
      replyLabel = 'Hai risposto a ${replyTo.author.fullName}';
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: isOwnMessage
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply label (like Instagram)
          Padding(
            padding: EdgeInsets.only(
              left: isOwnMessage ? 0 : NovaSpacing.xs,
              right: isOwnMessage ? NovaSpacing.xs : 0,
              bottom: NovaSpacing.xxs,
            ),
            child: Text(
              replyLabel,
              style: NovaTypography.labelSmall.copyWith(
                color: NovaColors.textTertiary(context),
                fontSize: 11,
              ),
            ),
          ),

          // Quoted message bubble (darker, compact)
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.6,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: NovaSpacing.s + 2,
              vertical: NovaSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: NovaColors.backgroundSecondary(context),
              borderRadius: NovaRadius.circularM,
            ),
            child: Text(
              isDeleted
                  ? '[Messaggio eliminato]'
                  : replyTo.content,
              style: NovaTypography.bodySmall.copyWith(
                color: isDeleted
                    ? NovaColors.textTertiary(context)
                    : NovaColors.textSecondary(context),
                fontStyle: isDeleted ? FontStyle.italic : FontStyle.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
