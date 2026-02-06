// Provider: EventLikesNotifier
// Feature: Event engagement
// Purpose: Centralized like state management that persists across widget rebuilds

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/core_providers.dart';
import '../providers/events_feed_provider.dart';

/// State for a single event's like status
class EventLikeState {
  final bool isLiked;
  final int likeCount;
  final bool isProcessing;

  const EventLikeState({
    this.isLiked = false,
    this.likeCount = 0,
    this.isProcessing = false,
  });

  EventLikeState copyWith({
    bool? isLiked,
    int? likeCount,
    bool? isProcessing,
  }) {
    return EventLikeState(
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}

/// Centralized state for all event likes
/// Uses a Map to track like state per event ID
class EventLikesState {
  final Map<String, EventLikeState> _likes;

  const EventLikesState([this._likes = const {}]);

  EventLikeState getForEvent(String eventId) {
    return _likes[eventId] ?? const EventLikeState();
  }

  EventLikesState copyWithEvent(String eventId, EventLikeState state) {
    return EventLikesState({..._likes, eventId: state});
  }

  bool isInitialized(String eventId) {
    return _likes.containsKey(eventId);
  }
}

/// Centralized notifier for all event likes
/// This single provider maintains state for all events, preventing state loss
class EventLikesNotifier extends StateNotifier<EventLikesState> {
  final Ref _ref;

  EventLikesNotifier(this._ref) : super(const EventLikesState());

  /// Initialize like state for an event (only if not already set or not processing)
  void initializeEvent({
    required String eventId,
    required bool isLiked,
    required int likeCount,
  }) {
    final current = state.getForEvent(eventId);
    // Don't overwrite if already initialized or currently processing
    if (!state.isInitialized(eventId) && !current.isProcessing) {
      state = state.copyWithEvent(
        eventId,
        EventLikeState(isLiked: isLiked, likeCount: likeCount),
      );
    }
  }

  /// Toggle like for an event with optimistic update
  Future<void> toggleLike(String eventId) async {
    final current = state.getForEvent(eventId);
    if (current.isProcessing) return;

    final userId = _ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    // Save previous state for rollback
    final previousState = current;
    final willBeLiked = !current.isLiked;

    // Optimistic update
    state = state.copyWithEvent(
      eventId,
      current.copyWith(
        isLiked: willBeLiked,
        likeCount: willBeLiked ? current.likeCount + 1 : current.likeCount - 1,
        isProcessing: true,
      ),
    );

    try {
      final repository = _ref.read(eventsRepositoryProvider);
      if (willBeLiked) {
        await repository.likeEvent(eventId: eventId, userId: userId);
      } else {
        await repository.unlikeEvent(eventId: eventId, userId: userId);
      }
      // Success - just clear processing flag
      state = state.copyWithEvent(
        eventId,
        state.getForEvent(eventId).copyWith(isProcessing: false),
      );
    } catch (e) {
      // Rollback on error
      state = state.copyWithEvent(
        eventId,
        previousState.copyWith(isProcessing: false),
      );
      rethrow;
    }
  }

  /// Get like state for a specific event
  EventLikeState getLikeState(String eventId) {
    return state.getForEvent(eventId);
  }

  /// Check if event has been initialized
  bool isEventInitialized(String eventId) {
    return state.isInitialized(eventId);
  }
}

/// Single centralized provider for all event likes
/// This never gets disposed because it's a global provider
final eventLikesProvider =
    StateNotifierProvider<EventLikesNotifier, EventLikesState>(
  (ref) => EventLikesNotifier(ref),
);
