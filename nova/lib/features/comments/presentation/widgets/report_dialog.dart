import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../domain/entities/comment_report.dart';
// Note: report_comment.dart import removed to avoid ambiguous CommentReportReason

/// ReportDialog Widget
///
/// Platform-adaptive dialog for reporting inappropriate comments.
///
/// Features:
/// - Title: "Perché segnali questo commento?"
/// - Reason checkboxes (single select)
/// - Optional text field for "Altro" reason
/// - Cancel and Submit buttons
/// - Platform-adaptive styling (Cupertino/Material)
///
/// **T062**: Create ReportDialog widget
/// **FR-033**: Students can report comments for moderation
///
/// Usage:
/// ```dart
/// final result = await showReportDialog(
///   context: context,
///   commentId: '123',
/// );
/// if (result != null) {
///   // User submitted report with reason and optional details
/// }
/// ```
class ReportDialog extends StatefulWidget {
  final String commentId;

  const ReportDialog({
    super.key,
    required this.commentId,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  CommentReportReason? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();
  final bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_selectedReason == null) return;

    Navigator.of(context).pop(ReportResult(
      reason: _selectedReason!,
      additionalDetails: _selectedReason == CommentReportReason.other
          ? _detailsController.text.trim()
          : null,
    ));
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
        child: Text(
          'Perché segnali questo commento?',
          style: NovaTypography.headingSmall,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Reason options
            ...CommentReportReason.values.map((reason) {
              return RadioListTile<CommentReportReason>(
                title: Text(
                  reason.displayName,
                  style: NovaTypography.bodyMedium,
                ),
                value: reason,
                groupValue: _selectedReason,
                onChanged: (value) {
                  setState(() {
                    _selectedReason = value;
                  });
                },
                activeColor: NovaColors.primaryLight,
                contentPadding: EdgeInsets.zero,
              );
            }),

            // Additional details for "Altro"
            if (_selectedReason == CommentReportReason.other) ...[
              SizedBox(height: NovaSpacing.s),
              TextField(
                controller: _detailsController,
                decoration: InputDecoration(
                  hintText: 'Descrivi il problema (opzionale)',
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
              ),
            ],
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
          onPressed: _selectedReason != null ? _submit : null,
          child: Text(
            'Segnala',
            style: NovaTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: _selectedReason != null
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
        child: Text(
          'Perché segnali questo commento?',
          style: NovaTypography.headingSmall,
        ),
      ),
      content: Padding(
        padding: EdgeInsets.only(top: NovaSpacing.s),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Reason options
            ...CommentReportReason.values.map((reason) {
              final isSelected = _selectedReason == reason;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedReason = reason;
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: NovaSpacing.s,
                    horizontal: NovaSpacing.m,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? NovaColors.primaryLight.withValues(alpha: 0.1)
                        : const Color(0x00000000),
                    borderRadius: NovaRadius.circularXs,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected
                            ? NovaColors.primaryLight
                            : NovaColors.textTertiaryLight,
                        size: 20,
                      ),
                      SizedBox(width: NovaSpacing.s),
                      Text(
                        reason.displayName,
                        style: NovaTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
              );
            }),

            // Additional details for "Altro"
            if (_selectedReason == CommentReportReason.other) ...[
              SizedBox(height: NovaSpacing.s),
              CupertinoTextField(
                controller: _detailsController,
                placeholder: 'Descrivi il problema (opzionale)',
                maxLines: 3,
                maxLength: 500,
                padding: EdgeInsets.all(NovaSpacing.s),
              ),
            ],
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
          onPressed: _selectedReason != null ? _submit : null,
          isDestructiveAction: true,
          child: Text(
            'Segnala',
            style: NovaTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: _selectedReason != null
                  ? NovaColors.errorLight
                  : NovaColors.textTertiaryLight,
            ),
          ),
        ),
      ],
    );
  }
}

/// Result from report dialog
class ReportResult {
  final CommentReportReason reason;
  final String? additionalDetails;

  ReportResult({
    required this.reason,
    this.additionalDetails,
  });
}

/// Show report dialog
///
/// Returns [ReportResult] if user submits, null if cancelled.
Future<ReportResult?> showReportDialog({
  required BuildContext context,
  required String commentId,
}) {
  return showDialog<ReportResult>(
    context: context,
    builder: (context) => ReportDialog(commentId: commentId),
  );
}
