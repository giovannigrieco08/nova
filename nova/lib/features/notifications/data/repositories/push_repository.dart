// =====================================================================
// Push Repository Implementation - Push Notifications Feature (009)
// =====================================================================
// Purpose: Concrete implementation of PushRepository using Supabase
// Depends on: FcmTokenRemoteDataSource
// =====================================================================

import '../../domain/entities/fcm_token.dart';
import '../../domain/repositories/push_repository_interface.dart';
import '../datasources/fcm_token_remote_datasource.dart';

/// Push repository implementation using Supabase
///
/// Handles FCM token lifecycle and push notification settings.
class PushRepositoryImpl implements PushRepository {
  final FcmTokenRemoteDataSource _remoteDataSource;

  PushRepositoryImpl(this._remoteDataSource);

  // =========================================================================
  // TOKEN MANAGEMENT
  // =========================================================================

  @override
  Future<String?> registerToken(String fcmToken) async {
    return _remoteDataSource.upsertToken(fcmToken);
  }

  @override
  Future<bool> removeToken(String fcmToken) async {
    return _remoteDataSource.deleteToken(fcmToken);
  }

  @override
  Future<List<FcmToken>> getUserTokens() async {
    final models = await _remoteDataSource.getUserTokens();
    return models.map((m) => m.toEntity()).toList();
  }

  @override
  Future<void> removeAllTokens() async {
    await _remoteDataSource.deleteAllUserTokens();
  }

  // =========================================================================
  // PUSH SETTINGS
  // =========================================================================

  @override
  Future<bool> isPushEnabled() async {
    return _remoteDataSource.getPushEnabled();
  }

  @override
  Future<void> setPushEnabled(bool enabled) async {
    await _remoteDataSource.setPushEnabled(enabled);
  }
}
