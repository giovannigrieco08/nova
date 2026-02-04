import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';

import '../../domain/entities/comment.dart';
import '../../domain/usecases/subscribe_to_realtime.dart';
import 'comments_notifier.dart';

/// Provider for SubscribeToRealtime use case
final subscribeToRealtimeProvider = Provider<SubscribeToRealtime>((ref) {
  final repository = ref.read(commentsRepositoryProvider);
  return SubscribeToRealtime(repository);
});

/// Realtime connection status
enum RealtimeStatus {
  /// Connected and receiving updates
  connected,

  /// Connecting to WebSocket
  connecting,

  /// Disconnected - show fallback banner
  disconnected,

  /// Error occurred - show retry option
  error,
}

/// State for realtime comments
class RealtimeCommentsState {
  final List<Comment> comments;
  final RealtimeStatus status;
  final String? errorMessage;
  final Set<String> newlyAddedIds; // For highlight animation (T090)

  const RealtimeCommentsState({
    required this.comments,
    required this.status,
    this.errorMessage,
    this.newlyAddedIds = const {},
  });

  RealtimeCommentsState copyWith({
    List<Comment>? comments,
    RealtimeStatus? status,
    String? errorMessage,
    Set<String>? newlyAddedIds,
  }) {
    return RealtimeCommentsState(
      comments: comments ?? this.comments,
      status: status ?? this.status,
      errorMessage: errorMessage,
      newlyAddedIds: newlyAddedIds ?? this.newlyAddedIds,
    );
  }
}

/// Realtime comments notifier
///
/// Manages real-time comment subscription for a specific event.
/// Features:
/// - T084: Supabase Realtime subscription lifecycle
/// - T085: 100ms debouncing to prevent UI thrashing
/// - T086: Efficient diffing (only update changed items)
/// - T087: Handle INSERT, UPDATE, DELETE events
/// - T088: Connection health monitoring
/// - T089: Fallback to pull-to-refresh
/// - T090: Track newly added comments for highlight animation
class RealtimeCommentsNotifier extends StateNotifier<RealtimeCommentsState> {
  final SubscribeToRealtime _subscribeToRealtime;
  final String eventId;

  StreamSubscription<List<Comment>>? _subscription;
  Timer? _highlightClearTimer;

  RealtimeCommentsNotifier(this._subscribeToRealtime, this.eventId)
      : super(const RealtimeCommentsState(
          comments: [],
          status: RealtimeStatus.connecting,
        )) {
    _startSubscription();
  }

  /// Start real-time subscription with debouncing (T084, T085)
  void _startSubscription() {
    state = state.copyWith(status: RealtimeStatus.connecting);

    try {
      final stream = _subscribeToRealtime(eventId: eventId);

      // T085: Apply 100ms debounce to prevent UI thrashing
      _subscription =
          stream.debounceTime(const Duration(milliseconds: 100)).listen(
        (incomingComments) {
          _handleRealtimeUpdate(incomingComments);
        },
        onError: (error) {
          _handleError(error);
        },
        onDone: () {
          state = state.copyWith(status: RealtimeStatus.disconnected);
        },
      );

      state = state.copyWith(status: RealtimeStatus.connected);
    } catch (e) {
      _handleError(e);
    }
  }

  /// Handle incoming realtime update with efficient diffing (T086, T087)
  void _handleRealtimeUpdate(List<Comment> incomingComments) {
    final currentIds = state.comments.map((c) => c.id).toSet();
    final incomingIds = incomingComments.map((c) => c.id).toSet();

    // T090: Track newly added comments for highlight animation
    final newIds = incomingIds.difference(currentIds);

    // T086: Only update if there are actual changes
    if (_hasChanges(state.comments, incomingComments)) {
      state = state.copyWith(
        comments: incomingComments,
        status: RealtimeStatus.connected,
        newlyAddedIds: newIds,
      );

      // Clear highlight after animation duration (1 second)
      _highlightClearTimer?.cancel();
      _highlightClearTimer = Timer(const Duration(seconds: 1), () {
        state = state.copyWith(newlyAddedIds: {});
      });
    }
  }

  /// T086: Check if there are meaningful changes
  bool _hasChanges(List<Comment> current, List<Comment> incoming) {
    if (current.length != incoming.length) return true;

    final currentMap = {for (var c in current) c.id: c};
    for (final comment in incoming) {
      final existing = currentMap[comment.id];
      if (existing == null) return true;
      if (_commentChanged(existing, comment)) return true;
    }

    return false;
  }

  /// Compare two comments for changes
  bool _commentChanged(Comment a, Comment b) {
    return a.text != b.text ||
        a.likeCount != b.likeCount ||
        a.replyCount != b.replyCount ||
        a.isDeleted != b.isDeleted ||
        a.isHidden != b.isHidden ||
        a.updatedAt != b.updatedAt;
  }

  /// T088: Handle connection errors
  void _handleError(dynamic error) {
    state = state.copyWith(
      status: RealtimeStatus.error,
      errorMessage: _getErrorMessage(error),
    );
  }

  String _getErrorMessage(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('network') || errorStr.contains('socket')) {
      return 'Connessione interrotta. Usa pull-to-refresh per aggiornare.';
    }
    if (errorStr.contains('unauthorized')) {
      return 'Sessione scaduta. Effettua nuovamente l\'accesso.';
    }
    return 'Aggiornamenti in tempo reale non disponibili. Usa pull-to-refresh.';
  }

  /// T089: Reconnect after disconnection
  void reconnect() {
    _subscription?.cancel();
    _startSubscription();
  }

  /// Check if a comment is newly added (for highlight animation)
  bool isNewlyAdded(String commentId) {
    return state.newlyAddedIds.contains(commentId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _highlightClearTimer?.cancel();
    super.dispose();
  }
}

/// Provider family for realtime comments by event ID
///
/// Usage:
/// ```dart
/// final realtimeState = ref.watch(realtimeCommentsProvider(eventId));
/// ```
final realtimeCommentsProvider = StateNotifierProvider.autoDispose
    .family<RealtimeCommentsNotifier, RealtimeCommentsState, String>(
  (ref, eventId) {
    final subscribeToRealtime = ref.read(subscribeToRealtimeProvider);
    return RealtimeCommentsNotifier(subscribeToRealtime, eventId);
  },
);

/// Provider for realtime connection status banner visibility
///
/// Returns true if the offline banner should be shown
final showRealtimeBannerProvider =
    Provider.family<bool, String>((ref, eventId) {
  final state = ref.watch(realtimeCommentsProvider(eventId));
  return state.status == RealtimeStatus.disconnected ||
      state.status == RealtimeStatus.error;
});
