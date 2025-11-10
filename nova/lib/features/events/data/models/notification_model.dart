// Data Model: NotificationModel
// Feature: 004-event-creation-moderation
// Purpose: Data layer model for FCM push notifications with JSON serialization

import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/app_notification.dart';
import '../../domain/entities/notification_channel.dart';

part 'notification_model.g.dart';

/// Notification data model for Supabase notifications table
///
/// Maps to the notifications table created in migration 005.
/// Supports 5 notification channels for different event lifecycle events.
@JsonSerializable()
class NotificationModel {
  @JsonKey(name: 'id')
  final String id;

  @JsonKey(name: 'user_id')
  final String userId;

  @JsonKey(name: 'channel')
  final String channel; // Stored as string in DB

  @JsonKey(name: 'title')
  final String title;

  @JsonKey(name: 'body')
  final String body;

  @JsonKey(name: 'event_id')
  final String? eventId;

  @JsonKey(name: 'sent_at')
  final DateTime sentAt;

  @JsonKey(name: 'read')
  final bool read;

  @JsonKey(name: 'delivered')
  final bool delivered;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.channel,
    required this.title,
    required this.body,
    this.eventId,
    required this.sentAt,
    required this.read,
    required this.delivered,
  });

  /// JSON deserialization (from Supabase REST API)
  factory NotificationModel.fromJson(Map<String, dynamic> json) =>
      _$NotificationModelFromJson(json);

  /// JSON serialization (to Supabase REST API)
  Map<String, dynamic> toJson() => _$NotificationModelToJson(this);

  /// Convert from domain entity to data model
  factory NotificationModel.fromEntity(AppNotification entity) {
    return NotificationModel(
      id: entity.id,
      userId: entity.userId,
      channel: entity.channel.name, // Convert enum to String
      title: entity.title,
      body: entity.body,
      eventId: entity.eventId,
      sentAt: entity.sentAt,
      read: entity.read,
      delivered: entity.delivered,
    );
  }

  /// Convert data model to domain entity
  AppNotification toEntity() {
    return AppNotification(
      id: id,
      userId: userId,
      channel: NotificationChannel.values.byName(channel), // Convert String to enum
      title: title,
      body: body,
      eventId: eventId,
      sentAt: sentAt,
      read: read,
      delivered: delivered,
    );
  }

  /// CopyWith for partial updates
  NotificationModel copyWith({
    String? id,
    String? userId,
    String? channel,
    String? title,
    String? body,
    String? eventId,
    DateTime? sentAt,
    bool? read,
    bool? delivered,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      channel: channel ?? this.channel,
      title: title ?? this.title,
      body: body ?? this.body,
      eventId: eventId ?? this.eventId,
      sentAt: sentAt ?? this.sentAt,
      read: read ?? this.read,
      delivered: delivered ?? this.delivered,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NotificationModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'NotificationModel(id: $id, channel: $channel, title: $title, read: $read)';
  }
}
