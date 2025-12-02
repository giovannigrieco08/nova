// =====================================================================
// RemoveFcmToken Use Case - Push Notifications Feature (009)
// =====================================================================
// Purpose: Remove FCM token on user logout
// Called: Before signOut to stop push notifications to this device
// =====================================================================

import '../repositories/push_repository_interface.dart';

/// Use case for removing FCM token on logout
///
/// Removes the device's FCM token from Supabase so that
/// push notifications are no longer sent to this device.
///
/// Usage:
/// ```dart
/// final useCase = RemoveFcmToken(repository);
/// final success = await useCase.execute(fcmToken);
/// ```
class RemoveFcmToken {
  final PushRepository _repository;

  RemoveFcmToken(this._repository);

  /// Remove FCM token for current device
  ///
  /// [fcmToken] - The FCM registration token to remove
  /// Returns true if successfully deleted
  Future<bool> execute(String fcmToken) async {
    return _repository.removeToken(fcmToken);
  }
}
