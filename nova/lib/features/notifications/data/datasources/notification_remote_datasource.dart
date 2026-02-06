// Data Source: NotificationRemoteDataSource
// Feature: Notifications
// Purpose: Remote data source for notifications

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/notification.dart';

/// Remote data source for notifications
class NotificationRemoteDataSource {
  final SupabaseClient _supabase;

  NotificationRemoteDataSource(this._supabase);

  /// Fetch notifications for user
  Future<List<AppNotification>> getNotifications({int limit = 50}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _supabase
        .from('notifications')
        .select('''
          *,
          actor:profiles!sender_id(
            full_name,
            avatar_url
          )
        ''')
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true}).eq('id', notificationId);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', userId)
        .eq('is_read', false);
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return 0;

    final response = await _supabase
        .from('notifications')
        .select()
        .eq('recipient_id', userId)
        .eq('is_read', false)
        .count(CountOption.exact);

    return response.count;
  }

  /// Delete a notification
  Future<void> deleteNotification(String notificationId) async {
    await _supabase.from('notifications').delete().eq('id', notificationId);
  }
}
