// Repository Implementation: NotificationRepository
// Feature: 004-event-creation-moderation (US2 - Status Tracking)
// Purpose: Concrete implementation of NotificationRepository interface
//
// Responsibilities:
// - Fetch notifications from Supabase notifications table
// - Mark notifications as read
// - Subscribe to real-time notification updates

import '../../domain/entities/app_notification.dart';
import '../../domain/repositories/notification_repository_interface.dart';
import '../datasources/notification_remote_datasource.dart';

/// Concrete implementation of NotificationRepository
class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationRemoteDataSource _remoteDataSource;

  NotificationRepositoryImpl({
    required NotificationRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  // =========================================================================
  // READ OPERATIONS
  // =========================================================================

  @override
  Future<List<AppNotification>> getMyNotifications(String userId) async {
    try {
      final models = await _remoteDataSource.getMyNotifications(userId);
      return models.map((model) => model.toEntity()).toList();
    } catch (e) {
      throw NotificationRepositoryException(
          'Failed to fetch notifications: $e');
    }
  }

  @override
  Future<int> getUnreadCount(String userId) async {
    try {
      return await _remoteDataSource.getUnreadCount(userId);
    } catch (e) {
      throw NotificationRepositoryException('Failed to fetch unread count: $e');
    }
  }

  @override
  Future<List<AppNotification>> getNotificationsByChannel(
    String userId,
    String channel,
  ) async {
    try {
      final models = await _remoteDataSource.getNotificationsByChannel(
        userId,
        channel,
      );
      return models.map((model) => model.toEntity()).toList();
    } catch (e) {
      throw NotificationRepositoryException(
        'Failed to fetch notifications by channel: $e',
      );
    }
  }

  // =========================================================================
  // WRITE OPERATIONS
  // =========================================================================

  @override
  Future<void> markAsRead(String notificationId) async {
    try {
      await _remoteDataSource.markAsRead(notificationId);
    } catch (e) {
      throw NotificationRepositoryException('Failed to mark as read: $e');
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    try {
      await _remoteDataSource.markAllAsRead(userId);
    } catch (e) {
      throw NotificationRepositoryException('Failed to mark all as read: $e');
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _remoteDataSource.deleteNotification(notificationId);
    } catch (e) {
      throw NotificationRepositoryException(
          'Failed to delete notification: $e');
    }
  }

  // =========================================================================
  // REALTIME SUBSCRIPTION
  // =========================================================================

  @override
  Stream<AppNotification> subscribeToNotifications(String userId) {
    try {
      return _remoteDataSource
          .subscribeToNotifications(userId)
          .map((model) => model.toEntity());
    } catch (e) {
      throw NotificationRepositoryException(
        'Failed to subscribe to notifications: $e',
      );
    }
  }
}

/// Exception thrown when repository operation fails
class NotificationRepositoryException implements Exception {
  final String message;

  NotificationRepositoryException(this.message);

  @override
  String toString() => 'NotificationRepositoryException: $message';
}
