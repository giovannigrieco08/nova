import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';
import 'package:nova/features/chat/presentation/widgets/chat_message_tile.dart';
import 'package:nova/features/chat/presentation/widgets/chat_animations.dart';
import 'package:nova/features/chat/presentation/widgets/failed_message_tile.dart';

/// Scrollable list of chat messages.
///
/// Features:
/// - Reverse scroll (newest at bottom)
/// - Pull-to-refresh
/// - Infinite scroll for older messages
/// - Scroll-to-bottom FAB
/// - Empty state
/// - Failed messages with retry
/// - Animated message appearance (slide + fade)
/// - RepaintBoundary for performance
class ChatMessageList extends ConsumerStatefulWidget {
  final List<ChatMessage> messages;
  final List<FailedMessage> failedMessages;
  final bool isLoading;
  final bool hasMore;
  final VoidCallback? onLoadMore;
  final VoidCallback? onRefresh;
  final void Function(ChatMessage message)? onReply;
  final void Function(ChatMessage message)? onReport;
  final void Function(ChatMessage message, String emoji)? onReact;
  final void Function(String messageId)? onScrollToMessage;

  const ChatMessageList({
    super.key,
    required this.messages,
    this.failedMessages = const [],
    this.isLoading = false,
    this.hasMore = false,
    this.onLoadMore,
    this.onRefresh,
    this.onReply,
    this.onReport,
    this.onReact,
    this.onScrollToMessage,
  });

  @override
  ConsumerState<ChatMessageList> createState() => _ChatMessageListState();
}

class _ChatMessageListState extends ConsumerState<ChatMessageList> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;
  Set<String> _animatedMessageIds = {};  // Track which messages have been animated

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Show scroll-to-bottom button when scrolled up
    final showButton = _scrollController.offset > 200;
    if (showButton != _showScrollToBottom) {
      setState(() => _showScrollToBottom = showButton);
    }

    // Load more when near top (remember: reversed list)
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (widget.hasMore && !widget.isLoading) {
        widget.onLoadMore?.call();
      }
    }
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void scrollToMessage(String messageId) {
    final index = widget.messages.indexWhere((m) => m.id == messageId);
    if (index >= 0) {
      // Calculate approximate position (reversed list)
      const itemHeight = 80.0; // Approximate message height
      final position = index * itemHeight;

      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty && widget.failedMessages.isEmpty && !widget.isLoading) {
      return _buildEmptyState(context);
    }

    // Total items: failed messages + regular messages + loading indicator
    final failedCount = widget.failedMessages.length;
    final messageCount = widget.messages.length;
    final totalCount = failedCount + messageCount + (widget.isLoading ? 1 : 0);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () async => widget.onRefresh?.call(),
          color: NovaColors.primary(context),
          child: ListView.builder(
            controller: _scrollController,
            reverse: true, // Newest at bottom
            padding: EdgeInsets.symmetric(vertical: NovaSpacing.m),
            itemCount: totalCount,
            // Pre-cache items for smoother scrolling
            cacheExtent: 500,
            itemBuilder: (context, index) {
              // Failed messages appear first (at bottom in reversed list)
              if (index < failedCount) {
                final failedMessage = widget.failedMessages[index];
                return FailedMessageTile(
                  key: ValueKey('failed_${failedMessage.id}'),
                  failedMessage: failedMessage,
                );
              }

              // Adjust index for regular messages
              final messageIndex = index - failedCount;

              // Loading indicator at top (end of reversed list)
              if (widget.isLoading && messageIndex == messageCount) {
                return Padding(
                  padding: EdgeInsets.all(NovaSpacing.m),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: NovaColors.primary(context),
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              final message = widget.messages[messageIndex];

              // Check if this message should be animated (only new messages)
              final shouldAnimate = !_animatedMessageIds.contains(message.id);
              if (shouldAnimate) {
                _animatedMessageIds.add(message.id);
              }

              // Wrap with RepaintBoundary for performance
              return RepaintBoundary(
                child: AnimatedMessageTile(
                  key: ValueKey('animated_${message.id}'),
                  animate: shouldAnimate && messageIndex < 5,  // Only animate first 5 new messages
                  index: messageIndex,
                  child: ChatMessageTile(
                    key: ValueKey(message.id),
                    message: message,
                    onReply: () => widget.onReply?.call(message),
                    onReport: () => widget.onReport?.call(message),
                    onReact: (emoji) => widget.onReact?.call(message, emoji),
                    onTapReplyPreview: message.replyToId != null
                        ? () => scrollToMessage(message.replyToId!)
                        : null,
                  ),
                ),
              );
            },
          ),
        ),

        // Scroll to bottom FAB
        if (_showScrollToBottom)
          Positioned(
            right: NovaSpacing.m,
            bottom: NovaSpacing.m,
            child: FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: NovaColors.card(context),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: NovaColors.textPrimary(context),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: NovaColors.textTertiary(context),
            ),
            SizedBox(height: NovaSpacing.m),
            Text(
              'Nessun messaggio',
              style: NovaTypography.headingSmall.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.xs),
            Text(
              'Inizia la conversazione!',
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textTertiary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
