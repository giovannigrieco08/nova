// =====================================================================
// Resubmit Event Notifier - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Handle event re-submission after rejection
// Architecture: Riverpod AutoDisposeNotifier with error handling
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/features/events/presentation/providers/repository_providers.dart';
import 'package:nova/features/events/presentation/providers/my_events_provider.dart';

/// State for event re-submission actions
class ResubmitEventState {
  final bool isLoading;
  final String? error;
  final String? successMessage;

  const ResubmitEventState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  ResubmitEventState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
  }) {
    return ResubmitEventState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      successMessage: successMessage,
    );
  }
}

/// Notifier for event re-submission
///
/// Handles resubmitting rejected events with updated descriptions.
/// Invalidates myEventsProvider to refresh the event list.
class ResubmitEventNotifier extends AutoDisposeNotifier<ResubmitEventState> {
  @override
  ResubmitEventState build() {
    return const ResubmitEventState();
  }

  /// Resubmit rejected event with updated description
  ///
  /// Steps:
  /// 1. Validate description (minimum 20 characters)
  /// 2. Call repository.resubmitEvent()
  /// 3. Invalidate myEventsProvider to refresh UI
  /// 4. Update state with success/error
  Future<void> resubmit(String eventId, String newDescription) async {
    // Validate description
    if (newDescription.trim().length < 20) {
      state = state.copyWith(
        error: 'La descrizione deve contenere almeno 20 caratteri.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null, successMessage: null);

    try {
      final repository = ref.read(eventRepositoryProvider);
      await repository.resubmitEvent(eventId, newDescription);

      // Invalidate myEventsProvider to refresh the list
      ref.invalidate(myEventsProvider);

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Evento ri-sottomesso per la moderazione.',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Errore durante la ri-sottomissione: $e',
      );
    }
  }

  /// Clear error and success messages
  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

/// Provider for resubmit event notifier
final resubmitEventNotifierProvider =
    NotifierProvider.autoDispose<ResubmitEventNotifier, ResubmitEventState>(
  ResubmitEventNotifier.new,
);
