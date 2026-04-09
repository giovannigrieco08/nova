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

    // Fetch notifications without FK join (FK was removed in migration 063)
    final response = await _supabase
        .from('notifications')
        .select('*')
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    // Collect unique sender IDs to fetch profiles separately
    final senderIds = (response as List)
        .map((n) => n['sender_id'] as String?)
        .where((id) => id != null)
        .toSet()
        .toList();

    // Fetch sender profiles in one query
    Map<String, Map<String, dynamic>> profileMap = {};
    if (senderIds.isNotEmpty) {
      final profiles = await _supabase
          .from('profiles')
          .select('user_id, full_name, avatar_url')
          .inFilter('user_id', senderIds);

      for (final p in profiles as List) {
        profileMap[p['user_id'] as String] = p as Map<String, dynamic>;
      }
    }

    // Merge actor data into notifications
    final enriched = (response as List).map((n) {
      final senderId = n['sender_id'] as String?;
      final profile = senderId != null ? profileMap[senderId] : null;
      return {
        ...n as Map<String, dynamic>,
        'actor': profile,
      };
    }).toList();

    return enriched
        .map((json) => AppNotification.fromJson(json))
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
