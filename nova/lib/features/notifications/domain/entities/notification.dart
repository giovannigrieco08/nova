import 'notification_channel.dart';

/// Notification entity representing an in-app notification
///
/// Immutable domain model for notifications. All fields are final.
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
  final String title;

  /// Notification description (max 500 characters)
  final String description;

  /// Type of target entity ('event' or 'comment')
  final String targetType;

  /// ID of the target entity (UUID)
  final String targetId;

  /// Additional metadata (JSON object)
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

  /// Create a copy with modified fields (for optimistic UI updates)
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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Notification && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
