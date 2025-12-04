// Domain Entity: Notification
// Feature: Notifications
// Purpose: Notification entity for display in notification list

import 'notification_channel.dart';

/// Notification entity
class AppNotification {
  final String id;
  final String userId;
  final NotificationChannel channel;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.channel,
    required this.title,
    required this.body,
    this.data,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    // Map database type to NotificationChannel
    final dbType = json['type'] as String? ?? 'event_moderation';
    final channelMap = {
      'event_moderation': NotificationChannel.eventModeration,
      'event_approved': NotificationChannel.eventModeration,
      'event_rejected': NotificationChannel.eventModeration,
      'new_pending_event': NotificationChannel.moderatorAlert,
      'added_as_coorganizer': NotificationChannel.coorganizerUpdate,
      'event_modified': NotificationChannel.coorganizerUpdate,
      'new_comment': NotificationChannel.newComment,
      'comment_reply': NotificationChannel.commentReply,
      'event_like': NotificationChannel.eventLike,
      'event_participation': NotificationChannel.eventParticipation,
      'coorganizer_update': NotificationChannel.coorganizerUpdate,
      'chat_mention': NotificationChannel.chatMention,
    };

    // Build data map from target info and metadata
    Map<String, dynamic>? dataMap;
    if (json['target_type'] != null || json['metadata'] != null) {
      dataMap = {
        if (json['target_type'] != null) 'target_type': json['target_type'],
        if (json['target_id'] != null) 'target_id': json['target_id'],
        ...(json['metadata'] as Map<String, dynamic>? ?? {}),
      };
    }

    return AppNotification(
      id: json['id'] as String,
      userId: json['recipient_id'] as String,
      channel: channelMap[dbType] ?? NotificationChannel.eventModeration,
      title: json['title'] as String? ?? '',
      body: json['description'] as String? ?? '',
      data: dataMap,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    NotificationChannel? channel,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      channel: channel ?? this.channel,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Notification state for provider
class NotificationState {
  final List<AppNotification> notifications;
  final bool isLoading;
  final String? error;

  const NotificationState({
    this.notifications = const [],
    this.isLoading = false,
    this.error,
  });

  NotificationState copyWith({
    List<AppNotification>? notifications,
    bool? isLoading,
    String? error,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
