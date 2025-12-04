// =====================================================================
// HandlePushTap Use Case - Push Notifications Feature (009)
// =====================================================================
// Purpose: Handle push notification taps and convert to navigation actions
// Called: When user taps a push notification (background or terminated)
// =====================================================================

import 'package:flutter/foundation.dart';

import '../entities/push_payload.dart';
import '../../data/repositories/notification_repository.dart';

/// Navigation action type from push tap
enum PushNavigationType {
  /// Navigate to event detail screen
  event,

  /// Navigate to event detail with comments open, scroll to specific comment
  comment,

  /// Navigate to profile screen
  profile,

  /// Navigate to global chat screen
  chat,

  /// Unknown target type - show error
  unknown,
}

/// Result of handling a push tap
class PushNavigationResult {
  /// Type of navigation to perform
  final PushNavigationType type;

  /// Event ID for navigation (event or comment target)
  final String? eventId;

  /// Comment ID for navigation (comment target only)
  final String? commentId;

  /// User ID for profile navigation
  final String? userId;

  /// Message ID for chat navigation (scroll to specific message)
  final String? messageId;

  /// Notification ID (for marking as read)
  final String? notificationId;

  /// Error message if navigation failed
  final String? error;

  const PushNavigationResult({
    required this.type,
    this.eventId,
    this.commentId,
    this.userId,
    this.messageId,
    this.notificationId,
    this.error,
  });

  /// Check if navigation is valid
  bool get isValid => error == null && type != PushNavigationType.unknown;

  /// Create error result
  factory PushNavigationResult.error(String message) => PushNavigationResult(
        type: PushNavigationType.unknown,
        error: message,
      );
}

/// Use case for handling push notification taps
///
/// Converts PushPayload into navigation action and marks
/// the notification as read.
///
/// Usage:
/// ```dart
/// final useCase = HandlePushTap(repository);
/// final result = await useCase.execute(payload);
/// if (result.isValid) {
///   // Navigate based on result.type
/// }
/// ```
class HandlePushTap {
  final NotificationRepository _repository;

  HandlePushTap(this._repository);

  /// Handle push notification tap
  ///
  /// [payload] - The parsed push notification payload
  /// Returns navigation result with target info
  Future<PushNavigationResult> execute(PushPayload payload) async {
    debugPrint('🔔 HandlePushTap: Processing ${payload.targetType}');

    // Mark notification as read first
    if (payload.notificationId.isNotEmpty) {
      await _markAsRead(payload.notificationId);
    }

    // Convert to navigation result
    switch (payload.targetType) {
      case 'event':
        if (payload.targetId.isEmpty) {
          return PushNavigationResult.error('Event ID missing');
        }
        return PushNavigationResult(
          type: PushNavigationType.event,
          eventId: payload.targetId,
          notificationId: payload.notificationId,
        );

      case 'comment':
        final eventId = payload.navigationEventId;
        if (eventId == null || eventId.isEmpty) {
          return PushNavigationResult.error('Event ID missing for comment');
        }
        return PushNavigationResult(
          type: PushNavigationType.comment,
          eventId: eventId,
          commentId: payload.targetId.isNotEmpty ? payload.targetId : null,
          notificationId: payload.notificationId,
        );

      case 'profile':
        if (payload.targetId.isEmpty) {
          return PushNavigationResult.error('Profile ID missing');
        }
        return PushNavigationResult(
          type: PushNavigationType.profile,
          userId: payload.targetId,
          notificationId: payload.notificationId,
        );

      case 'chat':
      case 'chat_mention':
        // Navigate to chat screen, optionally scroll to message
        return PushNavigationResult(
          type: PushNavigationType.chat,
          messageId: payload.targetId.isNotEmpty ? payload.targetId : null,
          notificationId: payload.notificationId,
        );

      default:
        return PushNavigationResult.error(
          'Unknown target type: ${payload.targetType}',
        );
    }
  }

  /// Mark notification as read
  Future<void> _markAsRead(String notificationId) async {
    try {
      await _repository.markAsRead(notificationId);
      debugPrint('✅ Notification marked as read: $notificationId');
    } catch (e) {
      // Non-fatal - log but continue with navigation
      debugPrint('⚠️ Failed to mark notification as read: $e');
    }
  }
}
