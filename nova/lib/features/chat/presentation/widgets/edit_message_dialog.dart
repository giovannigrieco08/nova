import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';

/// Dialog for editing a message (within 5-minute window).
///
/// Shows:
/// - Original message content
/// - Text field for editing
/// - Character counter (max 500)
/// - Cancel/Save buttons
/// - Timer showing remaining edit time
class EditMessageDialog extends ConsumerStatefulWidget {
  final ChatMessage message;
  final Future<bool> Function(String newContent) onSave;

  const EditMessageDialog({
    super.key,
    required this.message,
    required this.onSave,
  });

  /// Show the edit message dialog
  static Future<bool?> show(
    BuildContext context, {
    required ChatMessage message,
    required Future<bool> Function(String newContent) onSave,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => EditMessageDialog(
        message: message,
        onSave: onSave,
      ),
    );
  }

  @override
  ConsumerState<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends ConsumerState<EditMessageDialog> {
  late TextEditingController _controller;
  bool _isSaving = false;
  static const int _maxCharacters = 500;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.message.content);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSave {
    final text = _controller.text.trim();
    return text.isNotEmpty &&
        text != widget.message.content.trim() &&
        text.length <= _maxCharacters &&
        !_isSaving;
  }

  Future<void> _handleSave() async {
    if (!_canSave) return;

    setState(() => _isSaving = true);

    try {
      final success = await widget.onSave(_controller.text.trim());
      if (mounted) {
        Navigator.of(context).pop(success);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Messaggio modificato'),
              backgroundColor: NovaColors.success(context),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final characterCount = _controller.text.length;
    final isOverLimit = characterCount > _maxCharacters;
    final remainingMinutes = widget.message.editWindowMinutesRemaining;

    return AlertDialog(
      backgroundColor: NovaColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: NovaRadius.circularL,
      ),
      title: Row(
        children: [
          Icon(
            Icons.edit_outlined,
            color: NovaColors.primary(context),
            size: 24,
          ),
          SizedBox(width: NovaSpacing.s),
          Expanded(
            child: Text(
              'Modifica messaggio',
              style: NovaTypography.headlineSmall.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timer warning
          if (remainingMinutes <= 2)
            Container(
              padding: EdgeInsets.all(NovaSpacing.s),
              margin: EdgeInsets.only(bottom: NovaSpacing.m),
              decoration: BoxDecoration(
                color: NovaColors.warning(context).withValues(alpha: 0.1),
                borderRadius: NovaRadius.circularS,
                border: Border.all(
                  color: NovaColors.warning(context).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    color: NovaColors.warning(context),
                    size: 18,
                  ),
                  SizedBox(width: NovaSpacing.xs),
                  Expanded(
                    child: Text(
                      remainingMinutes > 0
                          ? '$remainingMinutes min rimanenti per modificare'
                          : 'Tempo scaduto',
                      style: NovaTypography.bodySmall.copyWith(
                        color: NovaColors.warning(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Text field
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 5,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            style: NovaTypography.bodyMedium.copyWith(
              color: NovaColors.textPrimary(context),
            ),
            decoration: InputDecoration(
              hintText: 'Scrivi il messaggio...',
              hintStyle: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textTertiary(context),
              ),
              filled: true,
              fillColor: NovaColors.card(context),
              border: OutlineInputBorder(
                borderRadius: NovaRadius.circularM,
                borderSide: BorderSide(color: NovaColors.border(context)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: NovaRadius.circularM,
                borderSide: BorderSide(color: NovaColors.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: NovaRadius.circularM,
                borderSide: BorderSide(
                  color: NovaColors.primary(context),
                  width: 2,
                ),
              ),
              contentPadding: EdgeInsets.all(NovaSpacing.m),
            ),
            onChanged: (_) => setState(() {}),
          ),

          SizedBox(height: NovaSpacing.xs),

          // Character counter
          Align(
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
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: Text(
            'Annulla',
            style: TextStyle(color: NovaColors.textSecondary(context)),
          ),
        ),
        ElevatedButton(
          onPressed: _canSave ? _handleSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: NovaColors.primary(context),
            foregroundColor: NovaColors.onPrimaryLight,
            shape: RoundedRectangleBorder(
              borderRadius: NovaRadius.circularS,
            ),
          ),
          child: _isSaving
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: NovaColors.onPrimaryLight,
                  ),
                )
              : const Text('Salva'),
        ),
      ],
    );
  }
}
