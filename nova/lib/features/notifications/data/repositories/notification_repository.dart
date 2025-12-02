// Repository: NotificationRepository
// Feature: Notifications
// Purpose: Repository for notification operations (stub)

import '../datasources/notification_remote_datasource.dart';
import '../../domain/entities/notification.dart';

/// Notification repository
class NotificationRepository {
  final NotificationRemoteDataSource _remoteDataSource;

  NotificationRepository(this._remoteDataSource);

  /// Get notifications
  Future<List<AppNotification>> getNotifications({int limit = 50}) {
    return _remoteDataSource.getNotifications(limit: limit);
  }

  /// Mark notification as read
  Future<void> markAsRead(String notificationId) {
    return _remoteDataSource.markAsRead(notificationId);
  }

  /// Mark all as read
  Future<void> markAllAsRead() {
    return _remoteDataSource.markAllAsRead();
  }

  /// Get unread count
  Future<int> getUnreadCount() {
    return _remoteDataSource.getUnreadCount();
  }
}
