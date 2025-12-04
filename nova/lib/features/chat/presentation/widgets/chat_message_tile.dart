import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';
import 'package:nova/features/chat/presentation/widgets/chat_reaction_row.dart';
import 'package:nova/features/chat/presentation/widgets/chat_reaction_detail_sheet.dart';
import 'package:nova/features/chat/presentation/widgets/chat_reply_preview.dart';
import 'package:nova/features/chat/presentation/widgets/chat_media_bubble.dart';
import 'package:nova/features/chat/presentation/screens/media_viewer_screen.dart';
import 'package:nova/shared/widgets/avatar_widget.dart';

/// A single message tile in the chat feed.
///
/// Displays:
/// - Author avatar (for others' messages)
/// - Message content with mention highlighting
/// - Swipe left to reveal timestamp (Instagram style)
/// - Reply preview (if replying to another message)
/// - Reaction row with counts
///
/// Supports:
/// - Long-press for context menu (report, react)
/// - Swipe left to reveal timestamp
/// - Tap on reactions to toggle
class ChatMessageTile extends ConsumerStatefulWidget {
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
  ConsumerState<ChatMessageTile> createState() => _ChatMessageTileState();
}

class _ChatMessageTileState extends ConsumerState<ChatMessageTile> {
  double _dragExtent = 0;
  static const double _maxDragExtent = 60;
  static const double _replyThreshold = 50; // Threshold to trigger reply
  bool _replyTriggered = false;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent += details.delta.dx;
      // Allow swipe left (timestamp) and right (reply)
      _dragExtent = _dragExtent.clamp(-_maxDragExtent, _maxDragExtent);
    });

    // Haptic feedback when crossing reply threshold
    if (_dragExtent > _replyThreshold && !_replyTriggered) {
      _replyTriggered = true;
      // Light haptic feedback
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    // Check if swipe right triggered reply
    if (_dragExtent >= _replyThreshold) {
      widget.onReply?.call();
    }

    // Reset state
    _replyTriggered = false;

    // Snap back with animation
    if (_dragExtent < 0 && _dragExtent.abs() >= _maxDragExtent / 2) {
      // Swiped left far enough - show timestamp briefly then snap back
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _dragExtent = 0;
          });
        }
      });
    } else {
      // Snap back immediately
      setState(() {
        _dragExtent = 0;
      });
    }
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeFormat = DateFormat('HH:mm');

    if (messageDate == today) {
      return timeFormat.format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Ieri ${timeFormat.format(dateTime)}';
    } else {
      return DateFormat('dd/MM HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOwnMessage = widget.message.userId == currentUserId;

    // Calculate opacity for timestamp based on drag
    final timestampOpacity = (_dragExtent.abs() / _maxDragExtent).clamp(0.0, 1.0);

    // Calculate opacity for reply icon based on right drag
    final replyIconOpacity = (_dragExtent / _replyThreshold).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: 3,
      ),
      child: GestureDetector(
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: Stack(
          alignment: isOwnMessage ? Alignment.centerRight : Alignment.centerLeft,
          children: [
            // Reply icon (revealed on swipe right)
            if (_dragExtent > 0)
              Positioned(
                left: isOwnMessage ? null : 0,
                right: isOwnMessage ? 0 : null,
                child: AnimatedOpacity(
                  opacity: replyIconOpacity,
                  duration: const Duration(milliseconds: 50),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: NovaColors.primary(context).withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.reply,
                      size: 18,
                      color: NovaColors.primary(context),
                    ),
                  ),
                ),
              ),

            // Timestamp (revealed on swipe left)
            if (_dragExtent < 0)
              Positioned(
                right: isOwnMessage ? 0 : null,
                left: isOwnMessage ? null : 0,
                child: AnimatedOpacity(
                  opacity: timestampOpacity,
                  duration: const Duration(milliseconds: 100),
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: isOwnMessage ? 8 : 0,
                      left: isOwnMessage ? 0 : 8,
                    ),
                    child: Text(
                      _formatTimestamp(widget.message.createdAt),
                      style: NovaTypography.bodySmall.copyWith(
                        color: NovaColors.textTertiary(context),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),

            // Message content (slides on drag)
            AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              transform: Matrix4.translationValues(_dragExtent, 0, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: isOwnMessage
                    ? MainAxisAlignment.end
                    : MainAxisAlignment.start,
                children: [
                  // Avatar (solo per messaggi degli altri)
                  if (!isOwnMessage) ...[
                    AvatarWidget(
                      avatarUrl: widget.message.author.avatarUrl,
                      name: widget.message.author.fullName,
                      size: 28,
                    ),
                    SizedBox(width: NovaSpacing.xs),
                  ],

                  // Message bubble
                  Flexible(
                    child: Column(
                      crossAxisAlignment: isOwnMessage
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        // Message bubble
                        GestureDetector(
                          onLongPress: () => _showContextMenu(context),
                          child: Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.75,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: NovaSpacing.m + 4,
                              vertical: NovaSpacing.s + 2,
                            ),
                            decoration: BoxDecoration(
                              color: isOwnMessage
                                  ? NovaColors.primary(context)
                                  : NovaColors.card(context),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Reply preview
                                if (widget.message.isReply && widget.message.replyTo != null)
                                  Padding(
                                    padding: EdgeInsets.only(bottom: NovaSpacing.xs),
                                    child: ChatReplyPreview(
                                      replyTo: widget.message.replyTo!,
                                      onTap: widget.onTapReplyPreview,
                                      isCompact: true,
                                    ),
                                  ),

                                // Message content
                                _buildMessageContent(context, isOwnMessage),
                              ],
                            ),
                          ),
                        ),

                        // Reactions row
                        if (widget.message.reactionCounts.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: NovaSpacing.xxs),
                            child: ChatReactionRow(
                              messageId: widget.message.id,
                              reactionCounts: widget.message.reactionCounts,
                              currentUserReactions: widget.message.currentUserReactions,
                              onTap: widget.onReact,
                              onLongPress: () => ChatReactionDetailSheet.show(
                                context,
                                messageId: widget.message.id,
                                reactionCounts: widget.message.reactionCounts,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, bool isOwnMessage) {
    // Text color: white on purple (own), dark on gray (others)
    final textColor = isOwnMessage
        ? Colors.white
        : NovaColors.textPrimary(context);

    if (widget.message.isHidden) {
      return Text(
        widget.message.displayContent,
        style: NovaTypography.bodyMedium.copyWith(
          color: isOwnMessage
              ? Colors.white70
              : NovaColors.textTertiary(context),
          fontStyle: FontStyle.italic,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    // Show media bubble if message has media
    if (widget.message.hasMedia && widget.message.media != null) {
      return ChatMediaBubble(
        media: widget.message.media!,
        isOwnMessage: isOwnMessage,
        onTap: () => _openMediaViewer(context, widget.message.media!),
      );
    }

    // Skip empty or space-only content (media placeholder)
    final trimmedContent = widget.message.content.trim();
    if (trimmedContent.isEmpty) {
      // This shouldn't happen normally, but show loading indicator as fallback
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: isOwnMessage ? Colors.white70 : NovaColors.primary(context),
        ),
      );
    }

    // For messages with mentions, highlight them
    if (widget.message.hasMentions) {
      return _buildHighlightedContent(context, isOwnMessage);
    }

    return Text(
      widget.message.content,
      style: NovaTypography.bodyMedium.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700, // Bold for chat bubbles
      ),
    );
  }

  Widget _buildHighlightedContent(BuildContext context, bool isOwnMessage) {
    final content = widget.message.content;
    final mentions = widget.message.mentions;

    // Text colors based on bubble background
    final textColor = isOwnMessage
        ? Colors.white
        : NovaColors.textPrimary(context);
    final mentionColor = isOwnMessage
        ? Colors.white70
        : NovaColors.primary(context);

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
            color: textColor,
            fontWeight: FontWeight.w700, // Bold for chat bubbles
          ),
        ));
      }

      // Add highlighted mention
      spans.add(TextSpan(
        text: content.substring(mention.startIndex, mention.endIndex),
        style: NovaTypography.bodyMedium.copyWith(
          color: mentionColor,
          fontWeight: FontWeight.w700, // Bold for mentions
        ),
      ));

      currentIndex = mention.endIndex;
    }

    // Add remaining text
    if (currentIndex < content.length) {
      spans.add(TextSpan(
        text: content.substring(currentIndex),
        style: NovaTypography.bodyMedium.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700, // Bold for chat bubbles
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// Allowed emoji reactions (matches database constraint)
  static const List<String> _allowedEmojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

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

            // Reaction picker row
            Padding(
              padding: EdgeInsets.symmetric(horizontal: NovaSpacing.l),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _allowedEmojis.map((emoji) {
                  final hasReacted = widget.message.currentUserReactions.contains(emoji);
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(sheetContext);
                      widget.onReact?.call(emoji);
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: hasReacted
                            ? NovaColors.primary(sheetContext).withOpacity(0.15)
                            : NovaColors.card(sheetContext),
                        shape: BoxShape.circle,
                        border: hasReacted
                            ? Border.all(
                                color: NovaColors.primary(sheetContext),
                                width: 2,
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 22),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            SizedBox(height: NovaSpacing.m),
            Divider(height: 1, color: NovaColors.border(sheetContext)),

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
                widget.onReply?.call();
              },
            ),

            // Report option (only for others' messages)
            if (widget.message.userId != ref.read(currentUserIdProvider))
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
                  widget.onReport?.call();
                },
              ),

            SizedBox(height: NovaSpacing.m),
          ],
        ),
      ),
    );
  }

  /// Open media viewer to display the ephemeral media
  Future<void> _openMediaViewer(BuildContext context, ChatMediaInfo media) async {
    // Check if media can still be viewed
    if (!media.canView) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            media.isExpired
                ? 'Questo media è scaduto'
                : 'Questo media non è più disponibile',
          ),
          backgroundColor: NovaColors.warning(context),
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // Fetch signed URL
      final repository = ref.read(chatRepositoryProvider);
      final signedUrl = await repository.getSignedMediaUrl(media.id);

      // Dismiss loading indicator
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (signedUrl == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Impossibile caricare il media'),
              backgroundColor: NovaColors.error(context),
            ),
          );
        }
        return;
      }

      // Navigate to media viewer
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (navContext) => MediaViewerScreen(
              media: media,
              signedUrl: signedUrl,
            ),
          ),
        );
      }
    } catch (e) {
      // Dismiss loading indicator
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Errore nel caricamento del media'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }
}
