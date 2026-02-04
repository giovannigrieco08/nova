import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/comment.dart';
import '../../domain/exceptions/comments_exceptions.dart';
import '../../domain/repositories/comments_repository_interface.dart';
import 'comments_notifier.dart';

/// Provider for comment likes state management
final commentLikesNotifierProvider = StateNotifierProvider.family<
    CommentLikesNotifier, CommentLikesState, String>((ref, commentId) {
  return CommentLikesNotifier(
    ref.read(commentsRepositoryProvider),
    ref,
    commentId,
  );
});

/// Comment likes state
///
/// Tracks optimistic like state for a single comment.
/// Used for instant UI feedback before server confirmation.
class CommentLikesState {
  final bool isLiked;
  final int likeCount;
  final bool isProcessing; // Currently toggling like
  final String? error; // Error message if like/unlike failed

  const CommentLikesState({
    this.isLiked = false,
    this.likeCount = 0,
    this.isProcessing = false,
    this.error,
  });

  CommentLikesState copyWith({
    bool? isLiked,
    int? likeCount,
    bool? isProcessing,
    String? error,
  }) {
    return CommentLikesState(
      isLiked: isLiked ?? this.isLiked,
      likeCount: likeCount ?? this.likeCount,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
    );
  }
}

/// Comment likes notifier
///
/// Manages like/unlike state for a single comment with optimistic UI:
/// 1. Instant toggle (isLiked, likeCount update immediately)
/// 2. Server sync (repository.likeComment or unlikeComment)
/// 3. Rollback on error (restore previous state, show error toast)
///
/// Features:
/// - Optimistic UI (<200ms perceived response time)
/// - Idempotent like/unlike (prevents duplicate actions)
/// - Rate limit handling with countdown timer
/// - Network error handling with rollback
class CommentLikesNotifier extends StateNotifier<CommentLikesState> {
  final CommentsRepositoryInterface _repository;
  final Ref _ref;
  final String _commentId;

  CommentLikesNotifier(this._repository, this._ref, this._commentId)
      : super(const CommentLikesState());

  /// Initialize state from comment entity
  ///
  /// Called when CommentCard is first rendered to sync UI with comment data.
  void initializeFromComment(Comment comment) {
    state = CommentLikesState(
      isLiked: comment.isLikedByCurrentUser,
      likeCount: comment.likeCount,
    );
  }

  /// Initialize state from raw values
  ///
  /// Alternative initialization method when Comment entity is not available.
  void initialize({required bool isLiked, required int likeCount}) {
    state = CommentLikesState(
      isLiked: isLiked,
      likeCount: likeCount,
    );
  }

  /// Toggle like/unlike with optimistic UI
  ///
  /// Flow:
  /// 1. Prevent duplicate actions (check isProcessing)
  /// 2. Save previous state for rollback
  /// 3. Instantly update UI (toggle isLiked, increment/decrement likeCount)
  /// 4. Call API (likeComment or unlikeComment)
  /// 5. On success: Update comments list with server data
  /// 6. On error: Rollback to previous state, show error
  Future<void> toggleLike() async {
    developer.log(
        'toggleLike called for comment $_commentId, current state: isLiked=${state.isLiked}, likeCount=${state.likeCount}, isProcessing=${state.isProcessing}');

    // Prevent duplicate actions
    if (state.isProcessing) {
      developer.log('toggleLike: Already processing, returning');
      return;
    }

    // Save previous state for rollback
    final previousState = state;

    // Optimistic update (instant UI feedback)
    final newIsLiked = !state.isLiked;
    final newLikeCount = newIsLiked ? state.likeCount + 1 : state.likeCount - 1;

    developer.log(
        'toggleLike: Optimistic update - newIsLiked=$newIsLiked, newLikeCount=$newLikeCount');

    state = state.copyWith(
      isLiked: newIsLiked,
      likeCount: newLikeCount,
      isProcessing: true,
      error: null,
    );

    try {
      if (newIsLiked) {
        // Like comment
        developer.log('toggleLike: Calling repository.likeComment');
        final updatedComment = await _repository.likeComment(
          commentId: _commentId,
        );
        developer.log(
            'toggleLike: Like successful, server likeCount=${updatedComment.likeCount}');

        // Update comment in comments list
        _updateCommentInList(updatedComment);

        // Update state with server data (sync like count)
        state = CommentLikesState(
          isLiked: true,
          likeCount: updatedComment.likeCount,
          isProcessing: false,
        );
      } else {
        // Unlike comment
        developer.log('toggleLike: Calling repository.unlikeComment');
        final updatedComment = await _repository.unlikeComment(
          commentId: _commentId,
        );
        developer.log(
            'toggleLike: Unlike successful, server likeCount=${updatedComment.likeCount}');

        // Update comment in comments list
        _updateCommentInList(updatedComment);

        // Update state with server data (sync like count)
        state = CommentLikesState(
          isLiked: false,
          likeCount: updatedComment.likeCount,
          isProcessing: false,
        );
      }
    } on RateLimitException catch (e) {
      developer.log('toggleLike: RateLimitException - ${e.message}');
      // Rate limit exceeded - rollback and show error
      state = previousState.copyWith(
        isProcessing: false,
        error:
            'Hai raggiunto il limite di like. Riprova tra ${e.retryAfter.inMinutes} minuti.',
      );
    } on NetworkException catch (e) {
      developer.log('toggleLike: NetworkException - ${e.message}');
      // Network error - rollback and show error
      state = previousState.copyWith(
        isProcessing: false,
        error: 'Nessuna connessione. Riprova più tardi.',
      );
    } on ConflictException catch (e) {
      developer.log('toggleLike: ConflictException - ${e.message}');
      // Already liked/unliked (duplicate action) - sync with server state
      // This shouldn't happen with optimistic UI, but handle gracefully
      state = previousState.copyWith(
        isProcessing: false,
      );
    } catch (e, stackTrace) {
      developer.log('toggleLike: Unknown error - $e',
          error: e, stackTrace: stackTrace);
      // Unknown error - rollback and show generic error
      state = previousState.copyWith(
        isProcessing: false,
        error: 'Errore durante il like. Riprova.',
      );
    }
  }

  /// Update comment in the comments list
  ///
  /// Syncs the comment state in CommentsNotifier after like/unlike.
  void _updateCommentInList(Comment updatedComment) {
    // Find the event ID from the comment
    final eventId = updatedComment.eventId;

    // Update comment in the list
    try {
      _ref
          .read(commentsNotifierProvider(eventId).notifier)
          .updateComment(updatedComment);
    } catch (e) {
      // Comments provider might not be active - ignore
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(error: null);
  }
}
