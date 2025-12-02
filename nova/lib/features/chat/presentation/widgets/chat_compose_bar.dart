import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';
import 'package:nova/features/chat/presentation/widgets/chat_reply_preview.dart';

/// Compose bar for sending chat messages.
///
/// Features:
/// - Text input with character counter (max 500)
/// - Reply preview with dismiss
/// - Send button with loading state
/// - @mention detection and autocomplete trigger
class ChatComposeBar extends ConsumerStatefulWidget {
  final ChatMessage? replyTo;
  final VoidCallback? onCancelReply;
  final VoidCallback? onSent;

  const ChatComposeBar({
    super.key,
    this.replyTo,
    this.onCancelReply,
    this.onSent,
  });

  @override
  ConsumerState<ChatComposeBar> createState() => _ChatComposeBarState();
}

class _ChatComposeBarState extends ConsumerState<ChatComposeBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  static const int _maxCharacters = 500;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    ref.read(composeStateProvider.notifier).updateContent(text);

    // Check for @mention trigger
    _checkMentionTrigger(text);
  }

  void _checkMentionTrigger(String text) {
    final cursorPosition = _controller.selection.baseOffset;
    if (cursorPosition < 0) return;

    // Find the last @ before cursor
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex >= 0) {
      // Check if we're still in a mention (no space after @)
      final textAfterAt = textBeforeCursor.substring(lastAtIndex + 1);
      if (!textAfterAt.contains(' ')) {
        // Trigger mention search
        ref.read(composeStateProvider.notifier).searchMentions(textAfterAt);
        return;
      }
    }

    // Hide mention picker if not in mention
    ref.read(composeStateProvider.notifier).hideMentionPicker();
  }

  Future<void> _sendMessage() async {
    final state = ref.read(composeStateProvider);
    if (state.content.trim().isEmpty || state.isSending) return;

    // Extract mentions from content
    final mentions = _extractMentions(state.content);

    final success = await ref.read(composeStateProvider.notifier).sendMessage(
          mentions: mentions,
        );

    if (success) {
      _controller.clear();
      widget.onSent?.call();
    }
  }

  List<Map<String, dynamic>> _extractMentions(String content) {
    // This is a simplified version - full implementation would track
    // mentions as they're selected from autocomplete
    final mentions = <Map<String, dynamic>>[];
    final mentionRegex = RegExp(r'@(\w+)');

    for (final match in mentionRegex.allMatches(content)) {
      mentions.add({
        'user_id': '', // Would be populated from autocomplete selection
        'username': match.group(1),
        'start_index': match.start,
        'end_index': match.end,
      });
    }

    return mentions;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(composeStateProvider);
    final characterCount = state.content.length;
    final isOverLimit = characterCount > _maxCharacters;
    final canSend =
        state.content.trim().isNotEmpty && !isOverLimit && !state.isSending;

    return Container(
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        border: Border(
          top: BorderSide(color: NovaColors.border(context)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reply preview
            if (widget.replyTo != null)
              Container(
                padding: EdgeInsets.fromLTRB(
                  NovaSpacing.m,
                  NovaSpacing.s,
                  NovaSpacing.m,
                  0,
                ),
                child: ChatReplyPreview(
                  replyTo: widget.replyTo!,
                  onDismiss: widget.onCancelReply,
                ),
              ),

            // Error message
            if (state.error != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.m,
                  vertical: NovaSpacing.xs,
                ),
                color: NovaColors.error(context).withOpacity(0.1),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: NovaColors.error(context),
                    ),
                    SizedBox(width: NovaSpacing.xs),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: NovaTypography.bodySmall.copyWith(
                          color: NovaColors.error(context),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () =>
                          ref.read(composeStateProvider.notifier).clearError(),
                      color: NovaColors.error(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                    ),
                  ],
                ),
              ),

            // Input row
            Padding(
              padding: EdgeInsets.all(NovaSpacing.s),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Text input
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: NovaColors.card(context),
                        borderRadius: BorderRadius.circular(NovaRadius.xl),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            maxLines: 4,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            style: NovaTypography.bodyMedium.copyWith(
                              color: NovaColors.textPrimary(context),
                            ),
                            decoration: InputDecoration(
                              hintText: 'Scrivi un messaggio...',
                              hintStyle: NovaTypography.bodyMedium.copyWith(
                                color: NovaColors.textTertiary(context),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: NovaSpacing.m,
                                vertical: NovaSpacing.s,
                              ),
                            ),
                          ),

                          // Character counter
                          if (characterCount > _maxCharacters - 50)
                            Padding(
                              padding: EdgeInsets.only(
                                right: NovaSpacing.m,
                                bottom: NovaSpacing.xs,
                              ),
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '$characterCount / $_maxCharacters',
                                  style: NovaTypography.bodySmall.copyWith(
                                    color: isOverLimit
                                        ? NovaColors.error(context)
                                        : NovaColors.textTertiary(context),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(width: NovaSpacing.s),

                  // Send button
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      onPressed: canSend ? _sendMessage : null,
                      icon: state.isSending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: NovaColors.primary(context),
                              ),
                            )
                          : Icon(
                              Icons.send,
                              color: canSend
                                  ? NovaColors.primary(context)
                                  : NovaColors.textTertiary(context),
                            ),
                      style: IconButton.styleFrom(
                        backgroundColor: canSend
                            ? NovaColors.primary(context).withOpacity(0.1)
                            : Colors.transparent,
                      ),
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
}
