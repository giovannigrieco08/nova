// Screen: EventCreationScreen
// Feature: 004-event-creation-moderation (US1 - Event Creation)
// Purpose: Main screen for creating new events with form and submission
//
// Features:
// - AppBar with "Crea Evento" title
// - EventForm widget (scrollable)
// - Bottom bar with "Crea Evento" button (disabled if invalid)
// - Loading overlay during submission
// - Success SnackBar navigation on success
// - Error handling with SnackBar
// - Draft restoration on init

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../providers/event_creation_provider.dart';
import '../widgets/event_form.dart';

/// Event creation screen
class EventCreationScreen extends ConsumerStatefulWidget {
  const EventCreationScreen({super.key});

  @override
  ConsumerState<EventCreationScreen> createState() => _EventCreationScreenState();
}

class _EventCreationScreenState extends ConsumerState<EventCreationScreen> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventCreationProvider);
    final notifier = ref.read(eventCreationProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crea Evento'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NovaColors.background(context),
        foregroundColor: NovaColors.textPrimary(context),
        actions: [
          // Clear/Reset button
          if (state.title.isNotEmpty || state.description.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'Ricomincia',
              onPressed: () => _showClearConfirmation(context, notifier),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Form
          const EventForm(),

          // Loading overlay
          if (state.isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, state, notifier),
    );
  }

  /// Bottom bar with "Crea Evento" button
  Widget _buildBottomBar(
    BuildContext context,
    EventFormState state,
    EventCreationNotifier notifier,
  ) {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.l),
      decoration: BoxDecoration(
        color: NovaColors.background(context),
        border: Border(
          top: BorderSide(
            color: NovaColors.border(context),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error message (if any)
            if (state.submitError != null) ...[
              Container(
                padding: EdgeInsets.all(NovaSpacing.m),
                margin: EdgeInsets.only(bottom: NovaSpacing.m),
                decoration: BoxDecoration(
                  color: NovaColors.error(context).withOpacity(0.1),
                  borderRadius: NovaRadius.circularM,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: NovaColors.error(context),
                      size: 20,
                    ),
                    SizedBox(width: NovaSpacing.s),
                    Expanded(
                      child: Text(
                        state.submitError!,
                        style: NovaTextStyles.caption.copyWith(
                          color: NovaColors.error(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Submit button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: state.isValid && !state.isSubmitting
                    ? () => _submitForm(context, notifier)
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NovaColors.primary(context),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: NovaColors.border(context),
                  disabledForegroundColor: NovaColors.textSecondary(context),
                  padding: EdgeInsets.symmetric(vertical: NovaSpacing.m),
                  shape: RoundedRectangleBorder(
                    borderRadius: NovaRadius.circularM,
                  ),
                  elevation: 0,
                ),
                child: state.isSubmitting
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Crea Evento',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Submit form
  Future<void> _submitForm(
    BuildContext context,
    EventCreationNotifier notifier,
  ) async {
    final event = await notifier.createEvent();

    if (event != null && mounted) {
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '✅ Evento creato! Sarà visibile dopo l\'approvazione del moderatore',
          ),
          backgroundColor: NovaColors.success(context),
          duration: const Duration(seconds: 3),
        ),
      );

      // Navigate back to feed
      Navigator.pop(context);
    }
    // Error is already shown in bottom bar via submitError
  }

  /// Show confirmation dialog before clearing form
  Future<void> _showClearConfirmation(
    BuildContext context,
    EventCreationNotifier notifier,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ricominciare?'),
        content: const Text(
          'Vuoi cancellare tutti i campi e ricominciare da zero? '
          'La bozza salvata verrà eliminata.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: NovaColors.error(context),
            ),
            child: const Text('Cancella Tutto'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      notifier.clearForm();
    }
  }
}
