import 'notification_channel.dart';

/// Notification entity representing an in-app notification
///
/// Immutable domain model for notifications. All fields are final.
/// Follows clean architecture principles (domain layer is framework-agnostic).
class Notification {
  /// Unique notification ID (UUID from database)
  final String id;

  /// ID of the user who will receive this notification
  final String recipientId;

  /// ID of the user who triggered this notification (nullable: system notifications)
  final String? senderId;

  /// Notification channel type
  final NotificationChannel type;

  /// Notification title (max 200 characters)
  ///
  /// Examples:
  /// - "Marco ha commentato sul tuo evento"
  /// - "Il tuo evento è stato approvato"
  final String title;

  /// Notification description (max 500 characters)
  ///
  /// For comments: first 100 characters of comment content
  /// For moderation: rejection reason or empty string for approval
  final String description;

  /// Type of target entity ('event' or 'comment')
  final String targetType;

  /// ID of the target entity (UUID)
  ///
  /// - For event notifications: event ID
  /// - For comment reply notifications: comment ID
  final String targetId;

  /// Additional metadata (JSON object)
  ///
  /// Examples:
  /// - Comment notification: {"comment_id": "uuid"}
  /// - Rejection notification: {"rejection_reason": "inappropriate content"}
  final Map<String, dynamic> metadata;

  /// Whether the notification has been marked as read
  final bool isRead;

  /// Timestamp when notification was created
  final DateTime createdAt;

  const Notification({
    required this.id,
    required this.recipientId,
    this.senderId,
    required this.type,
    required this.title,
    required this.description,
    required this.targetType,
    required this.targetId,
    required this.metadata,
    required this.isRead,
    required this.createdAt,
  });

  /// Create a copy with modified fields
  ///
  /// Used for optimistic UI updates (e.g., mark as read immediately)
  Notification copyWith({
    String? id,
    String? recipientId,
    String? senderId,
    NotificationChannel? type,
    String? title,
    String? description,
    String? targetType,
    String? targetId,
    Map<String, dynamic>? metadata,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return Notification(
      id: id ?? this.id,
      recipientId: recipientId ?? this.recipientId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      metadata: metadata ?? this.metadata,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Check if notification is unread
  bool get isUnread => !isRead;

  /// Calculate relative time ago (for display with timeago package)
  ///
  /// Returns Duration since notification was created
  Duration get timeSinceCreation => DateTime.now().difference(createdAt);

  /// Check if notification is a comment-related notification
  bool get isCommentNotification =>
      type == NotificationChannel.newComment ||
      type == NotificationChannel.commentReply;

  /// Check if notification is an event-related notification
  bool get isEventNotification =>
      type == NotificationChannel.eventModeration ||
      type == NotificationChannel.eventLike ||
      type == NotificationChannel.eventParticipation ||
      type == NotificationChannel.coorganizerUpdate;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Notification &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Notification{id: $id, type: ${type.value}, title: $title, isRead: $isRead, createdAt: $createdAt}';
  }
}
