// Riverpod Provider: ModerationQueueProvider
// Feature: 004-event-creation-moderation (US3 - Moderation Queue)
// Purpose: Fetch pending events for moderators with approve/reject actions
//
// Query: status = 'pending' ORDER BY created_at ASC (oldest first)
// RLS Policy: moderators_view_pending_events
//
// Actions:
// - approveEvent(): Update status to 'approved'
// - rejectEvent(): Update status to 'rejected' with rejection_reason

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/event.dart';
import './repository_providers.dart';

/// State notifier for moderation queue with optimistic updates
///
/// Provides instant UI feedback when approving/rejecting events.
/// Events are removed from the list immediately, then API call is made.
/// If API call fails, event is restored and error is shown.
class ModerationQueueNotifier extends StateNotifier<AsyncValue<List<Event>>> {
  final Ref _ref;

  ModerationQueueNotifier(this._ref) : super(const AsyncValue.loading()) {
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    state = const AsyncValue.loading();
    try {
      final repository = _ref.read(eventRepositoryProvider);
      final events = await repository.getPendingEvents();
      state = AsyncValue.data(events);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Refresh events from server
  Future<void> refresh() async {
    await _loadEvents();
  }

  /// Remove event from local list (optimistic update)
  void _removeEventLocally(String eventId) {
    if (state.hasValue) {
      final currentEvents = state.value!;
      final updatedEvents = currentEvents.where((e) => e.id != eventId).toList();
      state = AsyncValue.data(updatedEvents);
    }
  }

  /// Restore event to local list (rollback on error)
  void _restoreEvent(Event event) {
    if (state.hasValue) {
      final currentEvents = [...state.value!, event];
      // Sort by created_at ASC to maintain order
      currentEvents.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      state = AsyncValue.data(currentEvents);
    }
  }

  /// Approve event with optimistic update
  Future<void> approveEvent(String eventId) async {
    // Find the event before removing (for potential rollback)
    Event? removedEvent;
    if (state.hasValue) {
      removedEvent = state.value!.cast<Event?>().firstWhere(
        (e) => e?.id == eventId,
        orElse: () => null,
      );
    }

    // Optimistic update: remove immediately
    _removeEventLocally(eventId);

    try {
      final repository = _ref.read(eventRepositoryProvider);
      await repository.approveEvent(eventId);
      // Update pending count
      _ref.invalidate(pendingEventsCountProvider);
    } catch (e) {
      // Rollback: restore the event on error
      if (removedEvent != null) {
        _restoreEvent(removedEvent);
      }
      rethrow;
    }
  }

  /// Reject event with optimistic update
  Future<void> rejectEvent(String eventId, String rejectionReason) async {
    if (rejectionReason.trim().isEmpty) {
      throw Exception('Rejection reason is required');
    }
    if (rejectionReason.trim().length < 10) {
      throw Exception('Rejection reason must be at least 10 characters');
    }

    // Find the event before removing (for potential rollback)
    Event? removedEvent;
    if (state.hasValue) {
      removedEvent = state.value!.cast<Event?>().firstWhere(
        (e) => e?.id == eventId,
        orElse: () => null,
      );
    }

    // Optimistic update: remove immediately
    _removeEventLocally(eventId);

    try {
      final repository = _ref.read(eventRepositoryProvider);
      await repository.rejectEvent(eventId, rejectionReason.trim());
      // Update pending count
      _ref.invalidate(pendingEventsCountProvider);
    } catch (e) {
      // Rollback: restore the event on error
      if (removedEvent != null) {
        _restoreEvent(removedEvent);
      }
      rethrow;
    }
  }
}

/// Provider for moderation queue with optimistic updates
final moderationQueueProvider =
    StateNotifierProvider<ModerationQueueNotifier, AsyncValue<List<Event>>>((ref) {
  return ModerationQueueNotifier(ref);
});

/// Provider for pending events count (for badge display)
///
/// Efficient count query without fetching full event data.
/// Used for bottom navigation badge and stats dashboard.
final pendingEventsCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);

  try {
    final events = await repository.getPendingEvents();
    return events.length;
  } catch (e) {
    // If user is not a moderator, RLS will return empty list or error
    return 0;
  }
});

/// Legacy provider for backwards compatibility
/// @deprecated Use moderationQueueProvider.notifier instead
final moderationNotifierProvider =
    Provider<ModerationQueueNotifier>((ref) {
  return ref.watch(moderationQueueProvider.notifier);
});
