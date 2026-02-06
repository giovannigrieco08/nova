// Provider: EventLikesNotifier
// Feature: Event engagement
// Purpose: Manages local like state with optimistic updates that persist across rebuilds

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

/// Notifier that manages like state for a single event
class EventLikeNotifier extends StateNotifier<EventLikeState> {
  final Ref _ref;
  final String _eventId;
  bool _initialized = false;

  EventLikeNotifier(this._ref, this._eventId) : super(const EventLikeState());

  /// Initialize from server data (called once when engagement data is loaded)
  void initialize({required bool isLiked, required int likeCount}) {
    if (!_initialized) {
      state = EventLikeState(isLiked: isLiked, likeCount: likeCount);
      _initialized = true;
    }
  }

  /// Update from server data only if not currently processing
  /// This prevents server data from overwriting optimistic updates
  void updateFromServer({required bool isLiked, required int likeCount}) {
    if (!state.isProcessing) {
      state = state.copyWith(isLiked: isLiked, likeCount: likeCount);
      _initialized = true;
    }
  }

  /// Toggle like with optimistic update
  Future<void> toggleLike() async {
    if (state.isProcessing) return;

    final userId = _ref.read(supabaseClientProvider).auth.currentUser?.id;
    if (userId == null) return;

    // Save previous state for rollback
    final previousState = state;
    final willBeLiked = !state.isLiked;

    // Optimistic update
    state = state.copyWith(
      isLiked: willBeLiked,
      likeCount: willBeLiked ? state.likeCount + 1 : state.likeCount - 1,
      isProcessing: true,
    );

    try {
      final repository = _ref.read(eventsRepositoryProvider);
      if (willBeLiked) {
        await repository.likeEvent(eventId: _eventId, userId: userId);
      } else {
        await repository.unlikeEvent(eventId: _eventId, userId: userId);
      }
      // Success - just clear processing flag
      state = state.copyWith(isProcessing: false);
    } catch (e) {
      // Rollback on error
      state = previousState.copyWith(isProcessing: false);
      rethrow;
    }
  }

  /// Whether state has been initialized from server
  bool get isInitialized => _initialized;
}

/// Provider family for per-event like state
/// This maintains state across widget rebuilds
final eventLikeNotifierProvider =
    StateNotifierProvider.family<EventLikeNotifier, EventLikeState, String>(
  (ref, eventId) => EventLikeNotifier(ref, eventId),
);
