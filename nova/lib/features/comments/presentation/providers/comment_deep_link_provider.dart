import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/deep_link_handler.dart';
import '../screens/comments_sheet.dart';

/// CommentDeepLinkProvider
///
/// Handles deep link navigation to specific comments.
///
/// **T126**: Navigate to EventDetailScreen, open CommentsSheet,
///           scroll to and highlight specific comment with fade animation
///
/// Flow:
/// 1. Receive DeepLinkInfo with eventId and commentId
/// 2. Navigate to EventDetailScreen (if not already there)
/// 3. Open CommentsSheet with targetCommentId
/// 4. CommentsSheet scrolls to and highlights the comment
class CommentDeepLinkNotifier extends StateNotifier<CommentDeepLinkState> {
  CommentDeepLinkNotifier() : super(const CommentDeepLinkState());

  /// Handle incoming comment deep link
  ///
  /// If already on the event page, just opens comments sheet.
  /// Otherwise, navigates to event page first.
  Future<void> handleDeepLink(
    BuildContext context,
    DeepLinkInfo linkInfo,
  ) async {
    if (!linkInfo.shouldOpenComments) return;

    final eventId = linkInfo.eventId;
    final commentId = linkInfo.commentId;

    if (eventId == null || commentId == null) return;

    state = state.copyWith(
      pendingEventId: eventId,
      pendingCommentId: commentId,
      isNavigating: true,
    );

    try {
      // Navigate to event detail and open comments sheet
      await _navigateToEventComments(context, eventId, commentId);
      state = state.copyWith(isNavigating: false);
    } catch (e) {
      state = state.copyWith(
        isNavigating: false,
        error: 'Impossibile aprire il commento',
      );
    }
  }

  /// Navigate to event detail and open comments sheet
  Future<void> _navigateToEventComments(
    BuildContext context,
    String eventId,
    String commentId,
  ) async {
    if (!context.mounted) return;

    // Navigate to event detail (pushNamed will handle if already there)
    await Navigator.pushNamed(
      context,
      '/event/$eventId',
      arguments: {
        'eventId': eventId,
        'openComments': true,
        'targetCommentId': commentId,
      },
    );
  }

  /// Open comments sheet with target comment
  ///
  /// Call this from EventDetailScreen when it receives deep link arguments
  void openCommentsSheet(
    BuildContext context,
    String eventId, {
    String? targetCommentId,
  }) {
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(
        eventId: eventId,
        targetCommentId: targetCommentId,
      ),
    );
  }

  /// Clear pending navigation
  void clearPending() {
    state = const CommentDeepLinkState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Comment deep link state
class CommentDeepLinkState {
  final String? pendingEventId;
  final String? pendingCommentId;
  final bool isNavigating;
  final String? error;

  const CommentDeepLinkState({
    this.pendingEventId,
    this.pendingCommentId,
    this.isNavigating = false,
    this.error,
  });

  bool get hasPending => pendingEventId != null && pendingCommentId != null;

  CommentDeepLinkState copyWith({
    String? pendingEventId,
    String? pendingCommentId,
    bool? isNavigating,
    String? error,
  }) {
    return CommentDeepLinkState(
      pendingEventId: pendingEventId ?? this.pendingEventId,
      pendingCommentId: pendingCommentId ?? this.pendingCommentId,
      isNavigating: isNavigating ?? this.isNavigating,
      error: error,
    );
  }
}

/// Provider for comment deep link handling
final commentDeepLinkProvider =
    StateNotifierProvider<CommentDeepLinkNotifier, CommentDeepLinkState>(
  (ref) => CommentDeepLinkNotifier(),
);

/// Provider for target comment ID (used by CommentsSheet)
///
/// When a deep link is received, this holds the comment ID to scroll to.
/// CommentsSheet reads this to know which comment to highlight.
final targetCommentIdProvider = StateProvider<String?>((ref) => null);

/// Provider for highlighted comment (for fade animation)
///
/// After scrolling to target comment, this holds the ID for 3 seconds
/// to show a highlight animation, then clears.
final highlightedCommentIdProvider = StateProvider<String?>((ref) => null);
