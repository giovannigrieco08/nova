// =====================================================================
// Push Notification Service - Push Notifications Feature (009)
// =====================================================================
// Purpose: Core service for FCM initialization, token management, and
//          handling push notifications in all app states
// States: Foreground, Background, Terminated
// =====================================================================

import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:flutter_app_badger/flutter_app_badger.dart'; // REMOVED: incompatible with AGP 8.0+
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../features/notifications/domain/entities/push_payload.dart';
import '../../features/notifications/domain/entities/notification_permission_state.dart';
import '../../features/notifications/domain/repositories/push_repository_interface.dart';

/// SharedPreferences key for app instance ID (used for reinstall detection)
const _kAppInstanceId = 'push_app_instance_id';

/// Callback type for handling push notification taps
typedef OnPushTapCallback = void Function(PushPayload payload);

/// Callback type for handling foreground notifications
typedef OnForegroundNotificationCallback = void Function(PushPayload payload);

/// Push notification service for FCM integration
///
/// Handles:
/// - FCM token registration and lifecycle
/// - Permission requests (iOS/Android 13+)
/// - Push notification handling in all app states
/// - Badge count management
/// - Deep link navigation from push taps
class PushNotificationService {
  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications;
  final PushRepository _repository;

  /// Callback when user taps a notification (background/terminated)
  OnPushTapCallback? onPushTap;

  /// Callback when notification arrives in foreground
  OnForegroundNotificationCallback? onForegroundNotification;

  /// Current FCM token (cached)
  String? _currentToken;

  /// Whether service is initialized
  bool _isInitialized = false;

  PushNotificationService({
    required FirebaseMessaging messaging,
    required FlutterLocalNotificationsPlugin localNotifications,
    required PushRepository repository,
  })  : _messaging = messaging,
        _localNotifications = localNotifications,
        _repository = repository;

  /// Get current FCM token
  String? get currentToken => _currentToken;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  // =========================================================================
  // INITIALIZATION
  // =========================================================================

  /// Initialize push notification service
  ///
  /// Call this after user is authenticated and ready to receive pushes.
  /// Sets up message handlers for all app states.
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    // Initialize local notifications for foreground display
    await _initializeLocalNotifications();

    // Setup FCM message handlers
    _setupMessageHandlers();

    // Setup token refresh listener
    _setupTokenRefreshListener();

    _isInitialized = true;
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create Android notification channel
    await _createAndroidNotificationChannel();
  }

  /// Create Android notification channel (required for Android 8+)
  Future<void> _createAndroidNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      'nova_push_channel',
      'Nova Notifications',
      description: 'Notifiche per eventi e attività Nova',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Setup FCM message handlers for all app states
  void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background tap (app in background, user taps notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleBackgroundTap);
  }

  /// Setup token refresh listener
  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen((newToken) async {
      await _handleTokenRefresh(newToken);
    });
  }

  // =========================================================================
  // PERMISSION HANDLING
  // =========================================================================

  /// Check current notification permission status
  Future<NotificationPermissionState> checkPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();

    switch (settings.authorizationStatus) {
      case AuthorizationStatus.authorized:
        return NotificationPermissionState.granted;
      case AuthorizationStatus.denied:
        return NotificationPermissionState.denied;
      case AuthorizationStatus.provisional:
        return NotificationPermissionState.granted;
      case AuthorizationStatus.notDetermined:
        return NotificationPermissionState.notDetermined;
    }
  }

  /// Request notification permissions
  ///
  /// Returns the resulting permission state.
  /// On iOS: Shows system permission dialog
  /// On Android 13+: Shows runtime permission dialog
  Future<NotificationPermissionState> requestPermission() async {

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final status = switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized => NotificationPermissionState.granted,
      AuthorizationStatus.denied => NotificationPermissionState.denied,
      AuthorizationStatus.provisional => NotificationPermissionState.granted,
      AuthorizationStatus.notDetermined =>
        NotificationPermissionState.notDetermined,
    };

    return status;
  }

  // =========================================================================
  // TOKEN MANAGEMENT
  // =========================================================================

  /// Register FCM token for current user
  ///
  /// Call this after user authenticates and grants notification permission.
  /// Detects app reinstall and cleans up stale tokens if needed (T076).
  /// Returns the registered token ID, or null if failed.
  Future<String?> registerToken() async {
    try {
      // Check for app reinstall and cleanup stale tokens (T076)
      await _handleAppReinstallIfNeeded();

      // Get FCM token
      final token = await _messaging.getToken();
      if (token == null) {
        return null;
      }

      _currentToken = token;

      // Register with backend
      final tokenId = await _repository.registerToken(token);
      return tokenId;
    } catch (e) {
      return null;
    }
  }

  /// Detect app reinstall and cleanup old tokens (T076)
  ///
  /// Uses a unique app instance ID stored in SharedPreferences.
  /// If the ID doesn't exist (fresh install/reinstall), cleans up
  /// all existing tokens for this user before registering new one.
  Future<void> _handleAppReinstallIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedInstanceId = prefs.getString(_kAppInstanceId);

      if (storedInstanceId == null) {
        // Fresh install or reinstall detected
        // Remove all tokens for this user (they're now invalid)
        await _repository.removeAllTokens();

        // Generate and store new instance ID
        const uuid = Uuid();
        final newInstanceId = uuid.v4();
        await prefs.setString(_kAppInstanceId, newInstanceId);
      }
    } catch (e) {
      // Non-fatal - continue with registration
    }
  }

  /// Remove FCM token (call on logout)
  ///
  /// Removes the current device's token from backend.
  Future<bool> removeToken() async {
    if (_currentToken == null) {
      return true;
    }

    try {
      final success = await _repository.removeToken(_currentToken!);
      if (success) {
        _currentToken = null;
      }
      return success;
    } catch (e) {
      return false;
    }
  }

  /// Handle token refresh (called when FCM token changes)
  Future<void> _handleTokenRefresh(String newToken) async {
    // Remove old token if exists
    if (_currentToken != null && _currentToken != newToken) {
      await _repository.removeToken(_currentToken!);
    }

    // Register new token
    _currentToken = newToken;
    await _repository.registerToken(newToken);
  }

  // =========================================================================
  // MESSAGE HANDLERS
  // =========================================================================

  /// Handle notification tap on local notification
  void _onLocalNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    try {
      // Parse payload JSON
      // For simplicity, we encode payload as key=value pairs
      final data = _parsePayloadString(payload);
      final pushPayload = PushPayload.fromFcmData(data);
      onPushTap?.call(pushPayload);
    } catch (e) {
      // Failed to parse local notification payload - ignore
    }
  }

  /// Parse payload string to map (simple key=value format)
  Map<String, dynamic> _parsePayloadString(String payload) {
    final map = <String, dynamic>{};
    for (final pair in payload.split('&')) {
      final parts = pair.split('=');
      if (parts.length == 2) {
        map[parts[0]] = Uri.decodeComponent(parts[1]);
      }
    }
    return map;
  }

  /// Encode payload map to string
  String _encodePayloadToString(Map<String, dynamic> data) {
    return data.entries
        .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
        .join('&');
  }

  /// Handle foreground message
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    // Parse payload
    final payload = PushPayload.fromFcmData(message.data);

    // Update badge
    await _updateBadge(payload.badgeCount);

    // Notify callback for in-app banner
    onForegroundNotification?.call(payload);

    // Optionally show local notification
    await _showLocalNotification(message, payload);
  }

  /// Handle background tap (app was in background, user tapped notification)
  void _handleBackgroundTap(RemoteMessage message) {
    final payload = PushPayload.fromFcmData(message.data);
    onPushTap?.call(payload);
  }

  /// Check if app was opened from terminated state via push
  ///
  /// Call this on app startup to handle cold start from push tap.
  Future<PushPayload?> getInitialMessage() async {
    final message = await _messaging.getInitialMessage();
    if (message == null) return null;

    return PushPayload.fromFcmData(message.data);
  }

  /// Show local notification (for foreground state)
  Future<void> _showLocalNotification(
    RemoteMessage message,
    PushPayload payload,
  ) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'nova_push_channel',
      'Nova Notifications',
      channelDescription: 'Notifiche per eventi e attività Nova',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: _encodePayloadToString(payload.toFcmData()),
    );
  }

  // =========================================================================
  // BADGE MANAGEMENT
  // =========================================================================

  /// Update app icon badge count
  ///
  /// NOTE: Badge functionality disabled - flutter_app_badger removed due to
  /// AGP 8.0+ compatibility issues. Will be re-enabled when package is updated.
  Future<void> _updateBadge(int count) async {
    // Badge functionality disabled - flutter_app_badger incompatible with AGP 8.0+
  }

  /// Clear badge (call when user reads all notifications)
  Future<void> clearBadge() async {
    await _updateBadge(0);
  }

  /// Set badge count (call when unread count changes)
  Future<void> setBadgeCount(int count) async {
    await _updateBadge(count);
  }

  // =========================================================================
  // CLEANUP
  // =========================================================================

  /// Dispose service (call on app termination)
  void dispose() {
    _isInitialized = false;
    onPushTap = null;
    onForegroundNotification = null;
  }
}
