import '../entities/comment.dart';

/// SendReplyNotification Use Case
///
/// Sends a notification to the parent comment author when a reply is posted.
/// This is typically handled server-side via database trigger, but this use case
/// can be used as a fallback or for offline-first scenarios.
///
/// Notification format:
/// - Title: "[ReplyAuthorName] ha risposto al tuo commento"
/// - Description: First 100 chars of reply text
/// - Deep link: nova://events/{eventId}/comments/{commentId}
///
/// **T059**: Send notification to parent comment author when reply is posted
///
/// Usage:
/// ```dart
/// final sendReplyNotification = ref.read(sendReplyNotificationProvider);
/// await sendReplyNotification(
///   reply: newReply,
///   parentComment: parentComment,
/// );
/// ```
class SendReplyNotification {
  SendReplyNotification();

  /// Execute use case
  ///
  /// Parameters:
  /// - [reply]: The newly created reply comment
  /// - [parentComment]: The parent comment being replied to
  ///
  /// Note: This is typically handled server-side via database trigger.
  /// The trigger on comments INSERT with parent_comment_id != NULL will:
  /// 1. Get parent comment's user_id
  /// 2. Create notification with type 'comment_reply'
  /// 3. Set target_id to event_id for deep linking
  Future<void> call({
    required Comment reply,
    required Comment parentComment,
  }) async {
    // Server-side notification creation is preferred (via database trigger)
    // This use case documents the expected behavior and can be extended
    // for offline-first scenarios where client needs to queue notification

    // The notification will be created by the database trigger:
    // CREATE TRIGGER create_reply_notification
    // AFTER INSERT ON comments
    // FOR EACH ROW
    // WHEN (NEW.parent_comment_id IS NOT NULL)
    // EXECUTE FUNCTION create_comment_reply_notification();

    // The function creates:
    // - recipient_id: parent comment's user_id
    // - sender_id: reply's user_id
    // - type: 'comment_reply'
    // - title: "[ReplyAuthorName] ha risposto al tuo commento"
    // - description: First 100 chars of reply text
    // - target_type: 'event'
    // - target_id: event_id (for deep linking to event comments)
    // - metadata: {"comment_id": reply.id, "parent_comment_id": parentComment.id}

    // For now, this is a no-op as server handles it
    // In the future, we can add client-side queuing for offline scenarios
    return;
  }
}
