import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';
import 'package:nova/features/chat/presentation/widgets/chat_reaction_row.dart';
import 'package:nova/features/chat/presentation/widgets/chat_reply_preview.dart';
import 'package:nova/shared/widgets/avatar_widget.dart';

/// A single message tile in the chat feed.
///
/// Displays:
/// - Author avatar and name
/// - Message content with mention highlighting
/// - Relative timestamp
/// - Reply preview (if replying to another message)
/// - Reaction row with counts
///
/// Supports:
/// - Long-press for context menu (report, react)
/// - Swipe right to reply
/// - Tap on reactions to toggle
class ChatMessageTile extends ConsumerWidget {
  final ChatMessage message;
  final VoidCallback? onReply;
  final VoidCallback? onReport;
  final void Function(String emoji)? onReact;
  final VoidCallback? onTapReplyPreview;

  const ChatMessageTile({
    super.key,
    required this.message,
    this.onReply,
    this.onReport,
    this.onReact,
    this.onTapReplyPreview,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOwnMessage = message.userId == currentUserId;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          if (!isOwnMessage) ...[
            AvatarWidget(
              avatarUrl: message.author.avatarUrl,
              name: message.author.fullName ?? message.author.username,
              size: 36,
            ),
            SizedBox(width: NovaSpacing.s),
          ],

          // Message bubble
          Expanded(
            child: Column(
              crossAxisAlignment:
                  isOwnMessage ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Author name and timestamp (for other users)
                if (!isOwnMessage)
                  Padding(
                    padding: EdgeInsets.only(bottom: NovaSpacing.xxs),
                    child: Row(
                      children: [
                        Text(
                          message.author.fullName ?? message.author.username,
                          style: NovaTypography.bodySmall.copyWith(
                            color: NovaColors.textSecondary(context),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: NovaSpacing.xs),
                        Text(
                          message.relativeTimestamp,
                          style: NovaTypography.bodySmall.copyWith(
                            color: NovaColors.textTertiary(context),
                          ),
                        ),
                      ],
                    ),
                  ),

                // Message bubble
                GestureDetector(
                  onLongPress: () => _showContextMenu(context),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: EdgeInsets.all(NovaSpacing.s),
                    decoration: BoxDecoration(
                      color: isOwnMessage
                          ? NovaColors.primary(context).withOpacity(0.15)
                          : NovaColors.card(context),
                      borderRadius: BorderRadius.circular(NovaRadius.l),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Reply preview
                        if (message.isReply && message.replyTo != null)
                          Padding(
                            padding: EdgeInsets.only(bottom: NovaSpacing.xs),
                            child: ChatReplyPreview(
                              replyTo: message.replyTo!,
                              onTap: onTapReplyPreview,
                              isCompact: true,
                            ),
                          ),

                        // Message content
                        _buildMessageContent(context),

                        // Timestamp for own messages
                        if (isOwnMessage)
                          Padding(
                            padding: EdgeInsets.only(top: NovaSpacing.xxs),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                message.relativeTimestamp,
                                style: NovaTypography.bodySmall.copyWith(
                                  color: NovaColors.textTertiary(context),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Reactions row
                if (message.reactionCounts.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: NovaSpacing.xxs),
                    child: ChatReactionRow(
                      reactionCounts: message.reactionCounts,
                      currentUserReactions: message.currentUserReactions,
                      onTap: onReact,
                    ),
                  ),
              ],
            ),
          ),

          // Spacing for own messages
          if (isOwnMessage) SizedBox(width: NovaSpacing.m),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (message.isHidden) {
      return Text(
        message.displayContent,
        style: NovaTypography.bodyMedium.copyWith(
          color: NovaColors.textTertiary(context),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    // For messages with mentions, highlight them
    if (message.hasMentions) {
      return _buildHighlightedContent(context);
    }

    return Text(
      message.content,
      style: NovaTypography.bodyMedium.copyWith(
        color: NovaColors.textPrimary(context),
      ),
    );
  }

  Widget _buildHighlightedContent(BuildContext context) {
    final content = message.content;
    final mentions = message.mentions;

    // Sort mentions by start index
    final sortedMentions = [...mentions]
      ..sort((a, b) => a.startIndex.compareTo(b.startIndex));

    final spans = <TextSpan>[];
    int currentIndex = 0;

    for (final mention in sortedMentions) {
      // Add text before mention
      if (mention.startIndex > currentIndex) {
        spans.add(TextSpan(
          text: content.substring(currentIndex, mention.startIndex),
          style: NovaTypography.bodyMedium.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ));
      }

      // Add highlighted mention
      spans.add(TextSpan(
        text: content.substring(mention.startIndex, mention.endIndex),
        style: NovaTypography.bodyMedium.copyWith(
          color: NovaColors.primary(context),
          fontWeight: FontWeight.w600,
        ),
      ));

      currentIndex = mention.endIndex;
    }

    // Add remaining text
    if (currentIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(currentIndex),
        style: NovaTypography.bodyMedium.copyWith(
          color: NovaColors.textPrimary(context),
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NovaColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NovaRadius.xl),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(top: NovaSpacing.s),
              decoration: BoxDecoration(
                color: NovaColors.border(sheetContext),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: NovaSpacing.m),

            // Reply option
            ListTile(
              leading: Icon(Icons.reply, color: NovaColors.textPrimary(sheetContext)),
              title: Text(
                'Rispondi',
                style: NovaTypography.bodyMedium.copyWith(
                  color: NovaColors.textPrimary(sheetContext),
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                onReply?.call();
              },
            ),

            // Report option
            ListTile(
              leading: Icon(Icons.flag_outlined, color: NovaColors.error(sheetContext)),
              title: Text(
                'Segnala',
                style: NovaTypography.bodyMedium.copyWith(
                  color: NovaColors.error(sheetContext),
                ),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                onReport?.call();
              },
            ),

            SizedBox(height: NovaSpacing.m),
          ],
        ),
      ),
    );
  }
}
