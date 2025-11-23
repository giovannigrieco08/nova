// Provider: EventsFeedProvider
// Feature: 003-events-feed
// Purpose: Riverpod state management for events feed with pagination

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive/hive.dart';
import '../../data/data_sources/events_local_data_source.dart';
import '../../data/data_sources/events_remote_data_source.dart';
import '../../data/models/event_model.dart';
import '../../data/repositories/events_repository.dart';
import '../../domain/usecases/get_events_feed.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/offline_action.dart';

// ========================================================================
// DEPENDENCY PROVIDERS
// ========================================================================

/// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Events cache Hive box provider
final eventsCacheBoxProvider = Provider<Box<EventModel>>((ref) {
  return Hive.box<EventModel>('events_cache');
});

/// Offline actions queue Hive box provider
final offlineActionsBoxProvider = Provider<Box<OfflineAction>>((ref) {
  return Hive.box<OfflineAction>('offline_actions_queue');
});

/// Events local data source provider
final eventsLocalDataSourceProvider = Provider<EventsLocalDataSource>((ref) {
  final eventsBox = ref.watch(eventsCacheBoxProvider);
  final offlineActionsBox = ref.watch(offlineActionsBoxProvider);
  return EventsLocalDataSource(
    eventsBox: eventsBox,
    offlineActionsBox: offlineActionsBox,
  );
});

/// Events remote data source provider
final eventsRemoteDataSourceProvider = Provider<EventsRemoteDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return EventsRemoteDataSource(supabase: supabase);
});

/// Events repository provider
final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  final localDataSource = ref.watch(eventsLocalDataSourceProvider);
  final remoteDataSource = ref.watch(eventsRemoteDataSourceProvider);
  return EventsRepository(
    localDataSource: localDataSource,
    remoteDataSource: remoteDataSource,
  );
});

/// Get events feed use case provider
final getEventsFeedUseCaseProvider = Provider<GetEventsFeed>((ref) {
  final repository = ref.watch(eventsRepositoryProvider);
  return GetEventsFeed(repository: repository);
});

// ========================================================================
// EVENTS FEED STATE
// ========================================================================

/// Events feed state with pagination metadata
class EventsFeedState {
  final List<Event> events;
  final int currentPage;
  final bool hasMore;
  final bool isLoadingMore;
  final String? error;

  const EventsFeedState({
    this.events = const [],
    this.currentPage = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.error,
  });

  EventsFeedState copyWith({
    List<Event>? events,
    int? currentPage,
    bool? hasMore,
    bool? isLoadingMore,
    String? error,
  }) {
    return EventsFeedState(
      events: events ?? this.events,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: error,
    );
  }
}

// ========================================================================
// EVENTS FEED PROVIDER (AsyncNotifier)
// ========================================================================

/// Events feed provider with infinite scroll pagination
final eventsFeedProvider =
    AsyncNotifierProvider<EventsFeedNotifier, EventsFeedState>(() {
  return EventsFeedNotifier();
});

class EventsFeedNotifier extends AsyncNotifier<EventsFeedState> {
  static const int _pageSize = 20; // Events per page

  @override
  Future<EventsFeedState> build() async {
    // Initial load - fetch first page
    return await _loadPage(1, isRefresh: false);
  }

  /// Load a specific page of events
  Future<EventsFeedState> _loadPage(int page, {required bool isRefresh}) async {
    try {
      final getEventsFeed = ref.read(getEventsFeedUseCaseProvider);
      final events = await getEventsFeed.execute(
        page: page,
        limit: _pageSize,
        forceRefresh: isRefresh,
      );

      // Check if there are more pages
      final hasMore = events.length == _pageSize;

      return EventsFeedState(
        events: events,
        currentPage: page,
        hasMore: hasMore,
        isLoadingMore: false,
        error: null,
      );
    } catch (e) {
      return EventsFeedState(
        events: const [],
        currentPage: 0,
        hasMore: false,
        isLoadingMore: false,
        error: _formatError(e),
      );
    }
  }

  /// Load next page (infinite scroll pagination)
  Future<void> loadNextPage() async {
    final currentState = state.valueOrNull;
    if (currentState == null) return;

    // Don't load if already loading or no more pages
    if (currentState.isLoadingMore || !currentState.hasMore) return;

    // Set loading state
    state = AsyncData(currentState.copyWith(isLoadingMore: true));

    try {
      final nextPage = currentState.currentPage + 1;
      final getEventsFeed = ref.read(getEventsFeedUseCaseProvider);
      final newEvents = await getEventsFeed.execute(
        page: nextPage,
        limit: _pageSize,
      );

      // Check if there are more pages
      final hasMore = newEvents.length == _pageSize;

      // Append new events to existing list
      final updatedEvents = [...currentState.events, ...newEvents];

      state = AsyncData(EventsFeedState(
        events: updatedEvents,
        currentPage: nextPage,
        hasMore: hasMore,
        isLoadingMore: false,
        error: null,
      ));
    } catch (e) {
      // Keep existing events but show error
      state = AsyncData(currentState.copyWith(
        isLoadingMore: false,
        error: _formatError(e),
      ));
    }
  }

  /// Refresh feed (pull-to-refresh)
  Future<void> refresh() async {
    // Reset to page 1 and reload
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadPage(1, isRefresh: true));
  }

  /// Format error message for display
  String _formatError(Object error) {
    if (error is PostgrestException) {
      return 'Database error: ${error.message}';
    } else if (error is AuthException) {
      return 'Authentication error: ${error.message}';
    } else if (error.toString().contains('SocketException') ||
        error.toString().contains('NetworkException')) {
      return 'No internet connection. Showing cached events.';
    } else {
      return 'An error occurred. Please try again.';
    }
  }
}

// ========================================================================
// SCROLL POSITION PROVIDER
// ========================================================================

/// Stores the scroll position for the events feed to preserve it during navigation
final eventsFeedScrollPositionProvider = StateProvider<double>((ref) => 0.0);
