// =====================================================================
// Nova - Event Detail Provider
// =====================================================================
// Purpose: Manage event detail state with Realtime updates
// Architecture: Riverpod AsyncNotifier with Supabase Realtime subscription
// =====================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/event.dart';
import '../../data/repositories/events_repository.dart';
import 'events_feed_provider.dart'; // For eventsRepositoryProvider and supabaseClientProvider

/// Provider for single event detail with Realtime updates
///
/// Usage:
/// ```dart
/// final eventAsync = ref.watch(eventDetailProvider('event-id'));
/// eventAsync.when(
///   data: (event) => EventDetailScreen(event: event),
///   loading: () => LoadingIndicator(),
///   error: (err, stack) => ErrorScreen(error: err),
/// );
/// ```
final eventDetailProvider = AsyncNotifierProvider.family<EventDetailNotifier, Event, String>(
  EventDetailNotifier.new,
);

/// Event detail state notifier with Realtime subscription
///
/// Responsibilities:
/// - Load event by ID from repository (cache-first)
/// - Subscribe to Realtime updates from Supabase
/// - Handle refresh for pull-to-refresh
/// - Manage loading/error states
/// - Clean up subscriptions on dispose
class EventDetailNotifier extends FamilyAsyncNotifier<Event, String> {
  /// Repository instance
  late final EventsRepository _repository;

  /// Supabase client for Realtime
  late final SupabaseClient _supabase;

  /// Realtime subscription channel
  RealtimeChannel? _realtimeChannel;

  /// Event ID (from family parameter)
  String get eventId => arg;

  @override
  Future<Event> build(String arg) async {
    // Get dependencies
    _repository = ref.read(eventsRepositoryProvider);
    _supabase = ref.read(supabaseClientProvider);

    // Debug logging
    assert(() {
      debugPrint('🔧 EventDetailNotifier: Initializing for event $eventId');
      return true;
    }());

    // Setup Realtime subscription
    _setupRealtimeSubscription();

    // Clean up subscription when provider is disposed
    ref.onDispose(() {
      if (_realtimeChannel != null) {
        assert(() {
          debugPrint('🧹 EventDetailNotifier: Cleaning up Realtime subscription');
          return true;
        }());
        _supabase.removeChannel(_realtimeChannel!);
        _realtimeChannel = null;
      }
    });

    // Load event from repository (cache-first)
    try {
      final event = await _repository.getEventById(eventId);

      assert(() {
        debugPrint('✅ EventDetailNotifier: Event loaded - ${event.title}');
        return true;
      }());

      return event;
    } catch (e) {
      assert(() {
        debugPrint('❌ EventDetailNotifier: Failed to load event - $e');
        return true;
      }());

      throw Exception('Failed to load event: ${_formatError(e)}');
    }
  }

  /// Setup Realtime subscription for event updates
  ///
  /// Listens to:
  /// - UPDATE events on this specific event
  /// - Automatically updates state when event changes
  void _setupRealtimeSubscription() {
    // Clean up existing subscription
    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
      _realtimeChannel = null;
    }

    // Create channel for this event
    _realtimeChannel = _supabase.channel('event_detail_$eventId');

    // Subscribe to UPDATE events for this event
    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'events',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: eventId,
          ),
          callback: (payload) {
            assert(() {
              debugPrint('🔔 EventDetailNotifier: Event updated via Realtime');
              debugPrint('   Payload: ${payload.newRecord}');
              return true;
            }());

            // Reload event from repository to get fresh data
            _reloadEvent();
          },
        )
        .subscribe();

    assert(() {
      debugPrint('📡 EventDetailNotifier: Realtime subscription active');
      return true;
    }());
  }

  /// Reload event from repository (for Realtime updates)
  Future<void> _reloadEvent() async {
    try {
      // Fetch fresh data from repository
      final event = await _repository.getEventById(
        eventId,
        forceRefresh: true, // Bypass cache
      );

      // Update state with new data
      state = AsyncData(event);

      assert(() {
        debugPrint('✅ EventDetailNotifier: Event reloaded after Realtime update');
        return true;
      }());
    } catch (e) {
      assert(() {
        debugPrint('❌ EventDetailNotifier: Failed to reload after Realtime update - $e');
        return true;
      }());

      // Don't update state to error - keep showing stale data
    }
  }

  /// Refresh event data (for pull-to-refresh)
  ///
  /// Returns:
  /// - Refreshed event on success
  ///
  /// Throws:
  /// - Exception on failure
  ///
  /// Usage:
  /// ```dart
  /// await ref.read(eventDetailProvider(eventId).notifier).refresh();
  /// ```
  Future<Event> refresh() async {
    assert(() {
      debugPrint('🔄 EventDetailNotifier: Refreshing event $eventId');
      return true;
    }());

    try {
      // Fetch fresh data (force network)
      final event = await _repository.getEventById(
        eventId,
        forceRefresh: true,
      );

      // Update state
      state = AsyncData(event);

      assert(() {
        debugPrint('✅ EventDetailNotifier: Event refreshed successfully');
        return true;
      }());

      return event;
    } catch (e, stackTrace) {
      assert(() {
        debugPrint('❌ EventDetailNotifier: Refresh failed - $e');
        return true;
      }());

      // Update state to error
      state = AsyncError(e, stackTrace);

      throw Exception('Failed to refresh event: ${_formatError(e)}');
    }
  }

  /// Format error message for user-friendly display
  String _formatError(Object error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') || errorString.contains('connection')) {
      return 'Network error. Please check your internet connection.';
    }

    if (errorString.contains('not found') || errorString.contains('404')) {
      return 'Event not found. It may have been deleted.';
    }

    if (errorString.contains('unauthorized') || errorString.contains('403')) {
      return 'You do not have permission to view this event.';
    }

    if (errorString.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }

    return 'An unexpected error occurred. Please try again.';
  }
}
