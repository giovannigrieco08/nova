// Widget: RejectionDialog
// Feature: 004-event-creation-moderation (US3 - Moderation Queue)
// Purpose: Dialog for moderators to enter rejection reason
//
// Validation:
// - Minimum 10 characters (ensure meaningful feedback)
// - Maximum 200 characters (concise feedback)
// - Character counter displayed
//
// Usage:
// ```dart
// final reason = await showDialog<String>(
//   context: context,
//   builder: (context) => const RejectionDialog(),
// );
// if (reason != null) {
//   await moderationNotifier.rejectEvent(eventId, reason);
// }
// ```

import 'package:flutter/material.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';

/// Dialog for entering event rejection reason
class RejectionDialog extends StatefulWidget {
  final String eventTitle;

  const RejectionDialog({
    super.key,
    required this.eventTitle,
  });

  @override
  State<RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<RejectionDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  static const int minLength = 10;
  static const int maxLength = 200;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Validate rejection reason
  String? _validateReason(String reason) {
    final trimmed = reason.trim();

    if (trimmed.isEmpty) {
      return 'Il motivo del rifiuto è obbligatorio';
    }

    if (trimmed.length < minLength) {
      return 'Minimo $minLength caratteri (fornisci feedback utile)';
    }

    if (trimmed.length > maxLength) {
      return 'Massimo $maxLength caratteri';
    }

    return null; // Valid
  }

  /// Handle confirm button
  void _handleConfirm() {
    final reason = _controller.text.trim();
    final error = _validateReason(reason);

    if (error != null) {
      setState(() => _errorText = error);
      return;
    }

    // Return rejection reason to caller
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Rifiuta Evento',
        style: NovaTextStyles.h3,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Event title
          Container(
            padding: EdgeInsets.all(NovaSpacing.s),
            decoration: BoxDecoration(
              color: NovaColors.surface(context),
              borderRadius: BorderRadius.circular(NovaRadius.s),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 16,
                  color: NovaColors.textSecondary(context),
                ),
                SizedBox(width: NovaSpacing.xs),
                Expanded(
                  child: Text(
                    widget.eventTitle,
                    style: NovaTextStyles.caption.copyWith(
                      color: NovaColors.textSecondary(context),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: NovaSpacing.m),

          // Instruction text
          Text(
            'Spiega perché questo evento è stato rifiutato. Il creatore riceverà questa motivazione.',
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),

          SizedBox(height: NovaSpacing.m),

          // Rejection reason input
          TextField(
            controller: _controller,
            maxLength: maxLength,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
              hintText:
                  'Es: L\'evento non rispetta le linee guida della scuola...',
              errorText: _errorText,
              counterText:
                  '${_controller.text.length}/$maxLength', // Character counter
              filled: true,
              fillColor: NovaColors.surface(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NovaRadius.m),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NovaRadius.m),
                borderSide: BorderSide(color: NovaColors.border(context)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NovaRadius.m),
                borderSide:
                    BorderSide(color: NovaColors.primary(context), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(NovaRadius.m),
                borderSide: BorderSide(color: NovaColors.error(context)),
              ),
            ),
            style: NovaTextStyles.body,
            onChanged: (value) {
              // Clear error when user types
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),

          SizedBox(height: NovaSpacing.s),

          // Warning box
          Container(
            padding: EdgeInsets.all(NovaSpacing.s),
            decoration: BoxDecoration(
              color: NovaColors.error(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(NovaRadius.s),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_outlined,
                  size: 16,
                  color: NovaColors.error(context),
                ),
                SizedBox(width: NovaSpacing.xs),
                Expanded(
                  child: Text(
                    'Questa azione è irreversibile. Il creatore non potrà modificare l\'evento rifiutato.',
                    style: NovaTextStyles.small.copyWith(
                      color: NovaColors.error(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annulla'),
        ),

        // Confirm button
        ElevatedButton(
          onPressed: _handleConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: NovaColors.error(context),
            foregroundColor: Colors.white,
          ),
          child: const Text('Rifiuta Evento'),
        ),
      ],
    );
  }
}
