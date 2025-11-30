import '../entities/comment.dart';

/// SendCommentNotification Use Case
///
/// Sends a notification to the event creator when a top-level comment is posted.
/// This is handled server-side via database trigger. This use case documents
/// the expected behavior and can be extended for offline-first scenarios.
///
/// **T123**: Trigger notification when top-level comment posted
///
/// Notification format:
/// - Title: "[CommenterName] ha commentato il tuo evento '[EventTitle]'"
/// - Description: First 100 chars of comment text
/// - Deep link: nova://events/{eventId}/comments/{commentId}
/// - Channel: new_comment
///
/// Server-side trigger logic:
/// 1. Check if comment is top-level (parent_comment_id IS NULL)
/// 2. Check if commenter != event creator (don't notify self)
/// 3. Check if event creator has notifications enabled (profiles.comment_notifications)
/// 4. Check if event creator is not currently viewing comments (optional - client handles)
/// 5. Create notification with type 'new_comment'
///
/// Usage:
/// ```dart
/// final sendCommentNotification = ref.read(sendCommentNotificationProvider);
/// await sendCommentNotification(
///   comment: newComment,
///   eventId: eventId,
///   eventTitle: eventTitle,
///   eventCreatorId: event.createdByUserId,
/// );
/// ```
class SendCommentNotification {
  SendCommentNotification();

  /// Execute use case
  ///
  /// Parameters:
  /// - [comment]: The newly created top-level comment
  /// - [eventId]: Event UUID
  /// - [eventTitle]: Event title for notification message
  /// - [eventCreatorId]: Event creator's user ID (recipient)
  ///
  /// Note: This is typically handled server-side via database trigger.
  /// The trigger on comments INSERT with parent_comment_id = NULL will:
  /// 1. Get event's created_by_user_id
  /// 2. Check if commenter != event creator
  /// 3. Check notification preferences
  /// 4. Create notification with type 'new_comment'
  Future<void> call({
    required Comment comment,
    required String eventId,
    required String eventTitle,
    required String eventCreatorId,
  }) async {
    // Server-side notification creation is preferred (via database trigger)
    // This use case documents the expected behavior

    // The notification will be created by the database trigger:
    // CREATE TRIGGER create_comment_notification
    // AFTER INSERT ON comments
    // FOR EACH ROW
    // WHEN (NEW.parent_comment_id IS NULL)
    // EXECUTE FUNCTION create_new_comment_notification();

    // The function creates:
    // - recipient_id: event's created_by_user_id
    // - sender_id: comment's user_id
    // - type: 'new_comment'
    // - title: "[CommenterName] ha commentato il tuo evento '[EventTitle]'"
    // - description: First 100 chars of comment text
    // - target_type: 'event'
    // - target_id: event_id
    // - metadata: {"comment_id": comment.id, "event_id": eventId}

    // Skip notification if commenter is the event creator
    if (comment.userId == eventCreatorId) {
      return;
    }

    // For now, this is a no-op as server handles it
    // In the future, we can add client-side queuing for offline scenarios
    return;
  }
}

/// Deep link format for comment notifications
///
/// Format: nova://events/{eventId}/comments/{commentId}
///
/// The deep link handler will:
/// 1. Navigate to EventDetailScreen for the event
/// 2. Open CommentsSheet
/// 3. Scroll to and highlight the specific comment
String buildCommentDeepLink({
  required String eventId,
  required String commentId,
}) {
  return 'nova://events/$eventId/comments/$commentId';
}
