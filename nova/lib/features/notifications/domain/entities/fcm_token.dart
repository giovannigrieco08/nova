// =====================================================================
// FCM Token Entity - Push Notifications Feature (009)
// =====================================================================
// Purpose: Represents a device registration for receiving push notifications
// Note: One user can have multiple tokens (multi-device support)
// =====================================================================

/// FCM token entity for push notifications
///
/// Represents a device registration for receiving push notifications.
/// One user can have multiple tokens (multi-device support).
class FcmToken {
  /// Unique identifier
  final String id;

  /// User who owns this token
  final String userId;

  /// FCM registration token (device-specific)
  final String token;

  /// Platform: 'android' or 'ios'
  final String platform;

  /// Human-readable device name (e.g., "iPhone di Mario")
  final String? deviceName;

  /// When token was registered
  final DateTime createdAt;

  /// Last successful push delivery
  final DateTime lastUsedAt;

  const FcmToken({
    required this.id,
    required this.userId,
    required this.token,
    required this.platform,
    this.deviceName,
    required this.createdAt,
    required this.lastUsedAt,
  });

  /// Check if this is an iOS device
  bool get isIOS => platform == 'ios';

  /// Check if this is an Android device
  bool get isAndroid => platform == 'android';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FcmToken && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'FcmToken(id: $id, platform: $platform, deviceName: $deviceName)';
}
