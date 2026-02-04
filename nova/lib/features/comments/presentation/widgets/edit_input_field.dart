import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io' show Platform;

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../providers/edit_comment_provider.dart';

/// EditInputField Widget
///
/// Input field for editing comments. Replaces the normal input when in edit mode.
///
/// **T106**: Edit mode UI in CommentsSheet
/// **T107**: Save handler with validation
/// **T110**: Error handling and display
///
/// Features:
/// - Pre-filled with original comment text
/// - Character counter (500 limit)
/// - Save button (enabled when text valid and changed)
/// - Cancel via header (not here - handled by parent)
/// - Error display
/// - Loading state during save
///
/// Layout similar to CommentInputField but with different styling (orange accent)
class EditInputField extends ConsumerStatefulWidget {
  final String eventId;
  final VoidCallback? onSaveSuccess;

  const EditInputField({
    super.key,
    required this.eventId,
    this.onSaveSuccess,
  });

  @override
  ConsumerState<EditInputField> createState() => _EditInputFieldState();
}

class _EditInputFieldState extends ConsumerState<EditInputField> {
  late TextEditingController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editState = ref.watch(editCommentNotifierProvider(widget.eventId));
    final editNotifier =
        ref.read(editCommentNotifierProvider(widget.eventId).notifier);

    // Initialize controller with original text when edit mode starts
    if (editState.isEditing && !_initialized) {
      _controller.text = editState.currentText;
      _initialized = true;
    } else if (!editState.isEditing && _initialized) {
      _controller.clear();
      _initialized = false;
    }

    // Update notifier when text changes
    _controller.addListener(() {
      if (_initialized && editState.isEditing) {
        final text = _controller.text;
        if (text != editState.currentText) {
          editNotifier.updateText(text);
        }
      }
    });

    if (!editState.isEditing) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      decoration: BoxDecoration(
        color: NovaColors.warningLight.withValues(alpha: 0.05),
        border: Border(
          top: BorderSide(
            color: NovaColors.warningLight.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Input row (text field + save button)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Text field
              Expanded(
                child: Semantics(
                  textField: true,
                  label:
                      'Campo di testo per modificare il commento, limite 500 caratteri',
                  hint: 'Modifica il commento',
                  enabled: !editState.isSaving,
                  child: Platform.isIOS
                      ? CupertinoTextField(
                          controller: _controller,
                          placeholder: 'Modifica il commento...',
                          placeholderStyle: NovaTextStyles.body.copyWith(
                            color: NovaColors.textTertiaryLight,
                          ),
                          style: NovaTextStyles.body,
                          maxLines: null,
                          minLines: 1,
                          maxLength: 500,
                          textInputAction: TextInputAction.newline,
                          decoration: BoxDecoration(
                            color: NovaColors.surfaceLight,
                            borderRadius: NovaRadius.circularL,
                            border: Border.all(
                              color: NovaColors.warningLight,
                              width: 1,
                            ),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: NovaSpacing.m,
                            vertical: NovaSpacing.s,
                          ),
                          enabled: !editState.isSaving,
                        )
                      : TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: 'Modifica il commento...',
                            hintStyle: NovaTextStyles.body.copyWith(
                              color: NovaColors.textTertiaryLight,
                            ),
                            filled: true,
                            fillColor: NovaColors.surfaceLight,
                            border: OutlineInputBorder(
                              borderRadius: NovaRadius.circularL,
                              borderSide: BorderSide(
                                color: NovaColors.warningLight,
                                width: 1,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: NovaRadius.circularL,
                              borderSide: BorderSide(
                                color: NovaColors.warningLight,
                                width: 1,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: NovaRadius.circularL,
                              borderSide: BorderSide(
                                color: NovaColors.warningDark,
                                width: 2,
                              ),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: NovaSpacing.m,
                              vertical: NovaSpacing.s,
                            ),
                            counterText: '', // Hide default counter
                          ),
                          style: NovaTextStyles.body,
                          maxLines: null,
                          minLines: 1,
                          maxLength: 500,
                          textInputAction: TextInputAction.newline,
                          enabled: !editState.isSaving,
                        ),
                ),
              ),

              SizedBox(width: NovaSpacing.s),

              // Save button
              _buildSaveButton(context, editState, editNotifier),
            ],
          ),

          // Error message
          if (editState.error != null) ...[
            SizedBox(height: NovaSpacing.xs),
            Padding(
              padding: EdgeInsets.only(left: NovaSpacing.s),
              child: Text(
                editState.error!,
                style: NovaTextStyles.caption.copyWith(
                  color: NovaColors.errorLight,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton(
    BuildContext context,
    EditCommentState editState,
    EditCommentNotifier editNotifier,
  ) {
    if (editState.isSaving) {
      // Loading indicator
      return Semantics(
        label: 'Salvataggio modifica in corso',
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

    // Save button (checkmark)
    return Semantics(
      button: true,
      label: editState.canSave
          ? 'Salva modifica'
          : 'Pulsante salva disabilitato, modifica il testo per salvare',
      enabled: editState.canSave,
      child: IconButton(
        onPressed: editState.canSave
            ? () async {
                final result = await editNotifier.saveEdit();
                if (result == EditResult.success) {
                  widget.onSaveSuccess?.call();
                }
              }
            : null,
        icon: Icon(
          Icons.check_circle,
          color: editState.canSave
              ? NovaColors.successLight
              : NovaColors.textTertiaryLight,
        ),
        iconSize: 32,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
    );
  }
}
