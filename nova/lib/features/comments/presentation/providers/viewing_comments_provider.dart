import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ViewingCommentsProvider
///
/// Tracks which event's comments the user is currently viewing.
/// Used to suppress in-app notification banners when user is already
/// seeing real-time updates in the CommentsSheet.
///
/// **T128**: Handle edge cases - don't show notification if already viewing
///
/// Usage:
/// ```dart
/// // When opening comments sheet
/// ref.read(viewingCommentsProvider.notifier).startViewing(eventId);
///
/// // When closing comments sheet
/// ref.read(viewingCommentsProvider.notifier).stopViewing(eventId);
///
/// // When deciding whether to show notification
/// final viewingState = ref.read(viewingCommentsProvider);
/// if (!viewingState.isViewing(eventId)) {
///   showNotificationBanner(...);
/// }
/// ```
class ViewingCommentsNotifier extends StateNotifier<ViewingCommentsState> {
  ViewingCommentsNotifier() : super(const ViewingCommentsState());

  /// Start viewing comments for an event
  void startViewing(String eventId) {
    state = state.copyWith(
      viewingEventIds: {...state.viewingEventIds, eventId},
    );
  }

  /// Stop viewing comments for an event
  void stopViewing(String eventId) {
    final newSet = Set<String>.from(state.viewingEventIds)..remove(eventId);
    state = state.copyWith(viewingEventIds: newSet);
  }

  /// Clear all viewing state (e.g., on logout)
  void clearAll() {
    state = const ViewingCommentsState();
  }
}

/// State tracking which events' comments are being viewed
class ViewingCommentsState {
  /// Set of event IDs whose comments are currently being viewed
  final Set<String> viewingEventIds;

  const ViewingCommentsState({
    this.viewingEventIds = const {},
  });

  /// Check if currently viewing comments for a specific event
  bool isViewing(String eventId) => viewingEventIds.contains(eventId);

  /// Check if viewing any comments
  bool get isViewingAny => viewingEventIds.isNotEmpty;

  ViewingCommentsState copyWith({
    Set<String>? viewingEventIds,
  }) {
    return ViewingCommentsState(
      viewingEventIds: viewingEventIds ?? this.viewingEventIds,
    );
  }
}

/// Provider for tracking which comments are being viewed
final viewingCommentsProvider =
    StateNotifierProvider<ViewingCommentsNotifier, ViewingCommentsState>(
  (ref) => ViewingCommentsNotifier(),
);

/// Simple provider to check if viewing comments for a specific event
///
/// Usage:
/// ```dart
/// final isViewing = ref.watch(isViewingCommentsProvider(eventId));
/// ```
final isViewingCommentsProvider = Provider.family<bool, String>((ref, eventId) {
  return ref.watch(viewingCommentsProvider).isViewing(eventId);
});
