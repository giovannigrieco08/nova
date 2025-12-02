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
/// - ChatMessageTile: Shows the quoted message in compact form
class ChatReplyPreview extends StatelessWidget {
  final ChatMessage replyTo;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;
  final bool isCompact;

  const ChatReplyPreview({
    super.key,
    required this.replyTo,
    this.onTap,
    this.onDismiss,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDeleted = replyTo.isHidden;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(isCompact ? NovaSpacing.xs : NovaSpacing.s),
        decoration: BoxDecoration(
          color: NovaColors.card(context).withOpacity(0.5),
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
                        : replyTo.author.fullName ?? replyTo.author.username,
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
                    maxLines: isCompact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            // Dismiss button (only in compose bar)
            if (onDismiss != null) ...[
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
          ],
        ),
      ),
    );
  }
}
