// =====================================================================
// Notification Permission State - Push Notifications Feature (009)
// =====================================================================
// Purpose: Enum representing push notification permission states
// Used by: PushPermissionProvider for tracking permission status
// =====================================================================

/// Push notification permission state
///
/// Represents the current state of notification permissions on the device.
/// Used to determine what UI to show and whether to request permissions.
enum NotificationPermissionState {
  /// User hasn't been asked yet
  notDetermined,

  /// User granted permission
  granted,

  /// User denied permission (can be asked again on Android)
  denied,

  /// Permission permanently denied (must go to system settings)
  /// On iOS: After denial, always permanentlyDenied
  /// On Android 13+: After two denials, permanentlyDenied
  permanentlyDenied,
}

/// Extension methods for NotificationPermissionState
extension NotificationPermissionStateX on NotificationPermissionState {
  /// Check if permission allows receiving notifications
  bool get canReceiveNotifications =>
      this == NotificationPermissionState.granted;

  /// Check if we should show permission request
  bool get shouldRequestPermission =>
      this == NotificationPermissionState.notDetermined;

  /// Check if user needs to go to settings to enable
  bool get needsSettingsRedirect =>
      this == NotificationPermissionState.permanentlyDenied;

  /// Check if permission was denied (either temporarily or permanently)
  bool get isDenied =>
      this == NotificationPermissionState.denied ||
      this == NotificationPermissionState.permanentlyDenied;

  /// Get user-facing message in Italian
  String get userMessage {
    switch (this) {
      case NotificationPermissionState.notDetermined:
        return 'Permesso notifiche non richiesto';
      case NotificationPermissionState.granted:
        return 'Notifiche abilitate';
      case NotificationPermissionState.denied:
        return 'Notifiche disabilitate';
      case NotificationPermissionState.permanentlyDenied:
        return 'Notifiche disabilitate. Vai alle impostazioni per abilitarle.';
    }
  }
}
