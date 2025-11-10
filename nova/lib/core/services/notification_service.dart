// Core Service: NotificationService
// Feature: 004-event-creation-moderation (US2 - Status Tracking)
// Purpose: Firebase Cloud Messaging (FCM) integration for push notifications
//
// Responsibilities:
// - Initialize FCM and request permissions
// - Save FCM token to Supabase users table (user_metadata.fcm_token)
// - Handle foreground/background/terminated message callbacks
// - Define notification channels for Android 8.0+ (Oreo)
//
// Supported Channels (from migration 005):
// 1. event_approved: "Il tuo evento è stato approvato!"
// 2. event_rejected: "Il tuo evento è stato rifiutato"
// 3. new_pending_event: "Nuovo evento da moderare" (moderators only)
// 4. added_as_coorganizer: "Sei stato aggiunto come co-organizer"
// 5. event_modified: "Un evento che organizzi è stato modificato"

import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Notification service for Firebase Cloud Messaging
class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SupabaseClient _supabase;

  NotificationService(this._supabase);

  /// Initialize FCM and request permissions
  ///
  /// Must be called after user logs in.
  Future<void> initialize() async {
    try {
      // Request notification permissions (iOS requires explicit request)
      final settings = await _requestPermissions();

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Get FCM token
        final token = await _fcm.getToken();
        if (token != null) {
          await _saveFcmToken(token);
        }

        // Listen for token refreshes (rare, but possible)
        _fcm.onTokenRefresh.listen(_saveFcmToken);

        // Setup message handlers
        _setupMessageHandlers();

        assert(() {
          debugPrint('✅ FCM initialized successfully. Token: ${token?.substring(0, 20)}...');
          return true;
        }());
      } else {
        assert(() {
          debugPrint('⚠️ Notification permissions denied: ${settings.authorizationStatus}');
          return true;
        }());
      }
    } catch (e) {
      assert(() {
        debugPrint('❌ FCM initialization failed: $e');
        return true;
      }());
    }
  }

  /// Request notification permissions (iOS requires explicit request)
  Future<NotificationSettings> _requestPermissions() async {
    return await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
    );
  }

  /// Save FCM token to Supabase user_metadata
  ///
  /// Token is stored in auth.users table:
  /// raw_user_meta_data->fcm_token
  Future<void> _saveFcmToken(String token) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Update user metadata with FCM token
      await _supabase.auth.updateUser(
        UserAttributes(
          data: {'fcm_token': token},
        ),
      );

      assert(() {
        debugPrint('✅ FCM token saved to Supabase: ${token.substring(0, 20)}...');
        return true;
      }());
    } catch (e) {
      assert(() {
        debugPrint('❌ Failed to save FCM token: $e');
        return true;
      }());
    }
  }

  /// Setup message handlers for foreground/background/terminated states
  void _setupMessageHandlers() {
    // FOREGROUND: App is open and in focus
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // BACKGROUND TAP: User taps notification while app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundTap);

    // TERMINATED: Check if app was opened from terminated state via notification
    _checkTerminatedNotification();
  }

  /// Handle foreground message (app is open)
  ///
  /// Show in-app notification banner (custom implementation required)
  void _handleForegroundMessage(RemoteMessage message) {
    assert(() {
      debugPrint('🔔 Foreground notification received:');
      debugPrint('   Title: ${message.notification?.title}');
      debugPrint('   Body: ${message.notification?.body}');
      debugPrint('   Data: ${message.data}');
      return true;
    }());

    // TODO: Show in-app notification banner using package like overlay_support
    // For now, just log it (will be implemented in Phase 4)
  }

  /// Handle background tap (user taps notification)
  ///
  /// Navigate to appropriate screen based on notification data
  void _handleBackgroundTap(RemoteMessage message) {
    assert(() {
      debugPrint('🔔 Background notification tapped:');
      debugPrint('   Data: ${message.data}');
      return true;
    }());

    // Extract event_id from notification data
    final eventId = message.data['event_id'] as String?;

    if (eventId != null) {
      // TODO: Navigate to EventDetailScreen (requires navigation context)
      // Will be implemented in Phase 4 with proper router integration
    }
  }

  /// Check if app was opened from terminated state via notification
  Future<void> _checkTerminatedNotification() async {
    final message = await _fcm.getInitialMessage();
    if (message != null) {
      _handleBackgroundTap(message);
    }
  }

  /// Get current FCM token (for debugging)
  Future<String?> getCurrentToken() async {
    return await _fcm.getToken();
  }

  /// Delete FCM token (for logout)
  Future<void> deleteToken() async {
    try {
      await _fcm.deleteToken();
      assert(() {
        debugPrint('✅ FCM token deleted');
        return true;
      }());
    } catch (e) {
      assert(() {
        debugPrint('❌ Failed to delete FCM token: $e');
        return true;
      }());
    }
  }

  /// Subscribe to topic (for future use - e.g., class-specific notifications)
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _fcm.subscribeToTopic(topic);
      assert(() {
        debugPrint('✅ Subscribed to topic: $topic');
        return true;
      }());
    } catch (e) {
      assert(() {
        debugPrint('❌ Failed to subscribe to topic: $e');
        return true;
      }());
    }
  }

  /// Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _fcm.unsubscribeFromTopic(topic);
      assert(() {
        debugPrint('✅ Unsubscribed from topic: $topic');
        return true;
      }());
    } catch (e) {
      assert(() {
        debugPrint('❌ Failed to unsubscribe from topic: $e');
        return true;
      }());
    }
  }
}

/// Notification channels for Android 8.0+ (Oreo)
///
/// These must match the channels defined in Supabase notifications table.
/// iOS does not use channels - notifications are controlled in Settings app.
class NotificationChannels {
  // Prevent instantiation
  NotificationChannels._();

  static const String eventApproved = 'event_approved';
  static const String eventRejected = 'event_rejected';
  static const String newPendingEvent = 'new_pending_event';
  static const String addedAsCoorganizer = 'added_as_coorganizer';
  static const String eventModified = 'event_modified';

  /// Get user-friendly channel name
  static String getChannelName(String channelId) {
    switch (channelId) {
      case eventApproved:
        return 'Evento Approvato';
      case eventRejected:
        return 'Evento Rifiutato';
      case newPendingEvent:
        return 'Nuovi Eventi da Moderare';
      case addedAsCoorganizer:
        return 'Co-Organizer';
      case eventModified:
        return 'Eventi Modificati';
      default:
        return 'Notifiche';
    }
  }

  /// Get channel description
  static String getChannelDescription(String channelId) {
    switch (channelId) {
      case eventApproved:
        return 'Notifiche quando i tuoi eventi vengono approvati';
      case eventRejected:
        return 'Notifiche quando i tuoi eventi vengono rifiutati';
      case newPendingEvent:
        return 'Notifiche per moderatori: nuovi eventi da revisionare';
      case addedAsCoorganizer:
        return 'Notifiche quando sei aggiunto come co-organizer';
      case eventModified:
        return 'Notifiche quando eventi che organizzi vengono modificati';
      default:
        return 'Notifiche generali';
    }
  }
}
