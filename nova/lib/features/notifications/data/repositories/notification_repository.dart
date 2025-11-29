import '../../domain/entities/notification.dart';
import '../../domain/entities/notification_preferences.dart';
import '../datasources/notification_remote_datasource.dart';
import '../models/notification_model.dart';
import '../models/notification_preferences_model.dart';

/// Repository for notification operations
///
/// Abstracts the data source and provides domain-level operations.
/// Handles optimistic updates with rollback on error.
class NotificationRepository {
  final NotificationRemoteDataSource _remoteDataSource;

  NotificationRepository(this._remoteDataSource);

  // =========================================================================
  // NOTIFICATIONS
  // =========================================================================

  /// Get paginated notifications for current user
  Future<List<Notification>> getNotifications({
    int limit = 50,
    int offset = 0,
  }) async {
    final models = await _remoteDataSource.getNotifications(
      limit: limit,
      offset: offset,
    );
    return models.map((m) => m.toEntity()).toList();
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    return _remoteDataSource.getUnreadCount();
  }

  /// Mark notification as read
  ///
  /// Returns the updated notification for optimistic UI
  Future<Notification> markAsRead(Notification notification) async {
    await _remoteDataSource.markAsRead(notification.id);
    return notification.copyWith(isRead: true);
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead() async {
    await _remoteDataSource.markAllAsRead();
  }

  /// Delete notification
  Future<void> deleteNotification(String notificationId) async {
    await _remoteDataSource.deleteNotification(notificationId);
  }

  /// Delete all notifications
  Future<void> deleteAllNotifications() async {
    await _remoteDataSource.deleteAllNotifications();
  }

  // =========================================================================
  // REALTIME
  // =========================================================================

  /// Subscribe to real-time notification stream
  Stream<Notification> subscribeToNotifications() {
    return _remoteDataSource
        .subscribeToNotifications()
        .map((model) => model.toEntity());
  }

  /// Subscribe to unread count changes
  Stream<int> subscribeToUnreadCount() {
    return _remoteDataSource.subscribeToUnreadCount();
  }

  // =========================================================================
  // PREFERENCES
  // =========================================================================

  /// Get notification preferences
  Future<NotificationPreferences> getPreferences() async {
    final model = await _remoteDataSource.getPreferences();
    return model.toEntity();
  }

  /// Update all notification preferences
  Future<void> updatePreferences(NotificationPreferences preferences) async {
    final model = NotificationPreferencesModel.fromEntity(preferences);
    await _remoteDataSource.updatePreferences(model);
  }

  /// Toggle a single preference by column name
  ///
  /// Column names: eventi_moderati_enabled, nuovi_commenti_enabled, etc.
  Future<void> togglePreference(String columnName, bool value) async {
    await _remoteDataSource.togglePreference(columnName, value);
  }
}
