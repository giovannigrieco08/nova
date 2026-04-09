import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/repositories/chat_repository.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';
import 'package:nova/features/chat/presentation/widgets/mention_autocomplete.dart';
import 'package:nova/features/safety/presentation/providers/content_filter_provider.dart';
import 'package:nova/features/safety/presentation/screens/tos_acceptance_screen.dart';

/// Text input row for the compose bar.
///
/// Manages text editing, @mention detection/autocomplete, and the send action.
/// Media buttons (camera, mic, gallery) are passed in via [trailing] so the
/// parent keeps control over which buttons appear.
class ComposeTextInput extends ConsumerStatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool showEmojiPicker;
  final VoidCallback onToggleEmojiPicker;
  final VoidCallback? onSent;

  /// Widgets shown to the right of the text input when the field is empty
  /// (e.g. microphone + gallery icons).
  final List<Widget> trailing;

  const ComposeTextInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.showEmojiPicker,
    required this.onToggleEmojiPicker,
    this.onSent,
    this.trailing = const [],
  });

  @override
  ConsumerState<ComposeTextInput> createState() => _ComposeTextInputState();
}

class _ComposeTextInputState extends ConsumerState<ComposeTextInput> {
  int? _mentionStartIndex;
  final List<Map<String, dynamic>> _selectedMentions = [];

  static const int _maxCharacters = 500;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Text / mention logic
  // ---------------------------------------------------------------------------

  void _onTextChanged() {
    final text = widget.controller.text;
    ref.read(composeStateProvider.notifier).updateContent(text);

    // UGC Safety: Check content for banned words (T075)
    ref
        .read(contentCheckNotifierProvider.notifier)
        .checkWithDebounce(text);

    _checkMentionTrigger(text);
  }

  void _checkMentionTrigger(String text) {
    final cursorPosition = widget.controller.selection.baseOffset;
    if (cursorPosition < 0) return;

    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex >= 0) {
      final textAfterAt = textBeforeCursor.substring(lastAtIndex + 1);
      if (!textAfterAt.contains(' ')) {
        _mentionStartIndex = lastAtIndex;
        ref.read(composeStateProvider.notifier).searchMentions(textAfterAt);
        return;
      }
    }

    _mentionStartIndex = null;
    ref.read(composeStateProvider.notifier).hideMentionPicker();
  }

  void _onMentionSelected(MentionSearchResult result) {
    if (_mentionStartIndex == null) return;

    final text = widget.controller.text;
    final cursorPosition = widget.controller.selection.baseOffset;

    final beforeMention = text.substring(0, _mentionStartIndex!);
    final afterCursor =
        cursorPosition < text.length ? text.substring(cursorPosition) : '';
    final mentionText = '@${result.fullName} ';
    final newText = beforeMention + mentionText + afterCursor;

    _selectedMentions.add({
      'user_id': result.userId,
      'username': result.fullName,
      'start_index': _mentionStartIndex!,
      'end_index': _mentionStartIndex! + mentionText.length - 1,
    });

    widget.controller.text = newText;
    widget.controller.selection = TextSelection.collapsed(
      offset: beforeMention.length + mentionText.length,
    );

    _mentionStartIndex = null;
    ref.read(composeStateProvider.notifier).hideMentionPicker();
  }

  // ---------------------------------------------------------------------------
  // Send
  // ---------------------------------------------------------------------------

  Future<void> _sendMessage() async {
    final state = ref.read(composeStateProvider);
    if (state.content.trim().isEmpty || state.isSending) return;

    // UGC Safety: Check ToS acceptance before sending (T057)
    final tosAccepted = await showTosAcceptanceIfNeeded(context, ref);
    if (!tosAccepted) return;

    final messageMentions = List<Map<String, dynamic>>.from(_selectedMentions);

    final success = await ref.read(composeStateProvider.notifier).sendMessage(
          mentions: messageMentions,
        );

    if (success) {
      widget.controller.clear();
      _selectedMentions.clear();
      widget.onSent?.call();
    } else {
      final error = ref.read(composeStateProvider).error;
      if (error != null &&
          !error.contains('rate limit') &&
          !error.contains('linguaggio') &&
          !error.contains('offensiv')) {
        ref.read(failedMessagesProvider.notifier).addFailedMessage(
              content: state.content.trim(),
              mentions: messageMentions,
              replyToId: state.replyToId,
              errorMessage: error,
            );

        widget.controller.clear();
        _selectedMentions.clear();
        ref.read(composeStateProvider.notifier).clearError();
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(composeStateProvider);
    final characterCount = state.content.length;
    final isOverLimit = characterCount > _maxCharacters;
    final contentCheckState = ref.watch(contentCheckNotifierProvider);
    final isContentBlocked = contentCheckState.isBlocked;
    final canSend = state.content.trim().isNotEmpty &&
        !isOverLimit &&
        !state.isSending &&
        !isContentBlocked;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mention autocomplete
        if (state.isShowingMentionPicker && state.mentionResults.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: NovaSpacing.m,
              vertical: NovaSpacing.xs,
            ),
            child: MentionAutocomplete(
              results: state.mentionResults,
              onSelect: _onMentionSelected,
            ),
          ),

        // Input row
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.s,
            vertical: NovaSpacing.xs,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Text input field
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: NovaColors.card(context),
                    borderRadius: NovaRadius.circularXl,
                    border: Border.all(
                      color: NovaColors.border(context),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          focusNode: widget.focusNode,
                          maxLines: 4,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          onTap: () {
                            if (widget.showEmojiPicker) {
                              widget.onToggleEmojiPicker();
                            }
                          },
                          style: NovaTypography.bodyMedium.copyWith(
                            color: NovaColors.textPrimary(context),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Messaggio...',
                            hintStyle: NovaTypography.bodyMedium.copyWith(
                              color: NovaColors.textTertiary(context),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: NovaSpacing.s,
                              vertical: NovaSpacing.s,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                      // Send button (when typing)
                      if (state.content.isNotEmpty) ...[
                        Padding(
                          padding: EdgeInsets.only(right: NovaSpacing.xs),
                          child: state.isSending
                              ? Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: NovaColors.primary(context),
                                    ),
                                  ),
                                )
                              : TextButton(
                                  onPressed: canSend ? _sendMessage : null,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    minimumSize: const Size(0, 36),
                                  ),
                                  child: Text(
                                    'Invia',
                                    style: NovaTypography.bodyMedium.copyWith(
                                      color: canSend
                                          ? NovaColors.primary(context)
                                          : NovaColors.textTertiary(context),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Trailing icons (mic, gallery) when not typing
              if (state.content.isEmpty) ...widget.trailing,
            ],
          ),
        ),

        // Character counter (near limit)
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
    );
  }
}
