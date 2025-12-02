// =====================================================================
// RegisterFcmToken Use Case - Push Notifications Feature (009)
// =====================================================================
// Purpose: Register FCM token for current user's device
// Called: After successful authentication and permission granted
// =====================================================================

import '../repositories/push_repository_interface.dart';

/// Use case for registering FCM token on the backend
///
/// Registers the device's FCM token with Supabase so that
/// push notifications can be sent to this device.
///
/// Usage:
/// ```dart
/// final useCase = RegisterFcmToken(repository);
/// final tokenId = await useCase.execute(fcmToken);
/// ```
class RegisterFcmToken {
  final PushRepository _repository;

  RegisterFcmToken(this._repository);

  /// Register FCM token for current user
  ///
  /// [fcmToken] - The FCM registration token from Firebase
  /// Returns the token ID if successful, null if failed
  Future<String?> execute(String fcmToken) async {
    return _repository.registerToken(fcmToken);
  }
}
