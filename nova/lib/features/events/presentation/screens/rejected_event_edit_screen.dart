// =====================================================================
// Rejected Event Edit Screen - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Edit and resubmit rejected events (description-only editing)
// Architecture: ConsumerStatefulWidget with form validation
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/events/domain/entities/event.dart';
import 'package:nova/features/events/presentation/widgets/rejection_reason_badge.dart';
import 'package:nova/features/events/presentation/providers/resubmit_event_notifier.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_scaffold.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_app_bar.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_button.dart';

/// Edit rejected event screen
///
/// Allows users to:
/// - View rejection reason from moderator
/// - Edit only the event description (other fields read-only)
/// - Resubmit event for moderation
class RejectedEventEditScreen extends ConsumerStatefulWidget {
  final Event event;

  const RejectedEventEditScreen({
    super.key,
    required this.event,
  });

  @override
  ConsumerState<RejectedEventEditScreen> createState() =>
      _RejectedEventEditScreenState();
}

class _RejectedEventEditScreenState
    extends ConsumerState<RejectedEventEditScreen> {
  late TextEditingController _descriptionController;
  String? _descriptionError;
  bool _showConfirmDialog = false;

  @override
  void initState() {
    super.initState();
    _descriptionController =
        TextEditingController(text: widget.event.description);
    _descriptionController.addListener(_validateDescription);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// Validate description (20-500 characters)
  void _validateDescription() {
    final text = _descriptionController.text.trim();

    setState(() {
      if (text.isEmpty) {
        _descriptionError = 'La descrizione è obbligatoria';
      } else if (text.length < 20) {
        _descriptionError =
            'La descrizione deve contenere almeno 20 caratteri (${text.length}/20)';
      } else if (text.length > 500) {
        _descriptionError =
            'La descrizione può contenere massimo 500 caratteri (${text.length}/500)';
      } else {
        _descriptionError = null;
      }
    });
  }

  /// Show confirmation dialog before resubmitting
  Future<void> _showResubmitDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma ri-sottomissione'),
        content: const Text(
          'Sei sicuro di voler ri-sottomettere questo evento per la moderazione? '
          'Il tuo evento tornerà in coda per la revisione.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          AdaptiveButton(
            onPressed: () => Navigator.of(context).pop(true),
            variant: AdaptiveButtonVariant.primary,
            label: 'Ri-sottometti',
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _handleResubmit();
    }
  }

  /// Handle event resubmission
  Future<void> _handleResubmit() async {
    // Validate
    _validateDescription();
    if (_descriptionError != null) {
      return;
    }

    final notifier = ref.read(resubmitEventNotifierProvider.notifier);
    await notifier.resubmit(
      widget.event.id,
      _descriptionController.text.trim(),
    );

    // Check result
    final state = ref.read(resubmitEventNotifierProvider);

    if (state.successMessage != null && mounted) {
      // Show success and navigate back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.successMessage!),
          backgroundColor: NovaColors.success(context),
        ),
      );
      Navigator.of(context).pop();
    } else if (state.error != null && mounted) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(state.error!),
          backgroundColor: NovaColors.error(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifierState = ref.watch(resubmitEventNotifierProvider);
    final isSubmitting = notifierState.isLoading;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: const Text('Modifica Evento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(NovaSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Rejection reason badge
            if (widget.event.rejectionReason != null) ...[
              RejectionReasonBadge(
                rejectionReason: widget.event.rejectionReason!,
                expanded: true,
              ),
              const SizedBox(height: NovaSpacing.l),
            ],

            // Info message
            Container(
              padding: const EdgeInsets.all(NovaSpacing.m),
              decoration: BoxDecoration(
                color: NovaColors.primary(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(NovaRadius.m),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: NovaColors.primary(context),
                    size: 20,
                  ),
                  const SizedBox(width: NovaSpacing.s),
                  Expanded(
                    child: Text(
                      'Puoi modificare solo la descrizione. Gli altri campi sono di sola lettura.',
                      style: NovaTextStyles.caption.copyWith(
                        color: NovaColors.textSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: NovaSpacing.l),

            // Read-only: Title
            Text('Titolo', style: NovaTextStyles.label),
            const SizedBox(height: NovaSpacing.xs),
            Container(
              padding: const EdgeInsets.all(NovaSpacing.m),
              decoration: BoxDecoration(
                color: NovaColors.surface(context),
                borderRadius: BorderRadius.circular(NovaRadius.m),
              ),
              child: Text(
                widget.event.title,
                style: NovaTextStyles.body.copyWith(
                  color: NovaColors.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(height: NovaSpacing.m),

            // Read-only: Event Date
            Text('Data e Ora', style: NovaTextStyles.label),
            const SizedBox(height: NovaSpacing.xs),
            Container(
              padding: const EdgeInsets.all(NovaSpacing.m),
              decoration: BoxDecoration(
                color: NovaColors.surface(context),
                borderRadius: BorderRadius.circular(NovaRadius.m),
              ),
              child: Text(
                DateFormat('dd/MM/yyyy HH:mm').format(widget.event.eventDate),
                style: NovaTextStyles.body.copyWith(
                  color: NovaColors.textSecondary(context),
                ),
              ),
            ),
            const SizedBox(height: NovaSpacing.m),

            // Read-only: Location (if exists)
            if (widget.event.location != null) ...[
              Text('Luogo', style: NovaTextStyles.label),
              const SizedBox(height: NovaSpacing.xs),
              Container(
                padding: const EdgeInsets.all(NovaSpacing.m),
                decoration: BoxDecoration(
                  color: NovaColors.surface(context),
                  borderRadius: BorderRadius.circular(NovaRadius.m),
                ),
                child: Text(
                  widget.event.location!,
                  style: NovaTextStyles.body.copyWith(
                    color: NovaColors.textSecondary(context),
                  ),
                ),
              ),
              const SizedBox(height: NovaSpacing.m),
            ],

            // Editable: Description
            Text('Descrizione *', style: NovaTextStyles.label),
            const SizedBox(height: NovaSpacing.xs),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Modifica la descrizione dell\'evento...',
                errorText: _descriptionError,
                filled: true,
                fillColor: NovaColors.surface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(NovaRadius.m),
                  borderSide: BorderSide(
                    color: _descriptionError != null
                        ? NovaColors.error(context)
                        : NovaColors.border(context),
                  ),
                ),
              ),
              style: NovaTextStyles.body,
            ),
            const SizedBox(height: NovaSpacing.xl),

            // Resubmit button
            AdaptiveButton(
              onPressed: isSubmitting || _descriptionError != null
                  ? null
                  : _showResubmitDialog,
              variant: AdaptiveButtonVariant.primary,
              label: isSubmitting ? 'Invio in corso...' : 'Ri-sottometti Evento',
              icon: isSubmitting ? null : Icons.send,
            ),
          ],
        ),
      ),
    );
  }
}
