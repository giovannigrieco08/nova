// =====================================================================
// Push Payload Entity - Push Notifications Feature (009)
// =====================================================================
// Purpose: Push notification payload structure for sending/receiving
// Used by: Edge Function (sending) and Flutter app (receiving)
// =====================================================================

/// Push notification payload structure
///
/// Used for both sending (Edge Function) and receiving (Flutter app).
/// Contains all data needed for display and navigation.
class PushPayload {
  /// Notification title (displayed in system tray)
  final String title;

  /// Notification body text
  final String body;

  /// Navigation target type: 'event' or 'comment'
  final String targetType;

  /// Navigation target ID (event_id or comment_id)
  final String targetId;

  /// Reference to in-app notification (for marking as read)
  final String notificationId;

  /// Current unread count (for badge update)
  final int badgeCount;

  /// Event ID for comment targets (needed for navigation)
  final String? eventId;

  /// Optional metadata
  final Map<String, dynamic>? metadata;

  const PushPayload({
    required this.title,
    required this.body,
    required this.targetType,
    required this.targetId,
    required this.notificationId,
    required this.badgeCount,
    this.eventId,
    this.metadata,
  });

  /// Parse from FCM RemoteMessage data
  factory PushPayload.fromFcmData(Map<String, dynamic> data) => PushPayload(
        title: data['title'] as String? ?? 'Nova',
        body: data['body'] as String? ?? '',
        targetType: data['target_type'] as String? ?? 'event',
        targetId: data['target_id'] as String? ?? '',
        notificationId: data['notification_id'] as String? ?? '',
        badgeCount: int.tryParse(data['badge_count']?.toString() ?? '0') ?? 0,
        eventId: data['event_id'] as String?,
        metadata: data['metadata'] != null
            ? Map<String, dynamic>.from(data['metadata'] as Map)
            : null,
      );

  /// Convert to FCM data payload (all values must be strings for FCM)
  Map<String, String> toFcmData() => {
        'title': title,
        'body': body,
        'target_type': targetType,
        'target_id': targetId,
        'notification_id': notificationId,
        'badge_count': badgeCount.toString(),
        if (eventId != null) 'event_id': eventId!,
        if (metadata != null) 'metadata': metadata.toString(),
      };

  /// Check if this is an event notification
  bool get isEventTarget => targetType == 'event';

  /// Check if this is a comment notification
  bool get isCommentTarget => targetType == 'comment';

  /// Get the event ID for navigation (works for both event and comment targets)
  String? get navigationEventId => isEventTarget ? targetId : eventId;

  @override
  String toString() =>
      'PushPayload(title: $title, targetType: $targetType, targetId: $targetId)';
}
