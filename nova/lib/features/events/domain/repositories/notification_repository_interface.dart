// Domain Repository Interface: NotificationRepository
// Feature: 004-event-creation-moderation (US2 - Status Tracking)
// Purpose: Abstract contract for notification data operations
//
// This interface defines all notification-related operations for FCM push notifications.
// Notifications are created by Supabase Edge Functions and stored in notifications table.

import '../../domain/entities/app_notification.dart';

/// Abstract repository for notification operations
///
/// Implementations must provide:
/// - Supabase remote data source (for notification queries)
/// - Read-only access (notifications created server-side via Edge Functions)
abstract class NotificationRepository {
  // =========================================================================
  // READ OPERATIONS
  // =========================================================================

  /// Get all notifications for current user
  ///
  /// Query: `user_id=eq.{userId}&order=sent_at.desc`
  /// RLS Policy: users_view_own_notifications
  /// Returns notifications sorted by sent_at DESC (newest first)
  Future<List<AppNotification>> getMyNotifications(String userId);

  /// Get unread notifications count for current user
  ///
  /// Query: `user_id=eq.{userId}&read=eq.false&select=count`
  /// Used for badge display in bottom navigation bar
  Future<int> getUnreadCount(String userId);

  /// Get notifications by channel (e.g., only event_approved notifications)
  ///
  /// Query: `user_id=eq.{userId}&channel=eq.{channel}&order=sent_at.desc`
  Future<List<AppNotification>> getNotificationsByChannel(
    String userId,
    String channel,
  );

  // =========================================================================
  // WRITE OPERATIONS (User Actions)
  // =========================================================================

  /// Mark notification as read
  ///
  /// Updates: read = true
  /// RLS Policy: users_update_own_notifications
  Future<void> markAsRead(String notificationId);

  /// Mark all notifications as read for current user
  ///
  /// Batch update: read = true for all user's notifications
  Future<void> markAllAsRead(String userId);

  /// Delete notification (soft delete - only hides from user)
  ///
  /// Note: Actual deletion not implemented in migration 005.
  /// Future enhancement: add deleted_at column for soft deletes.
  Future<void> deleteNotification(String notificationId);

  // =========================================================================
  // REALTIME SUBSCRIPTION
  // =========================================================================

  /// Subscribe to new notifications in real-time
  ///
  /// Uses Supabase Realtime to listen for INSERT events on notifications table
  /// where user_id = current user.
  ///
  /// Returns Stream<AppNotification> that emits whenever a new notification
  /// is inserted server-side.
  ///
  /// Example usage:
  /// ```dart
  /// repository.subscribeToNotifications(userId).listen((notification) {
  ///   // Show in-app notification banner
  ///   showNotificationBanner(notification);
  /// });
  /// ```
  Stream<AppNotification> subscribeToNotifications(String userId);
}
