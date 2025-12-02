// =====================================================================
// Push Repository Interface - Push Notifications Feature (009)
// =====================================================================
// Purpose: Abstract repository interface for push notification operations
// Implements: Clean architecture repository pattern
// =====================================================================

import '../entities/fcm_token.dart';

/// Abstract repository interface for push notification operations
///
/// Defines the contract for push notification token management.
/// Implementation handles Supabase communication and token lifecycle.
abstract class PushRepository {
  // =========================================================================
  // TOKEN MANAGEMENT
  // =========================================================================

  /// Register FCM token for current user's device
  ///
  /// [fcmToken] - The FCM registration token from Firebase
  /// Returns the token ID if successful, null if failed
  Future<String?> registerToken(String fcmToken);

  /// Remove FCM token on logout
  ///
  /// [fcmToken] - The FCM registration token to remove
  /// Returns true if successfully deleted
  Future<bool> removeToken(String fcmToken);

  /// Get all registered tokens for current user
  ///
  /// Useful for "Logged in devices" UI in settings.
  Future<List<FcmToken>> getUserTokens();

  /// Remove all tokens for current user
  ///
  /// Used on account deletion or "logout from all devices".
  Future<void> removeAllTokens();

  // =========================================================================
  // PUSH SETTINGS
  // =========================================================================

  /// Get global push notification enabled flag
  Future<bool> isPushEnabled();

  /// Set global push notification enabled flag
  Future<void> setPushEnabled(bool enabled);
}
