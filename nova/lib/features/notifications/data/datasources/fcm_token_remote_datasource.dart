// =====================================================================
// FCM Token Remote Data Source - Push Notifications Feature (009)
// =====================================================================
// Purpose: Supabase API calls for FCM token CRUD operations
// Uses: upsert_fcm_token() and delete_fcm_token() database functions
// =====================================================================

import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fcm_token_model.dart';

/// Remote data source for FCM token operations using Supabase
///
/// Handles all Supabase API calls for FCM token management.
/// Uses database functions for upsert/delete operations.
class FcmTokenRemoteDataSource {
  final SupabaseClient _supabase;

  FcmTokenRemoteDataSource(this._supabase);

  /// Get current user ID
  String? get _currentUserId => _supabase.auth.currentUser?.id;

  /// Get platform string ('android' or 'ios')
  String get _platform {
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return 'unknown';
  }

  /// Get device name for display purposes
  String? get _deviceName {
    // Returns a generic name - could be enhanced with device_info_plus
    if (Platform.isIOS) return 'iPhone';
    if (Platform.isAndroid) return 'Android';
    return null;
  }

  // =========================================================================
  // TOKEN CRUD OPERATIONS
  // =========================================================================

  /// Register or update FCM token for current user
  ///
  /// Uses upsert_fcm_token database function which handles:
  /// - Insert if token doesn't exist
  /// - Update last_used_at if token exists
  /// - Returns the token ID (new or existing)
  Future<String?> upsertToken(String fcmToken) async {
    final userId = _currentUserId;
    if (userId == null) {
      return null;
    }

    try {
      final response = await _supabase.rpc(
        'upsert_fcm_token',
        params: {
          'p_user_id': userId,
          'p_token': fcmToken,
          'p_platform': _platform,
          'p_device_name': _deviceName,
        },
      );

      return response as String?;
    } catch (e) {
      rethrow;
    }
  }

  /// Delete FCM token on logout
  ///
  /// Uses delete_fcm_token database function which handles:
  /// - Delete token by value (not ID)
  /// - Returns success boolean
  Future<bool> deleteToken(String fcmToken) async {
    final userId = _currentUserId;
    if (userId == null) {
      return false;
    }

    try {
      final response = await _supabase.rpc(
        'delete_fcm_token',
        params: {
          'p_user_id': userId,
          'p_token': fcmToken,
        },
      );

      final success = response as bool? ?? false;
      return success;
    } catch (e) {
      rethrow;
    }
  }

  /// Get all FCM tokens for current user
  ///
  /// Useful for showing "Logged in devices" UI in settings.
  Future<List<FcmTokenModel>> getUserTokens() async {
    final userId = _currentUserId;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('fcm_tokens')
          .select()
          .eq('user_id', userId)
          .order('last_used_at', ascending: false);

      return (response as List)
          .map((json) => FcmTokenModel.fromJson(json))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Delete all FCM tokens for current user (on account deletion or full logout)
  Future<void> deleteAllUserTokens() async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _supabase.from('fcm_tokens').delete().eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }

  // =========================================================================
  // PUSH ENABLED FLAG
  // =========================================================================

  /// Get push_enabled flag from profile
  Future<bool> getPushEnabled() async {
    final userId = _currentUserId;
    if (userId == null) return false;

    try {
      final response = await _supabase
          .from('profiles')
          .select('push_enabled')
          .eq('user_id', userId)
          .single();

      return response['push_enabled'] as bool? ?? true;
    } catch (e) {
      return true; // Default to enabled
    }
  }

  /// Set push_enabled flag in profile
  Future<void> setPushEnabled(bool enabled) async {
    final userId = _currentUserId;
    if (userId == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({'push_enabled': enabled}).eq('user_id', userId);
    } catch (e) {
      rethrow;
    }
  }
}
