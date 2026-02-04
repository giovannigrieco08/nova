import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/comment.dart';
import '../../domain/exceptions/comments_exceptions.dart';
import '../../domain/repositories/comments_repository_interface.dart';
import 'comments_notifier.dart';

/// Provider for comment input state
final commentInputNotifierProvider = StateNotifierProvider.family<
    CommentInputNotifier, CommentInputState, String>((ref, eventId) {
  return CommentInputNotifier(
    ref.read(commentsRepositoryProvider),
    ref,
    eventId,
  );
});

/// Comment input state
class CommentInputState {
  final String text;
  final bool isPosting;
  final String? error;
  final bool hasReachedLimit;

  const CommentInputState({
    this.text = '',
    this.isPosting = false,
    this.error,
    this.hasReachedLimit = false,
  });

  CommentInputState copyWith({
    String? text,
    bool? isPosting,
    String? error,
    bool? hasReachedLimit,
  }) {
    return CommentInputState(
      text: text ?? this.text,
      isPosting: isPosting ?? this.isPosting,
      error: error,
      hasReachedLimit: hasReachedLimit ?? this.hasReachedLimit,
    );
  }

  /// Check if send button should be enabled
  bool get canSend => text.trim().isNotEmpty && !isPosting && !hasReachedLimit;

  /// Get character count (for display)
  int get characterCount => text.length;

  /// Check if approaching character limit (show warning at 450+ chars)
  bool get isApproachingLimit => characterCount >= 450;
}

/// Comment input notifier
///
/// Manages state for the comment input field:
/// - Text input with character counting
/// - Validation (1-500 chars after trim)
/// - Posting state with optimistic UI
/// - Error handling (profanity, rate limit, network)
class CommentInputNotifier extends StateNotifier<CommentInputState> {
  final CommentsRepositoryInterface _repository;
  final Ref _ref;
  final String _eventId;
  final TextEditingController textController = TextEditingController();
  final Uuid _uuid = const Uuid();

  CommentInputNotifier(this._repository, this._ref, this._eventId)
      : super(const CommentInputState()) {
    // Listen to text controller changes
    textController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  /// Handle text changes
  void _onTextChanged() {
    final text = textController.text;
    state = state.copyWith(
      text: text,
      hasReachedLimit: text.length > 500,
      error: null, // Clear error on text change
    );
  }

  /// Post comment with optimistic UI
  ///
  /// Flow:
  /// 1. Validate text (1-500 chars after trim)
  /// 2. Create optimistic comment with temp ID
  /// 3. Add to comments list immediately
  /// 4. Call API to post comment
  /// 5. Replace optimistic comment with server response
  /// 6. On error: Remove optimistic comment and show error
  Future<void> postComment() async {
    final text = state.text.trim();

    // Validate
    if (text.isEmpty) {
      state = state.copyWith(error: 'Il commento non può essere vuoto');
      return;
    }

    if (text.length > 500) {
      state =
          state.copyWith(error: 'Il commento non può superare i 500 caratteri');
      return;
    }

    // Set posting state
    state = state.copyWith(isPosting: true, error: null);

    // Generate temp ID for optimistic comment
    final tempId = 'temp_${_uuid.v4()}';

    // Create optimistic comment
    final optimisticComment = Comment(
      id: tempId,
      eventId: _eventId,
      userId: 'current_user', // Will be replaced by server response
      text: text,
      createdAt: DateTime.now(),
      likeCount: 0,
      replyCount: 0,
      reportCount: 0,
      isLikedByCurrentUser: false,
      authorName: 'You', // Placeholder
    );

    // Add optimistic comment to list
    _ref
        .read(commentsNotifierProvider(_eventId).notifier)
        .addOptimisticComment(optimisticComment);

    try {
      // Post to server
      final serverComment = await _repository.postComment(
        eventId: _eventId,
        text: text,
      );

      // Replace optimistic comment with server response
      _ref
          .read(commentsNotifierProvider(_eventId).notifier)
          .removeOptimisticComment(tempId);
      _ref
          .read(commentsNotifierProvider(_eventId).notifier)
          .addOptimisticComment(serverComment);

      // Clear input
      textController.clear();
      state = const CommentInputState();
    } on ValidationException catch (e) {
      // Profanity or validation error
      _ref
          .read(commentsNotifierProvider(_eventId).notifier)
          .removeOptimisticComment(tempId);

      state = state.copyWith(
        isPosting: false,
        error: e.message.contains('inappropriate')
            ? 'Il commento contiene linguaggio inappropriato'
            : e.message,
      );
    } on RateLimitException catch (e) {
      // Rate limit exceeded
      _ref
          .read(commentsNotifierProvider(_eventId).notifier)
          .removeOptimisticComment(tempId);

      final minutes = e.retryAfter.inMinutes;
      state = state.copyWith(
        isPosting: false,
        error: 'Hai raggiunto il limite. Riprova tra $minutes minuti',
      );
    } on NetworkException catch (_) {
      // Network error - keep optimistic comment, queue for sync
      state = state.copyWith(
        isPosting: false,
        error:
            'Nessuna connessione. Il commento sarà inviato quando torni online.',
      );

      // Clear input anyway
      textController.clear();
      state = const CommentInputState();
    } catch (e) {
      // Unknown error
      _ref
          .read(commentsNotifierProvider(_eventId).notifier)
          .removeOptimisticComment(tempId);

      state = state.copyWith(
        isPosting: false,
        error: 'Errore durante l\'invio del commento. Riprova.',
      );
    }
  }

  /// Post reply to an existing comment
  ///
  /// Similar to postComment but includes parent_comment_id.
  /// Called when user is in reply mode.
  Future<void> postReply(String parentCommentId) async {
    final text = state.text.trim();

    // Validate
    if (text.isEmpty) {
      state = state.copyWith(error: 'La risposta non può essere vuota');
      return;
    }

    if (text.length > 500) {
      state =
          state.copyWith(error: 'La risposta non può superare i 500 caratteri');
      return;
    }

    // Set posting state
    state = state.copyWith(isPosting: true, error: null);

    // Generate temp ID for optimistic reply
    final tempId = 'temp_${_uuid.v4()}';

    // Create optimistic reply
    final optimisticReply = Comment(
      id: tempId,
      eventId: _eventId,
      userId: 'current_user',
      parentCommentId: parentCommentId,
      text: text,
      createdAt: DateTime.now(),
      likeCount: 0,
      replyCount: 0,
      reportCount: 0,
      isLikedByCurrentUser: false,
      authorName: 'You',
    );

    // Add optimistic reply to list
    _ref
        .read(commentsNotifierProvider(_eventId).notifier)
        .addOptimisticComment(optimisticReply);

    try {
      // Post reply to server
      await _repository.replyToComment(
        commentId: parentCommentId,
        text: text,
      );

      // Replace optimistic reply with server response
      _ref
          .read(commentsNotifierProvider(_eventId).notifier)
          .removeOptimisticComment(tempId);

      // Refresh comments to get the reply in proper threaded position
      await _ref.read(commentsNotifierProvider(_eventId).notifier).refresh();

      // Clear input
      textController.clear();
      state = const CommentInputState();
    } on ValidationException catch (e) {
      _ref
          .read(commentsNotifierProvider(_eventId).notifier)
          .removeOptimisticComment(tempId);

      state = state.copyWith(
        isPosting: false,
        error: e.message.contains('inappropriate')
            ? 'La risposta contiene linguaggio inappropriato'
            : e.message,
      );
    } on RateLimitException catch (e) {
      _ref
          .read(commentsNotifierProvider(_eventId).notifier)
          .removeOptimisticComment(tempId);

      final minutes = e.retryAfter.inMinutes;
      state = state.copyWith(
        isPosting: false,
        error: 'Hai raggiunto il limite. Riprova tra $minutes minuti',
      );
    } on NetworkException catch (_) {
      state = state.copyWith(
        isPosting: false,
        error:
            'Nessuna connessione. La risposta sarà inviata quando torni online.',
      );

      textController.clear();
      state = const CommentInputState();
    } catch (e) {
      _ref
          .read(commentsNotifierProvider(_eventId).notifier)
          .removeOptimisticComment(tempId);

      state = state.copyWith(
        isPosting: false,
        error: 'Errore durante l\'invio della risposta. Riprova.',
      );
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}
