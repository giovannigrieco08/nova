import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification_model.dart';
import '../models/notification_preferences_model.dart';

/// Remote data source for notifications using Supabase
///
/// Handles all Supabase API calls for notifications and preferences.
/// Uses Supabase Realtime for live notification updates.
class NotificationRemoteDataSource {
  final SupabaseClient _supabase;

  NotificationRemoteDataSource(this._supabase);

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  // =========================================================================
  // NOTIFICATIONS CRUD
  // =========================================================================

  /// Fetch all notifications for current user (paginated, newest first)
  ///
  /// [limit] - Number of notifications to fetch (default 50)
  /// [offset] - Pagination offset
  Future<List<NotificationModel>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('notifications')
        .select()
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => NotificationModel.fromJson(json))
        .toList();
  }

  /// Get unread notification count for badge display
  Future<int> getUnreadCount() async {
    final userId = _currentUserId;
    if (userId == null) return 0;

    final response = await _supabase
        .from('notifications')
        .select('id')
        .eq('recipient_id', userId)
        .eq('is_read', false);

    return (response as List).length;
  }

  /// Mark a single notification as read
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    final userId = _currentUserId;
    if (userId == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', userId)
        .eq('is_read', false);
  }

  /// Delete a single notification
  Future<void> deleteNotification(String notificationId) async {
    await _supabase.from('notifications').delete().eq('id', notificationId);
  }

  /// Delete all notifications for current user
  Future<void> deleteAllNotifications() async {
    final userId = _currentUserId;
    if (userId == null) return;

    await _supabase.from('notifications').delete().eq('recipient_id', userId);
  }

  // =========================================================================
  // REALTIME SUBSCRIPTION
  // =========================================================================

  /// Subscribe to real-time notification updates
  ///
  /// Returns a Stream that emits new notifications as they arrive.
  /// Uses Supabase Realtime (Postgres CDC) for <1s latency.
  Stream<NotificationModel> subscribeToNotifications() {
    final userId = _currentUserId;
    if (userId == null) {
      return const Stream.empty();
    }

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .map((data) {
          if (data.isEmpty) return null;
          return NotificationModel.fromJson(data.first);
        })
        .where((notification) => notification != null)
        .cast<NotificationModel>();
  }

  /// Subscribe to unread count changes for badge updates
  Stream<int> subscribeToUnreadCount() {
    final userId = _currentUserId;
    if (userId == null) {
      return Stream.value(0);
    }

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', userId)
        .map((data) => data.where((n) => n['is_read'] == false).length);
  }

  // =========================================================================
  // NOTIFICATION PREFERENCES
  // =========================================================================

  /// Get notification preferences for current user
  Future<NotificationPreferencesModel> getPreferences() async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('profiles')
        .select('''
          eventi_moderati_enabled,
          nuovi_commenti_enabled,
          risposte_commenti_enabled,
          like_eventi_enabled,
          nuove_partecipazioni_enabled,
          coorganizer_updates_enabled
        ''')
        .eq('user_id', userId)
        .single();

    return NotificationPreferencesModel.fromJson(response);
  }

  /// Update notification preferences
  Future<void> updatePreferences(NotificationPreferencesModel preferences) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('profiles')
        .update(preferences.toJson())
        .eq('user_id', userId);
  }

  /// Toggle a single preference
  Future<void> togglePreference(String columnName, bool value) async {
    final userId = _currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    await _supabase
        .from('profiles')
        .update({columnName: value})
        .eq('user_id', userId);
  }
}
