import '../../domain/entities/notification.dart';
import '../../domain/entities/notification_channel.dart';

/// Data model for Notification with Supabase JSON serialization
class NotificationModel extends Notification {
  const NotificationModel({
    required super.id,
    required super.recipientId,
    super.senderId,
    required super.type,
    required super.title,
    required super.description,
    required super.targetType,
    required super.targetId,
    required super.metadata,
    required super.isRead,
    required super.createdAt,
  });

  /// Create from Supabase JSON response
  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      recipientId: json['recipient_id'] as String,
      senderId: json['sender_id'] as String?,
      type: NotificationChannel.fromString(json['type'] as String),
      title: json['title'] as String,
      description: json['description'] as String,
      targetType: json['target_type'] as String,
      targetId: json['target_id'] as String,
      metadata: (json['metadata'] as Map<String, dynamic>?) ?? {},
      isRead: json['is_read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert to JSON for Supabase (used for updates)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'recipient_id': recipientId,
      'sender_id': senderId,
      'type': type.value,
      'title': title,
      'description': description,
      'target_type': targetType,
      'target_id': targetId,
      'metadata': metadata,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create from domain entity
  factory NotificationModel.fromEntity(Notification entity) {
    return NotificationModel(
      id: entity.id,
      recipientId: entity.recipientId,
      senderId: entity.senderId,
      type: entity.type,
      title: entity.title,
      description: entity.description,
      targetType: entity.targetType,
      targetId: entity.targetId,
      metadata: entity.metadata,
      isRead: entity.isRead,
      createdAt: entity.createdAt,
    );
  }

  /// Convert to domain entity
  Notification toEntity() {
    return Notification(
      id: id,
      recipientId: recipientId,
      senderId: senderId,
      type: type,
      title: title,
      description: description,
      targetType: targetType,
      targetId: targetId,
      metadata: metadata,
      isRead: isRead,
      createdAt: createdAt,
    );
  }

  @override
  NotificationModel copyWith({
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
    return NotificationModel(
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
}
