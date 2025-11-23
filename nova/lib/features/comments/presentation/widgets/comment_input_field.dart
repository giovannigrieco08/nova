import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../providers/comment_input_notifier.dart';

/// CommentInputField Widget
///
/// Sticky input field at bottom of comments sheet.
/// Platform-adaptive: CupertinoTextField (iOS) vs TextField (Android).
///
/// Features:
/// - Auto-expanding text field (max 4 lines)
/// - Character counter (appears at 450+ chars)
/// - Send button (enabled when text valid and not posting)
/// - Validation (1-500 chars after trim)
/// - Error display (profanity, rate limit, network)
/// - Loading state during posting
///
/// Layout:
/// - Horizontal padding: 12px
/// - Vertical padding: 8px
/// - TextField with send button on right
/// - Character counter below field (conditional)
/// - Error message below counter (conditional)
class CommentInputField extends ConsumerWidget {
  final String eventId;

  const CommentInputField({
    super.key,
    required this.eventId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inputState = ref.watch(commentInputNotifierProvider(eventId));
    final inputNotifier = ref.read(commentInputNotifierProvider(eventId).notifier);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.medium,
        vertical: NovaSpacing.small,
      ),
      decoration: BoxDecoration(
        color: NovaColors.backgroundPrimary(context),
        border: Border(
          top: BorderSide(
            color: NovaColors.dividerLight,
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Input row (text field + send button)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Text field
              Expanded(
                child: Semantics(
                  textField: true,
                  label: 'Campo di testo per scrivere un commento, limite 500 caratteri',
                  hint: 'Aggiungi un commento',
                  enabled: !inputState.isPosting,
                  child: Platform.isIOS
                      ? CupertinoTextField(
                          controller: inputNotifier.textController,
                          placeholder: 'Aggiungi un commento...',
                          placeholderStyle: NovaTypography.bodyMedium.copyWith(
                            color: NovaColors.textTertiaryLight,
                          ),
                          style: NovaTypography.bodyMedium,
                          maxLines: null,
                          minLines: 1,
                          maxLength: 500,
                          textInputAction: TextInputAction.newline,
                          decoration: BoxDecoration(
                            color: NovaColors.backgroundSecondaryLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: NovaColors.dividerLight,
                              width: 1,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: NovaSpacing.medium,
                            vertical: NovaSpacing.small,
                          ),
                          enabled: !inputState.isPosting,
                        )
                      : TextField(
                          controller: inputNotifier.textController,
                          decoration: InputDecoration(
                            hintText: 'Aggiungi un commento...',
                            hintStyle: NovaTypography.bodyMedium.copyWith(
                              color: NovaColors.textTertiaryLight,
                            ),
                            filled: true,
                            fillColor: NovaColors.backgroundSecondaryLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: NovaColors.dividerLight,
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: NovaColors.dividerLight,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: NovaColors.primary,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: NovaSpacing.medium,
                              vertical: NovaSpacing.small,
                            ),
                            counterText: '', // Hide default counter
                          ),
                          style: NovaTypography.bodyMedium,
                          maxLines: null,
                          minLines: 1,
                          maxLength: 500,
                          textInputAction: TextInputAction.newline,
                          enabled: !inputState.isPosting,
                        ),
                ),
              ),

              SizedBox(width: NovaSpacing.small),

              // Send button
              _buildSendButton(context, inputState, inputNotifier),
            ],
          ),

          // Character counter (shown when approaching limit)
          if (inputState.isApproachingLimit) ...[
            SizedBox(height: NovaSpacing.tiny),
            Padding(
              padding: EdgeInsets.only(left: NovaSpacing.small),
              child: Text(
                '${inputState.characterCount}/500',
                style: NovaTypography.labelSmall.copyWith(
                  color: inputState.hasReachedLimit
                      ? NovaColors.error
                      : NovaColors.textTertiaryLight,
                ),
              ),
            ),
          ],

          // Error message
          if (inputState.error != null) ...[
            SizedBox(height: NovaSpacing.tiny),
            Padding(
              padding: EdgeInsets.only(left: NovaSpacing.small),
              child: Text(
                inputState.error!,
                style: NovaTypography.labelSmall.copyWith(
                  color: NovaColors.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSendButton(
    BuildContext context,
    CommentInputState inputState,
    CommentInputNotifier inputNotifier,
  ) {
    if (inputState.isPosting) {
      // Loading indicator
      return Semantics(
        label: 'Invio commento in corso',
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Platform.isIOS
                ? const CupertinoActivityIndicator()
                : const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    // Send button
    return Semantics(
      button: true,
      label: inputState.canSend
          ? 'Invia commento'
          : 'Pulsante invia disabilitato, scrivi un commento per inviare',
      enabled: inputState.canSend,
      child: IconButton(
        onPressed: inputState.canSend ? () => inputNotifier.postComment() : null,
        icon: Icon(
          Platform.isIOS ? CupertinoIcons.arrow_up_circle_fill : Icons.send,
          color: inputState.canSend
              ? NovaColors.primary
              : NovaColors.textTertiaryLight,
        ),
        iconSize: 32,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}
