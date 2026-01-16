import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/providers/core_providers.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/chat/domain/repositories/chat_repository.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';
import 'package:nova/features/chat/presentation/widgets/chat_reaction_row.dart';
import 'package:nova/features/chat/presentation/widgets/chat_reaction_detail_sheet.dart';
import 'package:nova/features/chat/presentation/widgets/chat_reply_preview.dart';
import 'package:nova/features/chat/presentation/widgets/chat_media_bubble.dart';
import 'package:nova/features/chat/presentation/widgets/chat_message_context_overlay.dart';
import 'package:nova/features/chat/presentation/widgets/link_preview_bubble.dart';
import 'package:nova/features/chat/presentation/widgets/edit_message_dialog.dart';
import 'package:nova/features/chat/presentation/widgets/gif_picker.dart';
import 'package:nova/features/chat/presentation/screens/media_viewer_screen.dart';
import 'package:nova/shared/widgets/avatar_widget.dart';
import 'package:nova/core/animations/page_transitions.dart';

/// A single message tile in the chat feed.
///
/// Displays:
/// - Author avatar (for others' messages)
/// - Message content with mention highlighting
/// - Reply preview (if replying to another message)
/// - Reaction row with counts
///
/// Supports:
/// - Long-press for context menu (report, react)
/// - Swipe right to reply (with spring animation and haptic feedback)
/// - Double-tap to add heart reaction
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

class _ChatMessageTileState extends ConsumerState<ChatMessageTile>
    with SingleTickerProviderStateMixin {
  double _dragExtent = 0;
  static const double _maxDragExtent = 80;
  static const double _replyThreshold = 60; // Threshold to trigger reply
  static const double _edgeSwipeThreshold = 30; // Left edge zone for back navigation
  bool _replyTriggered = false;
  bool _isDragActive = false; // Track if we should handle this drag
  double? _dragStartX; // Track where the drag started

  late AnimationController _animationController;
  late Animation<double> _snapBackAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animationController.addListener(_onAnimationTick);
  }

  @override
  void dispose() {
    _animationController.removeListener(_onAnimationTick);
    _animationController.dispose();
    super.dispose();
  }

  void _onAnimationTick() {
    setState(() {
      _dragExtent = _snapBackAnimation.value;
    });
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
    // Only handle drags that don't start from the left edge (allow back navigation)
    _isDragActive = _dragStartX! > _edgeSwipeThreshold;
    // Stop any running animation
    if (_isDragActive && _animationController.isAnimating) {
      _animationController.stop();
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // Ignore drags that started from the edge (for back navigation)
    if (!_isDragActive) return;
    setState(() {
      _dragExtent += details.delta.dx;
      // Only allow swipe right (reply) - remove left swipe
      _dragExtent = _dragExtent.clamp(0.0, _maxDragExtent);
    });

    // Haptic feedback when crossing reply threshold
    if (_dragExtent > _replyThreshold && !_replyTriggered) {
      _replyTriggered = true;
      HapticFeedback.mediumImpact();
    } else if (_dragExtent <= _replyThreshold && _replyTriggered) {
      // Reset if user drags back below threshold
      _replyTriggered = false;
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    // Ignore drags that started from the edge (for back navigation)
    if (!_isDragActive) {
      _resetDragState();
      return;
    }

    // Check if swipe right triggered reply
    if (_dragExtent >= _replyThreshold) {
      HapticFeedback.lightImpact();
      widget.onReply?.call();
    }

    // Animate snap back with spring curve
    _snapBackAnimation = Tween<double>(
      begin: _dragExtent,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _animationController.forward(from: 0.0);
    _resetDragState();
  }

  void _resetDragState() {
    _isDragActive = false;
    _dragStartX = null;
    _replyTriggered = false;
  }

  /// Handle double-tap for quick react (heart emoji)
  void _handleDoubleTap(BuildContext context) {
    // Haptic feedback
    HapticFeedback.lightImpact();

    // Toggle heart reaction (no animation - just add/remove the reaction)
    const heartEmoji = '❤️';
    widget.onReact?.call(heartEmoji);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOwnMessage = widget.message.userId == currentUserId;

    // Calculate opacity and scale for reply icon based on right drag
    final replyIconOpacity = (_dragExtent / _replyThreshold).clamp(0.0, 1.0);
    final replyIconScale = 0.5 + (replyIconOpacity * 0.5); // Scale from 0.5 to 1.0
    final isTriggered = _dragExtent >= _replyThreshold;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: 3,
      ),
      child: GestureDetector(
        onHorizontalDragStart: _onHorizontalDragStart,
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
                child: Transform.scale(
                  scale: replyIconScale,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isTriggered
                          ? NovaColors.primary(context)
                          : NovaColors.primary(context).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.reply,
                      size: 20,
                      color: isTriggered
                          ? Colors.white
                          : NovaColors.primary(context),
                    ),
                  ),
                ),
              ),

            // Message content (slides on drag with smooth transform)
            Transform.translate(
              offset: Offset(_dragExtent, 0),
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
                        // Reply preview (Instagram style - ABOVE the bubble)
                        if (widget.message.isReply && widget.message.replyTo != null)
                          Padding(
                            padding: EdgeInsets.only(bottom: NovaSpacing.xxs),
                            child: ChatReplyPreview(
                              replyTo: widget.message.replyTo!,
                              onTap: widget.onTapReplyPreview,
                              isCompact: true,
                              currentUserId: currentUserId,
                              isOwnMessage: isOwnMessage,
                            ),
                          ),

                        // GIF message: show GifBubble directly
                        if (widget.message.isGif && widget.message.gifUrl != null)
                          GestureDetector(
                            onDoubleTap: () => _handleDoubleTap(context),
                            onLongPress: () => _showContextMenu(context),
                            child: GifBubble(
                              gifUrl: widget.message.gifUrl!,
                              isOwnMessage: isOwnMessage,
                            ),
                          )
                        // Media message: show ChatMediaBubble directly (no wrapper bubble)
                        else if (widget.message.hasMedia && widget.message.media != null)
                          Column(
                            crossAxisAlignment: isOwnMessage
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onDoubleTap: () => _handleDoubleTap(context),
                                onLongPress: () => _showContextMenu(context),
                                // Audio plays inline - don't open MediaViewerScreen
                                // Images/videos open full-screen viewer
                                onTap: widget.message.media!.mediaType.isAudio
                                    ? null  // Audio: no tap handler (plays inline in bubble)
                                    : () => _openMediaViewer(context, widget.message.media!),
                                child: ChatMediaBubble(
                                  media: widget.message.media!,
                                  isOwnMessage: isOwnMessage,
                                ),
                              ),
                              // Caption for media (if provided)
                              if (widget.message.mediaCaption != null &&
                                  widget.message.mediaCaption!.isNotEmpty)
                                Container(
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                                  ),
                                  margin: EdgeInsets.only(top: NovaSpacing.xxs),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: NovaSpacing.s,
                                    vertical: NovaSpacing.xxs,
                                  ),
                                  child: Text(
                                    widget.message.mediaCaption!,
                                    style: NovaTypography.bodyMedium.copyWith(
                                      color: isOwnMessage
                                          ? NovaColors.textPrimary(context)
                                          : NovaColors.textPrimary(context),
                                    ),
                                    textAlign: isOwnMessage ? TextAlign.right : TextAlign.left,
                                  ),
                                ),
                            ],
                          )
                        // Text message: show in normal bubble
                        else
                          GestureDetector(
                            onDoubleTap: () => _handleDoubleTap(context),
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
                                borderRadius: NovaRadius.circularL,
                              ),
                              child: _buildMessageContent(context, isOwnMessage),
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
        ),
      );
    }

    // Note: Media messages are now handled separately in the layout
    // This method only handles text content

    // Skip media placeholder content
    final trimmedContent = widget.message.content.trim();
    if (trimmedContent.isEmpty || trimmedContent == '[media]') {
      return const SizedBox.shrink();
    }

    // Check for URL in message content
    final extractedUrl = LinkPreviewBubble.extractUrl(widget.message.content);
    final hasLinkPreview = LinkPreviewBubble.isValidUrl(extractedUrl);

    // For messages with mentions, highlight them
    Widget textWidget;
    if (widget.message.hasMentions) {
      textWidget = _buildHighlightedContent(context, isOwnMessage);
    } else {
      textWidget = Text(
        widget.message.content,
        style: NovaTypography.bodyMedium.copyWith(
          color: textColor,
        ),
      );
    }

    // Build the content widget
    Widget contentWidget = textWidget;

    // Add link preview if URL found
    if (hasLinkPreview && extractedUrl != null) {
      contentWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          textWidget,
          LinkPreviewBubble(
            url: extractedUrl,
            isOwnMessage: isOwnMessage,
          ),
        ],
      );
    }

    // Add edited indicator if message was edited
    if (widget.message.isEdited) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          contentWidget,
          SizedBox(height: NovaSpacing.xxs),
          Text(
            'modificato',
            style: NovaTypography.bodySmall.copyWith(
              color: isOwnMessage
                  ? Colors.white60
                  : NovaColors.textTertiary(context),
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      );
    }

    return contentWidget;
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
          ),
        ));
      }

      // Add highlighted mention
      spans.add(TextSpan(
        text: content.substring(mention.startIndex, mention.endIndex),
        style: NovaTypography.bodyMedium.copyWith(
          color: mentionColor,
          fontWeight: FontWeight.w600, // SemiBold for mentions
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
        ),
      ));
    }

    return RichText(text: TextSpan(children: spans));
  }

  void _showContextMenu(BuildContext context) {
    final currentUserId = ref.read(currentUserIdProvider);
    final isOwnMessage = widget.message.userId == currentUserId;

    // Build the message bubble to display in overlay
    final messageBubble = _buildMessageBubbleForOverlay(context, isOwnMessage);

    // Only show delete option if message can be deleted (within 30 minutes)
    final canDelete = isOwnMessage && widget.message.canDelete;

    // Only show edit option if message can be edited (within 5 minutes)
    final canEdit = isOwnMessage && widget.message.canEdit && !widget.message.hasMedia;

    // Don't show copy option for audio messages (can't copy audio)
    final isAudioMessage = widget.message.hasMedia &&
        widget.message.media?.mediaType.isAudio == true;

    ChatMessageContextOverlay.show(
      context,
      messageBubble: messageBubble,
      isOwnMessage: isOwnMessage,
      currentUserReactions: widget.message.currentUserReactions,
      onReact: widget.onReact,
      onReply: widget.onReply,
      onReport: widget.onReport,
      messageContent: isAudioMessage ? null : widget.message.content,
      onDelete: canDelete ? () => _deleteMessage(context) : null,
      onEdit: canEdit ? () => _editMessage(context) : null,
      canEdit: canEdit,
    );
  }

  Future<void> _deleteMessage(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: NovaColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: NovaRadius.circularM,
        ),
        title: Text(
          'Elimina messaggio',
          style: NovaTypography.headingSmall.copyWith(
            color: NovaColors.textPrimary(context),
          ),
        ),
        content: Text(
          'Vuoi eliminare questo messaggio? Questa azione non può essere annullata.',
          style: NovaTypography.bodyMedium.copyWith(
            color: NovaColors.textSecondary(context),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              'Annulla',
              style: TextStyle(color: NovaColors.textSecondary(context)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Elimina',
              style: TextStyle(color: NovaColors.error(context)),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(chatRepositoryProvider);
      await repository.deleteMessage(widget.message.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Messaggio eliminato'),
            backgroundColor: NovaColors.textSecondary(context),
          ),
        );
      }
    } on ChatDeleteNotAllowedException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Errore nell\'eliminazione del messaggio'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }

  Future<void> _editMessage(BuildContext context) async {
    await EditMessageDialog.show(
      context,
      message: widget.message,
      onSave: (newContent) async {
        try {
          await ref.read(editMessageProvider((
            messageId: widget.message.id,
            newContent: newContent,
          )).future);

          // Refresh the messages list
          ref.invalidate(chatMessagesStreamProvider);
          return true;
        } on ChatEditNotAllowedException catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e.message),
                backgroundColor: NovaColors.error(context),
              ),
            );
          }
          return false;
        } catch (e) {
          return false;
        }
      },
    );
  }

  /// Build a standalone message bubble for the context overlay
  Widget _buildMessageBubbleForOverlay(BuildContext context, bool isOwnMessage) {
    final currentUserId = ref.read(currentUserIdProvider);

    // For GIF messages, show the GIF bubble
    if (widget.message.isGif && widget.message.gifUrl != null) {
      return Column(
        crossAxisAlignment: isOwnMessage
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview (Instagram style - ABOVE the bubble)
          if (widget.message.isReply && widget.message.replyTo != null)
            Padding(
              padding: EdgeInsets.only(bottom: NovaSpacing.xxs),
              child: ChatReplyPreview(
                replyTo: widget.message.replyTo!,
                isCompact: true,
                currentUserId: currentUserId,
                isOwnMessage: isOwnMessage,
              ),
            ),
          GifBubble(
            gifUrl: widget.message.gifUrl!,
            isOwnMessage: isOwnMessage,
          ),
        ],
      );
    }

    // For media messages, show the media bubble
    if (widget.message.hasMedia && widget.message.media != null) {
      return Column(
        crossAxisAlignment: isOwnMessage
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reply preview (Instagram style - ABOVE the bubble)
          if (widget.message.isReply && widget.message.replyTo != null)
            Padding(
              padding: EdgeInsets.only(bottom: NovaSpacing.xxs),
              child: ChatReplyPreview(
                replyTo: widget.message.replyTo!,
                isCompact: true,
                currentUserId: currentUserId,
                isOwnMessage: isOwnMessage,
              ),
            ),
          ChatMediaBubble(
            media: widget.message.media!,
            isOwnMessage: isOwnMessage,
          ),
        ],
      );
    }

    // For text messages, show the text bubble with reply above
    return Column(
      crossAxisAlignment: isOwnMessage
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reply preview (Instagram style - ABOVE the bubble)
        if (widget.message.isReply && widget.message.replyTo != null)
          Padding(
            padding: EdgeInsets.only(bottom: NovaSpacing.xxs),
            child: ChatReplyPreview(
              replyTo: widget.message.replyTo!,
              isCompact: true,
              currentUserId: currentUserId,
              isOwnMessage: isOwnMessage,
            ),
          ),
        Container(
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
            borderRadius: NovaRadius.circularL,
          ),
          child: _buildMessageContent(context, isOwnMessage),
        ),
      ],
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
          NovaPageRoute.swipeBack(
            page: MediaViewerScreen(
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
