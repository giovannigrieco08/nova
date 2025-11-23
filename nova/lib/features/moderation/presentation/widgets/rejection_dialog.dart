// =====================================================================
// RejectionDialog Widget - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Dialog for selecting rejection reason with predefined options
// Architecture: Stateful widget with dropdown + custom text field
// =====================================================================

import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_button.dart';

/// Dialog for rejecting an event with reason
///
/// Features:
/// - Predefined rejection reasons dropdown
/// - Custom text field for additional details
/// - Validation (reason required)
/// - Adaptive buttons (Cancel/Rifiuta)
class RejectionDialog extends StatefulWidget {
  /// Event title (for context)
  final String eventTitle;

  const RejectionDialog({
    super.key,
    required this.eventTitle,
  });

  @override
  State<RejectionDialog> createState() => _RejectionDialogState();

  /// Show dialog and return selected reason (null if cancelled)
  static Future<String?> show(BuildContext context, String eventTitle) {
    return showDialog<String>(
      context: context,
      builder: (context) => RejectionDialog(eventTitle: eventTitle),
    );
  }
}

class _RejectionDialogState extends State<RejectionDialog> {
  /// Predefined rejection reasons (from spec)
  static const List<String> predefinedReasons = [
    'Contenuto inappropriato',
    'Informazioni incomplete',
    'Duplicato',
    'Fuori tema',
  ];

  String? _selectedReason;
  final _customReasonController = TextEditingController();
  bool _showCustomField = false;

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Rifiuta evento',
        style: NovaTextStyles.h3.copyWith(
          color: NovaColors.textPrimary(context),
        ),
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event title context
            Text(
              widget.eventTitle,
              style: NovaTextStyles.bodyBold.copyWith(
                color: NovaColors.textPrimary(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: NovaSpacing.l),

            // Reason label
            Text(
              'Motivo del rifiuto',
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.s),

            // Predefined reasons dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: NovaSpacing.m),
              decoration: BoxDecoration(
                border: Border.all(color: NovaColors.border(context)),
                borderRadius: NovaRadius.circularS,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text(
                    'Seleziona motivo...',
                    style: NovaTextStyles.body.copyWith(
                      color: NovaColors.textTertiary(context),
                    ),
                  ),
                  value: _selectedReason,
                  items: predefinedReasons.map((reason) {
                    return DropdownMenuItem(
                      value: reason,
                      child: Text(
                        reason,
                        style: NovaTextStyles.body.copyWith(
                          color: NovaColors.textPrimary(context),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                      _showCustomField = false;
                      _customReasonController.clear();
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: NovaSpacing.m),

            // "Altro" button to show custom text field
            if (!_showCustomField)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showCustomField = true;
                    _selectedReason = null;
                  });
                },
                child: Text(
                  'Altro motivo...',
                  style: NovaTextStyles.body.copyWith(
                    color: NovaColors.primary(context),
                  ),
                ),
              ),

            // Custom reason text field
            if (_showCustomField) ...[
              TextField(
                controller: _customReasonController,
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Descrivi il motivo del rifiuto...',
                  hintStyle: NovaTextStyles.body.copyWith(
                    color: NovaColors.textTertiary(context),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: NovaRadius.circularS,
                    borderSide: BorderSide(
                      color: NovaColors.border(context),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: NovaRadius.circularS,
                    borderSide: BorderSide(
                      color: NovaColors.border(context),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: NovaRadius.circularS,
                    borderSide: BorderSide(
                      color: NovaColors.primary(context),
                      width: 2,
                    ),
                  ),
                ),
                style: NovaTextStyles.body.copyWith(
                  color: NovaColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: NovaSpacing.s),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showCustomField = false;
                    _customReasonController.clear();
                  });
                },
                child: Text(
                  'Usa motivo predefinito',
                  style: NovaTextStyles.caption.copyWith(
                    color: NovaColors.textSecondary(context),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // Cancel button
        AdaptiveButton(
          type: AdaptiveButtonType.text,
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'Annulla',
            style: NovaTextStyles.button.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
        ),

        // Reject button
        AdaptiveButton(
          type: AdaptiveButtonType.destructive,
          onPressed: _handleReject,
          child: Text(
            'Rifiuta',
            style: NovaTextStyles.button.copyWith(
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// Handle reject button tap
  void _handleReject() {
    // Get final reason (predefined or custom)
    final reason = _showCustomField
        ? _customReasonController.text.trim()
        : _selectedReason;

    // Validate
    if (reason == null || reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Seleziona o inserisci un motivo del rifiuto',
            style: NovaTextStyles.body.copyWith(color: Colors.white),
          ),
          backgroundColor: NovaColors.errorLight,
        ),
      );
      return;
    }

    // Return reason
    Navigator.of(context).pop(reason);
  }
}
