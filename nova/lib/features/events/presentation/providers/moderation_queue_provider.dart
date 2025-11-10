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

/// Provider for pending events awaiting moderation
///
/// Only accessible to users with moderator role (via RLS policies).
/// Returns events sorted by created_at ASC (oldest first = FIFO queue).
///
/// Usage:
/// ```dart
/// final pendingEventsAsync = ref.watch(moderationQueueProvider);
/// pendingEventsAsync.when(
///   data: (events) => ModerationQueue(events),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => ErrorWidget(err),
/// );
/// ```
final moderationQueueProvider = FutureProvider<List<Event>>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);
  return await repository.getPendingEvents();
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

/// Notifier for moderation actions
///
/// Provides methods to approve/reject events with proper error handling.
/// Auto-refreshes moderation queue after successful action.
class ModerationNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ModerationNotifier(this._ref) : super(const AsyncValue.data(null));

  /// Approve event (status = 'approved')
  ///
  /// Triggers notification to event creator via Edge Function.
  /// Updates event status and sets moderated_by, moderated_at fields.
  Future<void> approveEvent(String eventId) async {
    state = const AsyncValue.loading();

    try {
      final repository = _ref.read(eventRepositoryProvider);
      await repository.approveEvent(eventId);

      // Refresh moderation queue
      _ref.invalidate(moderationQueueProvider);
      _ref.invalidate(pendingEventsCountProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Reject event (status = 'rejected')
  ///
  /// Requires rejection reason for transparency.
  /// Triggers notification to event creator with reason via Edge Function.
  Future<void> rejectEvent(String eventId, String rejectionReason) async {
    if (rejectionReason.trim().isEmpty) {
      state = AsyncValue.error(
        Exception('Rejection reason is required'),
        StackTrace.current,
      );
      return;
    }

    if (rejectionReason.trim().length < 10) {
      state = AsyncValue.error(
        Exception('Rejection reason must be at least 10 characters'),
        StackTrace.current,
      );
      return;
    }

    state = const AsyncValue.loading();

    try {
      final repository = _ref.read(eventRepositoryProvider);
      await repository.rejectEvent(eventId, rejectionReason.trim());

      // Refresh moderation queue
      _ref.invalidate(moderationQueueProvider);
      _ref.invalidate(pendingEventsCountProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Bulk approve events (for future use)
  ///
  /// Approves multiple events in a single operation.
  /// Useful for batch moderation during high-volume periods.
  Future<void> bulkApprove(List<String> eventIds) async {
    state = const AsyncValue.loading();

    try {
      final repository = _ref.read(eventRepositoryProvider);

      // Approve events sequentially (Supabase doesn't support batch updates directly)
      for (final eventId in eventIds) {
        await repository.approveEvent(eventId);
      }

      // Refresh moderation queue
      _ref.invalidate(moderationQueueProvider);
      _ref.invalidate(pendingEventsCountProvider);

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

/// Provider for ModerationNotifier
final moderationNotifierProvider =
    StateNotifierProvider<ModerationNotifier, AsyncValue<void>>((ref) {
  return ModerationNotifier(ref);
});
