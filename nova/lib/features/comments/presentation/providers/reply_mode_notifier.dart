import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/comment.dart';

/// Provider for reply mode state (per event)
///
/// Tracks whether user is replying to a comment:
/// - null: Normal comment mode (posting top-level comment)
/// - Comment: Replying to this specific comment
final replyModeNotifierProvider =
    StateNotifierProvider.family<ReplyModeNotifier, ReplyModeState, String>(
        (ref, eventId) {
  return ReplyModeNotifier();
});

/// Reply mode state
///
/// Represents the current reply mode for commenting:
/// - `targetComment == null`: Normal mode (posting top-level comment)
/// - `targetComment != null`: Replying to target comment
class ReplyModeState {
  final Comment? targetComment; // Comment being replied to (null = normal mode)

  const ReplyModeState({this.targetComment});

  /// Normal mode (posting top-level comment)
  bool get isNormalMode => targetComment == null;

  /// Reply mode (replying to a comment)
  bool get isReplyMode => targetComment != null;

  /// Get reply header text for UI
  ///
  /// Returns: "Rispondi a [Name]" when in reply mode, null otherwise
  String? get replyHeaderText {
    if (targetComment == null) return null;
    final authorName = targetComment!.authorName ?? 'Utente';
    return 'Rispondi a $authorName';
  }

  /// Get mention prefix for input field
  ///
  /// Returns: "@[Username] " when in reply mode, empty string otherwise
  String get mentionPrefix {
    if (targetComment == null) return '';
    final authorName = targetComment!.authorName ?? 'Utente';
    final username = authorName.split(' ').first; // Use first name as username
    return '@$username ';
  }

  ReplyModeState copyWith({Comment? targetComment}) {
    return ReplyModeState(
      targetComment: targetComment,
    );
  }
}

/// Reply mode notifier
///
/// Manages reply mode state for an event's comment section.
/// Allows switching between normal mode and reply mode.
///
/// Features:
/// - Start reply mode: set target comment
/// - Cancel reply mode: clear target comment
/// - Automatic mode management: clears after successful post
///
/// Usage:
/// ```dart
/// // Enter reply mode
/// ref.read(replyModeNotifierProvider(eventId).notifier).startReply(comment);
///
/// // Exit reply mode
/// ref.read(replyModeNotifierProvider(eventId).notifier).cancelReply();
///
/// // Check mode
/// final isReplying = ref.watch(replyModeNotifierProvider(eventId)).isReplyMode;
/// ```
class ReplyModeNotifier extends StateNotifier<ReplyModeState> {
  ReplyModeNotifier() : super(const ReplyModeState());

  /// Start replying to a comment
  ///
  /// Switches to reply mode and sets the target comment.
  /// UI should show reply header and pre-fill input with mention.
  void startReply(Comment comment) {
    state = ReplyModeState(targetComment: comment);
  }

  /// Cancel reply mode
  ///
  /// Returns to normal mode (posting top-level comments).
  void cancelReply() {
    state = const ReplyModeState();
  }

  /// Get target comment ID (null if in normal mode)
  ///
  /// Used when posting comment to determine parent_comment_id.
  String? get targetCommentId => state.targetComment?.id;
}
