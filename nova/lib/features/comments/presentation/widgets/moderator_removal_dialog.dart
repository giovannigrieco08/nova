import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

/// ModeratorRemovalDialog Widget
///
/// Platform-adaptive dialog for moderator to provide removal reason.
///
/// Features:
/// - Title: "Rimuovi commento"
/// - Message: "Inserisci il motivo della rimozione. Verrà inviato all'autore del commento."
/// - Text field for reason (required, max 500 chars)
/// - Common reasons as quick-select chips
/// - Cancel button: "Annulla"
/// - Remove button: "Rimuovi" (destructive red, disabled until reason provided)
///
/// **T081**: Create notification input dialog for moderator removal reason
/// **FR-030**: Moderators can remove comments with reason
///
/// Usage:
/// ```dart
/// final reason = await showModeratorRemovalDialog(context: context);
/// if (reason != null) {
///   await moderatorRemove(commentId: '123', reason: reason);
/// }
/// ```
class ModeratorRemovalDialog extends StatefulWidget {
  const ModeratorRemovalDialog({super.key});

  @override
  State<ModeratorRemovalDialog> createState() => _ModeratorRemovalDialogState();
}

class _ModeratorRemovalDialogState extends State<ModeratorRemovalDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String? _selectedQuickReason;

  /// Common removal reasons for quick selection
  static const List<String> _quickReasons = [
    'Linguaggio inappropriato',
    'Contenuto offensivo',
    'Bullismo o molestie',
    'Spam o pubblicità',
    'Off-topic',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _selectQuickReason(String reason) {
    setState(() {
      if (_selectedQuickReason == reason) {
        // Deselect
        _selectedQuickReason = null;
        _reasonController.clear();
      } else {
        _selectedQuickReason = reason;
        _reasonController.text = reason;
      }
    });
  }

  bool get _canSubmit => _reasonController.text.trim().isNotEmpty;

  void _submit() {
    if (!_canSubmit) return;
    Navigator.of(context).pop(_reasonController.text.trim());
  }

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
        child: Row(
          children: [
            Icon(
              Icons.shield_outlined,
              color: NovaColors.errorLight,
              size: 24,
            ),
            SizedBox(width: NovaSpacing.s),
            Text(
              'Rimuovi commento',
              style: NovaTypography.headingSmall,
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Inserisci il motivo della rimozione. Verrà inviato all\'autore del commento.',
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textSecondaryLight,
              ),
            ),
            SizedBox(height: NovaSpacing.m),

            // Quick reason chips
            Wrap(
              spacing: NovaSpacing.xs,
              runSpacing: NovaSpacing.xs,
              children: _quickReasons.map((reason) {
                final isSelected = _selectedQuickReason == reason;
                return ChoiceChip(
                  label: Text(
                    reason,
                    style: NovaTypography.bodySmall.copyWith(
                      color: isSelected
                          ? Colors.white
                          : NovaColors.textSecondaryLight,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: NovaColors.primaryLight,
                  onSelected: (_) => _selectQuickReason(reason),
                );
              }).toList(),
            ),

            SizedBox(height: NovaSpacing.m),

            // Reason text field
            TextField(
              controller: _reasonController,
              decoration: InputDecoration(
                hintText: 'Motivo della rimozione...',
                hintStyle: NovaTypography.bodyMedium.copyWith(
                  color: NovaColors.textTertiaryLight,
                ),
                border: OutlineInputBorder(
                  borderRadius: NovaRadius.circularXs,
                ),
                contentPadding: EdgeInsets.all(NovaSpacing.s),
              ),
              maxLines: 3,
              maxLength: 500,
              style: NovaTypography.bodyMedium,
              onChanged: (_) {
                setState(() {
                  _selectedQuickReason = null;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Annulla',
            style: NovaTypography.bodyMedium.copyWith(
              color: NovaColors.textSecondaryLight,
            ),
          ),
        ),
        TextButton(
          onPressed: _canSubmit ? _submit : null,
          child: Text(
            'Rimuovi',
            style: NovaTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: _canSubmit
                  ? NovaColors.errorLight
                  : NovaColors.textTertiaryLight,
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.shield,
              color: CupertinoColors.destructiveRed,
              size: 20,
            ),
            SizedBox(width: NovaSpacing.xs),
            Text(
              'Rimuovi commento',
              style: NovaTypography.headingSmall,
            ),
          ],
        ),
      ),
      content: Padding(
        padding: EdgeInsets.only(top: NovaSpacing.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Inserisci il motivo della rimozione. Verrà inviato all\'autore del commento.',
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textSecondaryLight,
              ),
            ),
            SizedBox(height: NovaSpacing.m),

            // Quick reason buttons
            ...(_quickReasons.map((reason) {
              final isSelected = _selectedQuickReason == reason;
              return GestureDetector(
                onTap: () => _selectQuickReason(reason),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(
                    vertical: NovaSpacing.xs,
                    horizontal: NovaSpacing.s,
                  ),
                  margin: EdgeInsets.only(bottom: NovaSpacing.xs),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? NovaColors.primaryLight.withValues(alpha: 0.1)
                        : Colors.transparent,
                    borderRadius: NovaRadius.circularXs,
                    border: Border.all(
                      color: isSelected
                          ? NovaColors.primaryLight
                          : NovaColors.dividerLight,
                    ),
                  ),
                  child: Text(
                    reason,
                    style: NovaTypography.bodyMedium.copyWith(
                      color: isSelected
                          ? NovaColors.primaryLight
                          : NovaColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            })),

            SizedBox(height: NovaSpacing.s),

            // Reason text field
            CupertinoTextField(
              controller: _reasonController,
              placeholder: 'Altro motivo...',
              maxLines: 2,
              maxLength: 500,
              padding: EdgeInsets.all(NovaSpacing.s),
              onChanged: (_) {
                setState(() {
                  _selectedQuickReason = null;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Annulla',
            style: NovaTypography.bodyMedium.copyWith(
              color: NovaColors.textSecondaryLight,
            ),
          ),
        ),
        CupertinoDialogAction(
          onPressed: _canSubmit ? _submit : null,
          isDestructiveAction: true,
          child: Text(
            'Rimuovi',
            style: NovaTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

/// Show moderator removal dialog
///
/// Returns removal reason string if submitted, null if cancelled.
Future<String?> showModeratorRemovalDialog({
  required BuildContext context,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => const ModeratorRemovalDialog(),
  );
}
