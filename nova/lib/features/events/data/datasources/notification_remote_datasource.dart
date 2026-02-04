// Data Source: NotificationRemoteDataSource
// Feature: 004-event-creation-moderation (US2 - Status Tracking)
// Purpose: Supabase REST API client for notification operations
//
// Notifications are created server-side by Supabase Edge Functions triggered
// by database events (event approval, rejection, co-organizer addition, etc.).
// This data source provides read-only access for users.

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

/// Remote data source for notification operations via Supabase REST API
class NotificationRemoteDataSource {
  final SupabaseClient _supabase;

  NotificationRemoteDataSource(this._supabase);

  // =========================================================================
  // READ OPERATIONS
  // =========================================================================

  /// Fetch all notifications for user
  ///
  /// RLS: users_view_own_notifications policy
  /// Query: SELECT * FROM notifications WHERE user_id = {userId} ORDER BY sent_at DESC
  Future<List<NotificationModel>> getMyNotifications(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .order('sent_at', ascending: false);

      return (response as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      throw NotificationDataSourceException(
        'Failed to fetch notifications: $e',
      );
    }
  }

  /// Get unread notifications count
  ///
  /// Query: SELECT COUNT(*) FROM notifications WHERE user_id = {userId} AND read = false
  /// TODO: Optimize with Supabase count() in Phase 8
  Future<int> getUnreadCount(String userId) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('user_id', userId)
          .eq('read', false);

      return (response as List).length;
    } catch (e) {
      throw NotificationDataSourceException(
        'Failed to fetch unread count: $e',
      );
    }
  }

  /// Get notifications by channel
  ///
  /// Example: Get only event_approved notifications
  Future<List<NotificationModel>> getNotificationsByChannel(
    String userId,
    String channel,
  ) async {
    try {
      final response = await _supabase
          .from('notifications')
          .select()
          .eq('user_id', userId)
          .eq('channel', channel)
          .order('sent_at', ascending: false);

      return (response as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      throw NotificationDataSourceException(
        'Failed to fetch notifications by channel: $e',
      );
    }
  }

  // =========================================================================
  // WRITE OPERATIONS
  // =========================================================================

  /// Mark notification as read
  ///
  /// RLS: users_update_own_notifications policy
  Future<void> markAsRead(String notificationId) async {
    try {
      await _supabase.from('notifications').update({
        'read': true,
      }).eq('id', notificationId);
    } catch (e) {
      throw NotificationDataSourceException('Failed to mark as read: $e');
    }
  }

  /// Mark all notifications as read
  ///
  /// Batch update for current user
  Future<void> markAllAsRead(String userId) async {
    try {
      await _supabase
          .from('notifications')
          .update({
            'read': true,
          })
          .eq('user_id', userId)
          .eq('read', false); // Only update unread ones
    } catch (e) {
      throw NotificationDataSourceException('Failed to mark all as read: $e');
    }
  }

  /// Delete notification (future enhancement - requires migration)
  ///
  /// Note: Not implemented in migration 005. Would require:
  /// - Add deleted_at TIMESTAMPTZ column
  /// - Update RLS policies to filter WHERE deleted_at IS NULL
  Future<void> deleteNotification(String notificationId) async {
    throw NotificationDataSourceException(
      'Delete not implemented - requires database migration',
    );
  }

  // =========================================================================
  // REALTIME SUBSCRIPTION
  // =========================================================================

  /// Subscribe to new notifications in real-time
  ///
  /// Uses Supabase Realtime to listen for INSERT events on notifications table.
  /// Returns Stream that emits whenever a new notification is inserted.
  ///
  /// Example usage:
  /// ```dart
  /// dataSource.subscribeToNotifications(userId).listen((notification) {
  ///   // Show in-app notification banner
  ///   showNotificationBanner(notification.title, notification.body);
  /// });
  /// ```
  Stream<NotificationModel> subscribeToNotifications(String userId) {
    try {
      return _supabase
          .from('notifications')
          .stream(primaryKey: ['id'])
          .eq('user_id', userId)
          .order('sent_at', ascending: false)
          .map((data) {
            // Stream emits List<Map>, but we only care about new inserts
            if (data.isEmpty) return null;
            return NotificationModel.fromJson(data.first);
          })
          .where((notification) => notification != null)
          .cast<NotificationModel>();
    } catch (e) {
      throw NotificationDataSourceException(
        'Failed to subscribe to notifications: $e',
      );
    }
  }
}

/// Exception thrown when notification data source operation fails
class NotificationDataSourceException implements Exception {
  final String message;

  NotificationDataSourceException(this.message);

  @override
  String toString() => 'NotificationDataSourceException: $message';
}
