import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/entities/chat_report.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';

/// Dialog for reporting inappropriate chat messages.
///
/// Presents 4 reason options:
/// - Spam
/// - Contenuto inappropriato
/// - Bullismo
/// - Off-topic
class ChatReportDialog extends ConsumerStatefulWidget {
  final String messageId;
  final VoidCallback? onReported;
  final VoidCallback? onAlreadyReported;

  const ChatReportDialog({
    super.key,
    required this.messageId,
    this.onReported,
    this.onAlreadyReported,
  });

  @override
  ConsumerState<ChatReportDialog> createState() => _ChatReportDialogState();
}

class _ChatReportDialogState extends ConsumerState<ChatReportDialog> {
  ChatReportReason? _selectedReason;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: NovaColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NovaRadius.xl),
      ),
      child: Padding(
        padding: EdgeInsets.all(NovaSpacing.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Segnala messaggio',
              style: NovaTypography.headingSmall.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.xs),
            Text(
              'Seleziona il motivo della segnalazione:',
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
            SizedBox(height: NovaSpacing.m),

            // Reason options
            ...ChatReportReason.values.map((reason) => _buildReasonOption(context, reason)),

            SizedBox(height: NovaSpacing.l),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  child: Text(
                    'Annulla',
                    style: NovaTypography.bodyMedium.copyWith(
                      color: NovaColors.textSecondary(context),
                    ),
                  ),
                ),
                SizedBox(width: NovaSpacing.s),
                ElevatedButton(
                  onPressed: _selectedReason != null && !_isSubmitting
                      ? _submitReport
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: NovaColors.error(context),
                    foregroundColor: NovaColors.onErrorLight,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: NovaColors.onErrorLight,
                          ),
                        )
                      : const Text('Segnala'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReasonOption(BuildContext context, ChatReportReason reason) {
    final isSelected = _selectedReason == reason;

    return GestureDetector(
      onTap: () => setState(() => _selectedReason = reason),
      child: Container(
        margin: EdgeInsets.only(bottom: NovaSpacing.xs),
        padding: EdgeInsets.all(NovaSpacing.s),
        decoration: BoxDecoration(
          color: isSelected
              ? NovaColors.error(context).withValues(alpha: 0.1)
              : NovaColors.card(context),
          borderRadius: BorderRadius.circular(NovaRadius.m),
          border: Border.all(
            color: isSelected ? NovaColors.error(context) : NovaColors.card(context).withValues(alpha: 0.0),
          ),
        ),
        child: Row(
          children: [
            // Radio indicator
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? NovaColors.error(context) : NovaColors.textTertiary(context),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: NovaColors.error(context),
                        ),
                      ),
                    )
                  : null,
            ),
            SizedBox(width: NovaSpacing.s),

            // Label
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reason.label,
                    style: NovaTypography.bodyMedium.copyWith(
                      color: isSelected
                          ? NovaColors.error(context)
                          : NovaColors.textPrimary(context),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  Text(
                    _getReasonDescription(reason),
                    style: NovaTypography.bodySmall.copyWith(
                      color: NovaColors.textTertiary(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getReasonDescription(ChatReportReason reason) {
    switch (reason) {
      case ChatReportReason.spam:
        return 'Messaggi ripetitivi o promozionali';
      case ChatReportReason.inappropriate:
        return 'Contenuto offensivo o per adulti';
      case ChatReportReason.bullying:
        return 'Insulti, minacce o molestie';
      case ChatReportReason.offTopic:
        return 'Non pertinente alla scuola';
    }
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() => _isSubmitting = true);

    try {
      final success = await ref.read(
        submitReportProvider(
          (messageId: widget.messageId, reason: _selectedReason!),
        ).future,
      );

      if (mounted) {
        Navigator.pop(context);
        if (success) {
          widget.onReported?.call();
        } else {
          widget.onAlreadyReported?.call();
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Errore nell\'invio della segnalazione'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }
}
