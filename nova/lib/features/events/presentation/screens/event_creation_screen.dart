// Screen: EventCreationScreen
// Feature: 004-event-creation-moderation (US1 - Event Creation)
// Purpose: Main screen for creating new events with form and submission
//
// Features:
// - AppBar with "Crea evento" title
// - EventForm widget (scrollable)
// - Bottom bar with "Crea evento" button (disabled if invalid)
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
import '../providers/events_feed_provider.dart';
import '../widgets/event_form.dart';
import '../../domain/entities/event.dart';

/// Event creation/edit screen
class EventCreationScreen extends ConsumerStatefulWidget {
  /// If provided, the screen will be in edit mode with this event's data
  final Event? eventToEdit;

  const EventCreationScreen({
    super.key,
    this.eventToEdit,
  });

  @override
  ConsumerState<EventCreationScreen> createState() => _EventCreationScreenState();
}

class _EventCreationScreenState extends ConsumerState<EventCreationScreen> {
  bool _initialized = false;

  bool get isEditMode => widget.eventToEdit != null;

  @override
  void initState() {
    super.initState();
    // Initialize form with event data if in edit mode
    if (widget.eventToEdit != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_initialized) {
          _initialized = true;
          ref.read(eventCreationProvider.notifier).loadEventForEdit(widget.eventToEdit!);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(eventCreationProvider);
    final notifier = ref.read(eventCreationProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: NovaColors.textPrimary(context),
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Indietro',
        ),
        title: Text(
          isEditMode ? 'Modifica evento' : 'Crea evento',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: NovaColors.background(context),
        foregroundColor: NovaColors.textPrimary(context),
        actions: [
          // Clear/Reset button
          if (state.title.isNotEmpty || state.description.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh_outlined),
              tooltip: 'Aggiorna',
              onPressed: () => _showClearConfirmation(context, notifier),
            ),
        ],
      ),
      body: AbsorbPointer(
        // Disable interactions during submission
        absorbing: state.isSubmitting,
        child: const EventForm(),
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
    // Debug: log validation state
    debugPrint('=== EVENT FORM VALIDATION ===');
    debugPrint('Title: "${state.title}" (${state.title.trim().length} chars, needs 5-100)');
    debugPrint('Description: "${state.description.length > 50 ? state.description.substring(0, 50) + '...' : state.description}" (${state.description.trim().length} chars, needs 20-500)');
    debugPrint('Event date: ${state.eventDate} (needs future date)');
    debugPrint('Has image: ${state.imageFile != null || state.imagePath != null}');
    debugPrint('Title error: ${state.titleError}');
    debugPrint('Description error: ${state.descriptionError}');
    debugPrint('Date error: ${state.eventDateError}');
    debugPrint('Image error: ${state.imageError}');
    debugPrint('isValid: ${state.isValid}');
    debugPrint('isSubmitting: ${state.isSubmitting}');
    debugPrint('=============================');

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
            // Validation status (debug info for user)
            if (!state.isValid && !state.isSubmitting) ...[
              Container(
                padding: EdgeInsets.all(NovaSpacing.m),
                margin: EdgeInsets.only(bottom: NovaSpacing.m),
                decoration: BoxDecoration(
                  color: NovaColors.warning(context).withValues(alpha: 0.1),
                  borderRadius: NovaRadius.circularM,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: NovaColors.warning(context),
                      size: 20,
                    ),
                    SizedBox(width: NovaSpacing.s),
                    Expanded(
                      child: Text(
                        _getValidationMessage(state),
                        style: NovaTextStyles.caption.copyWith(
                          color: NovaColors.warning(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Error message (if any)
            if (state.submitError != null) ...[
              Container(
                padding: EdgeInsets.all(NovaSpacing.m),
                margin: EdgeInsets.only(bottom: NovaSpacing.m),
                decoration: BoxDecoration(
                  color: NovaColors.error(context).withValues(alpha: 0.1),
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
                  foregroundColor: NovaColors.onPrimaryLight,
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
                          valueColor: const AlwaysStoppedAnimation<Color>(NovaColors.onPrimaryLight),
                        ),
                      )
                    : Text(
                        isEditMode ? 'Salva modifiche' : 'Crea evento',
                        style: const TextStyle(
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

  /// Submit form (create or update)
  Future<void> _submitForm(
    BuildContext context,
    EventCreationNotifier notifier,
  ) async {
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    Event? event;
    if (isEditMode) {
      event = await notifier.updateEvent(widget.eventToEdit!.id);
    } else {
      event = await notifier.createEvent();
    }

    if (event != null) {
      // Refresh the feed to show the new/updated event
      ref.invalidate(eventsFeedProvider);
      ref.invalidate(userPendingEventsProvider);

      // Navigate back immediately
      navigator.pop(event); // Return the updated event

      // Show success message after navigation
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            isEditMode
              ? 'Evento modificato con successo'
              : 'Evento creato! Sarà visibile dopo l\'approvazione del moderatore',
          ),
          backgroundColor: NovaColors.successLight,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    // Error is already shown in bottom bar via submitError
  }

  /// Get human-readable validation message
  String _getValidationMessage(EventFormState state) {
    final issues = <String>[];

    if (state.title.trim().length < 5) {
      issues.add('Titolo troppo corto (min 5 caratteri)');
    } else if (state.title.trim().length > 100) {
      issues.add('Titolo troppo lungo (max 100 caratteri)');
    }

    if (state.description.trim().length < 20) {
      issues.add('Descrizione troppo corta (min 20 caratteri)');
    } else if (state.description.trim().length > 500) {
      issues.add('Descrizione troppo lunga (max 500 caratteri)');
    }

    if (state.eventDate == null) {
      issues.add('Seleziona una data');
    } else if (state.eventDate!.isBefore(DateTime.now())) {
      issues.add('La data deve essere futura');
    }

    if (state.imageFile == null && state.imagePath == null) {
      issues.add('Aggiungi un\'immagine');
    }

    if (issues.isEmpty) {
      return 'Tutti i campi sono validi';
    }

    return issues.join(' • ');
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
