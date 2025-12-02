// Data Source: NotificationRemoteDataSource
// Feature: Notifications
// Purpose: Remote data source for notifications (stub)

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/notification.dart';

/// Remote data source for notifications
class NotificationRemoteDataSource {
  final SupabaseClient _supabase;

  NotificationRemoteDataSource(this._supabase);

  /// Fetch notifications for user
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    // TODO: Implement actual notification fetching
    return [];
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    // TODO: Implement
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    // TODO: Implement
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    // TODO: Implement
    return 0;
  }
}
