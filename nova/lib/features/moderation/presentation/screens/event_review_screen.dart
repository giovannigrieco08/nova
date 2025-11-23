// =====================================================================
// EventReviewScreen - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Full event details for moderation decision
// Architecture: ConsumerWidget with moderation actions
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/moderation/data/models/moderation_event.dart';
import 'package:nova/features/moderation/presentation/providers/moderation_notifier.dart';
import 'package:nova/features/moderation/presentation/widgets/rejection_dialog.dart';
import 'package:nova/features/moderation/data/repositories/moderation_repository.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_button.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_scaffold.dart';
import 'package:nova/shared/widgets/adaptive/adaptive_app_bar.dart';

/// Event review screen for moderation
///
/// Shows:
/// - Full event details (all fields)
/// - Cover image or emoji icon (large)
/// - Organizer info
/// - Re-submission badge if applicable
/// - Two action buttons: Approva (green) and Rifiuta (red)
///
/// Implements optimistic updates for instant feedback.
class EventReviewScreen extends ConsumerWidget {
  final ModerationEvent event;

  const EventReviewScreen({
    super.key,
    required this.event,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to moderation errors
    ref.listen<AsyncValue<void>>(
      moderationNotifierProvider,
      (previous, next) {
        next.whenOrNull(
          error: (error, stack) {
            _showErrorSnackbar(context, error);
          },
        );
      },
    );

    final moderationState = ref.watch(moderationNotifierProvider);
    final isProcessing = moderationState.isLoading;

    return AdaptiveScaffold(
      appBar: AdaptiveAppBar(
        title: const Text('Revisiona evento'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(NovaSpacing.l),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Re-submission badge (if applicable)
            if (event.isResubmission) ...[
              Container(
                padding: const EdgeInsets.all(NovaSpacing.m),
                decoration: BoxDecoration(
                  color: NovaColors.warning(context).withOpacity(0.1),
                  borderRadius: NovaRadius.circularS,
                  border: Border.all(
                    color: NovaColors.warning(context),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.refresh,
                      color: NovaColors.warning(context),
                      size: 20,
                    ),
                    const SizedBox(width: NovaSpacing.s),
                    Expanded(
                      child: Text(
                        'Evento risottomesso (${event.submissionCount}ª volta)',
                        style: NovaTextStyles.body.copyWith(
                          color: NovaColors.warning(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: NovaSpacing.l),
            ],

            // Event icon/image
            _buildEventMedia(context),
            const SizedBox(height: NovaSpacing.l),

            // Event title
            Text(
              event.title,
              style: NovaTextStyles.h1.copyWith(
                color: NovaColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.s),

            // Organizer
            Text(
              'Organizzatore: ${event.organizerName}',
              style: NovaTextStyles.bodyBold.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
            const SizedBox(height: NovaSpacing.l),

            // Description
            _buildSection(
              context,
              title: 'Descrizione',
              content: event.description,
            ),

            // Date and time
            _buildSection(
              context,
              title: 'Data e ora',
              content: event.formattedDateRange,
            ),

            // Location
            if (event.location != null)
              _buildSection(
                context,
                title: 'Luogo',
                content: event.location!,
              ),

            // Category
            _buildSection(
              context,
              title: 'Categoria',
              content: event.category,
            ),

            // Submission time
            _buildSection(
              context,
              title: 'Inviato',
              content: event.timeSinceSubmission,
            ),

            const SizedBox(height: NovaSpacing.xxl),

            // Action buttons
            Row(
              children: [
                // Reject button
                Expanded(
                  child: AdaptiveButton(
                    type: AdaptiveButtonType.destructive,
                    onPressed: isProcessing ? null : () => _handleReject(context, ref),
                    child: Text(
                      'Rifiuta',
                      style: NovaTextStyles.button.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: NovaSpacing.m),

                // Approve button
                Expanded(
                  child: AdaptiveButton(
                    type: AdaptiveButtonType.primary,
                    onPressed: isProcessing ? null : () => _handleApprove(context, ref),
                    child: Text(
                      'Approva',
                      style: NovaTextStyles.button.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: NovaSpacing.xxl),
          ],
        ),
      ),
    );
  }

  /// Build event media (image or emoji)
  Widget _buildEventMedia(BuildContext context) {
    if (event.coverImageUrl != null) {
      // Cover image
      return ClipRRect(
        borderRadius: NovaRadius.circularM,
        child: Image.network(
          event.coverImageUrl!,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(context);
          },
        ),
      );
    } else if (event.emojiIcon != null) {
      // Emoji icon (large)
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: NovaColors.primary(context).withOpacity(0.1),
          borderRadius: NovaRadius.circularM,
        ),
        child: Center(
          child: Text(
            event.emojiIcon!,
            style: const TextStyle(fontSize: 96),
          ),
        ),
      );
    } else {
      // Fallback placeholder
      return _buildPlaceholder(context);
    }
  }

  /// Build placeholder for missing media
  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: NovaColors.divider(context),
        borderRadius: NovaRadius.circularM,
      ),
      child: Center(
        child: Icon(
          Icons.event,
          size: 64,
          color: NovaColors.textTertiary(context),
        ),
      ),
    );
  }

  /// Build section with title and content
  Widget _buildSection(
    BuildContext context, {
    required String title,
    required String content,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: NovaSpacing.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: NovaTextStyles.bodyBold.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: NovaSpacing.xs),
          Text(
            content,
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Handle approve button tap
  Future<void> _handleApprove(BuildContext context, WidgetRef ref) async {
    final notifier = ref.read(moderationNotifierProvider.notifier);

    await notifier.approveEvent(event);

    // On success, pop back to dashboard
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Evento approvato!',
            style: NovaTextStyles.body.copyWith(color: Colors.white),
          ),
          backgroundColor: NovaColors.successLight,
        ),
      );
    }
  }

  /// Handle reject button tap
  Future<void> _handleReject(BuildContext context, WidgetRef ref) async {
    // Show rejection dialog
    final reason = await RejectionDialog.show(context, event.title);

    if (reason == null || reason.isEmpty) {
      // Cancelled or no reason provided
      return;
    }

    // Perform rejection
    final notifier = ref.read(moderationNotifierProvider.notifier);
    await notifier.rejectEvent(event, reason);

    // On success, pop back to dashboard
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Evento rifiutato',
            style: NovaTextStyles.body.copyWith(color: Colors.white),
          ),
          backgroundColor: NovaColors.errorLight,
        ),
      );
    }
  }

  /// Show error snackbar for moderation errors
  void _showErrorSnackbar(BuildContext context, Object error) {
    String message;

    if (error is EventAlreadyModeratedException) {
      message = 'Questo evento è già stato moderato da un altro moderatore.';
    } else if (error is ConcurrentModerationException) {
      message = 'Un altro moderatore sta revisionando questo evento.';
    } else if (error is SelfModerationException) {
      message = 'Non puoi moderare i tuoi eventi.';
    } else {
      message = 'Errore durante la moderazione. Riprova.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: NovaTextStyles.body.copyWith(color: Colors.white),
        ),
        backgroundColor: NovaColors.errorLight,
        duration: const Duration(seconds: 4),
      ),
    );
  }
}
