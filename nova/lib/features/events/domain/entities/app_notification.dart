// =====================================================================
// AppNotification Entity (Freezed) - Event Creation and Moderation Feature
// =====================================================================
// Purpose: Immutable notification entity for push notifications
// Architecture: Freezed for immutability, JSON serialization support
// =====================================================================

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nova/features/events/domain/entities/notification_channel.dart';

part 'app_notification.freezed.dart';
part 'app_notification.g.dart';

/// Push notification entity
///
/// Represents a notification sent to a user about event-related actions
/// (approval, rejection, co-organizer addition, modifications, etc.)
@freezed
class AppNotification with _$AppNotification {
  const factory AppNotification({
    /// Unique notification ID (UUID from Supabase)
    required String id,

    /// Recipient user ID (UUID)
    required String userId,

    /// Notification channel/type
    required NotificationChannel channel,

    /// Notification title (shown in system notification)
    required String title,

    /// Notification body text (detailed message)
    required String body,

    /// Related event ID (UUID, optional for non-event notifications)
    String? eventId,

    /// When notification was sent
    required DateTime sentAt,

    /// Whether user has marked notification as read (default: false)
    @Default(false) bool read,

    /// Whether FCM successfully delivered notification (default: false)
    @Default(false) bool delivered,
  }) = _AppNotification;

  /// JSON deserialization factory
  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      _$AppNotificationFromJson(json);
}
