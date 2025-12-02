import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

/// DeleteConfirmationDialog Widget
///
/// Platform-adaptive dialog for confirming comment deletion.
///
/// Features:
/// - Title: "Elimina commento"
/// - Message: "Sei sicuro di voler eliminare questo commento?"
/// - Warning: "Questa azione non può essere annullata."
/// - Cancel button: "Annulla"
/// - Delete button: "Elimina" (destructive red)
/// - Platform-adaptive styling (Cupertino/Material)
///
/// **T070**: Create DeleteConfirmationDialog widget
/// **FR-036**: Students can delete their own comments
///
/// Usage:
/// ```dart
/// final confirmed = await showDeleteConfirmationDialog(
///   context: context,
/// );
/// if (confirmed == true) {
///   // User confirmed deletion
///   await deleteComment(commentId: '123');
/// }
/// ```
class DeleteConfirmationDialog extends StatelessWidget {
  const DeleteConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return _buildCupertinoDialog(context);
    }
    return _buildMaterialDialog(context);
  }

  Widget _buildMaterialDialog(BuildContext context) {
    return AlertDialog(
      title: Semantics(
        header: true,
        child: Text(
          'Elimina commento',
          style: NovaTypography.headingSmall,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sei sicuro di voler eliminare questo commento?',
            style: NovaTypography.bodyMedium,
          ),
          SizedBox(height: NovaSpacing.s),
          Text(
            'Questa azione non può essere annullata.',
            style: NovaTypography.bodySmall.copyWith(
              color: NovaColors.textTertiaryLight,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Annulla',
            style: NovaTypography.bodyMedium.copyWith(
              color: NovaColors.textSecondaryLight,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Elimina',
            style: NovaTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: NovaColors.errorLight,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCupertinoDialog(BuildContext context) {
    return CupertinoAlertDialog(
      title: Semantics(
        header: true,
        child: Text(
          'Elimina commento',
          style: NovaTypography.headingSmall,
        ),
      ),
      content: Padding(
        padding: EdgeInsets.only(top: NovaSpacing.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sei sicuro di voler eliminare questo commento?',
              style: NovaTypography.bodyMedium,
            ),
            SizedBox(height: NovaSpacing.xs),
            Text(
              'Questa azione non può essere annullata.',
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.textTertiaryLight,
              ),
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Annulla',
            style: NovaTypography.bodyMedium.copyWith(
              color: NovaColors.textSecondaryLight,
            ),
          ),
        ),
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(true),
          isDestructiveAction: true,
          child: Text(
            'Elimina',
            style: NovaTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Show delete confirmation dialog
///
/// Returns [true] if user confirms deletion, [false] if cancelled.
Future<bool?> showDeleteConfirmationDialog({
  required BuildContext context,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => const DeleteConfirmationDialog(),
  );
}
