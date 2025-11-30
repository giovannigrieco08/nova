import '../entities/comment.dart';

/// SendReplyNotification Use Case
///
/// Sends a notification to the parent comment author when a reply is posted.
/// This is handled server-side via database trigger. This use case documents
/// the expected behavior and can be extended for offline-first scenarios.
///
/// **T124**: Create reply notification format
/// **T125**: Trigger notification when reply posted
///
/// Notification format:
/// - Title: "[ReplyAuthorName] ha risposto al tuo commento"
/// - Description: First 100 chars of reply text
/// - Deep link: nova://events/{eventId}/comments/{commentId}
/// - Channel: comment_reply
///
/// Server-side trigger logic:
/// 1. Check if comment has parent (parent_comment_id IS NOT NULL)
/// 2. Check if replier != parent comment author (don't notify self)
/// 3. Check if parent author has notifications enabled (profiles.comment_notifications)
/// 4. Check if parent author is not currently viewing comments (optional - client handles)
/// 5. Create notification with type 'comment_reply'
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
  /// 2. Check if replier != parent author
  /// 3. Check notification preferences
  /// 4. Create notification with type 'comment_reply'
  Future<void> call({
    required Comment reply,
    required Comment parentComment,
  }) async {
    // Server-side notification creation is preferred (via database trigger)
    // This use case documents the expected behavior

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

    // Skip notification if replier is the parent comment author
    if (reply.userId == parentComment.userId) {
      return;
    }

    // For now, this is a no-op as server handles it
    // In the future, we can add client-side queuing for offline scenarios
    return;
  }
}

/// Deep link format for reply notifications
///
/// Format: nova://events/{eventId}/comments/{commentId}
///
/// The deep link handler will:
/// 1. Navigate to EventDetailScreen for the event
/// 2. Open CommentsSheet
/// 3. Scroll to and highlight the specific reply
String buildReplyDeepLink({
  required String eventId,
  required String commentId,
}) {
  return 'nova://events/$eventId/comments/$commentId';
}
