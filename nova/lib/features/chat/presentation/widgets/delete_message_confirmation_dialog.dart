import 'package:flutter/material.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Confirmation dialog before deleting a message.
///
/// Shows:
/// - Title "Elimina messaggio"
/// - Descriptive text explaining the action is irreversible
/// - "Annulla" and "Elimina" buttons
/// - "Elimina" button styled with error color
class DeleteMessageConfirmationDialog extends StatelessWidget {
  const DeleteMessageConfirmationDialog({super.key});

  /// Show the confirmation dialog.
  /// Returns true if user confirmed deletion, false otherwise.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => const DeleteMessageConfirmationDialog(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
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
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Annulla',
            style: TextStyle(color: NovaColors.textSecondary(context)),
          ),
        ),
        // T028: "Elimina" button styled with error color
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Elimina',
            style: TextStyle(color: NovaColors.error(context)),
          ),
        ),
      ],
    );
  }
}
