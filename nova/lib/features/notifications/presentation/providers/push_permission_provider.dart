// =====================================================================
// Push Permission Provider - Push Notifications Feature (009)
// =====================================================================
// Purpose: Manage push notification permission state with SharedPreferences
// Handles: Permission status, first-time request flow, open settings
// =====================================================================

import 'package:app_settings/app_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/push_notification_service.dart';
import '../../domain/entities/notification_permission_state.dart';
import 'push_providers.dart';

// ============================================================================
// SHARED PREFERENCES KEYS
// ============================================================================

/// Key for storing whether we've asked for permission
const _kHasAskedPermission = 'push_has_asked_permission';

/// Key for storing when we last asked (for "ask again later" flow)
const _kLastAskedTimestamp = 'push_last_asked_timestamp';

// ============================================================================
// PERMISSION STATE
// ============================================================================

/// Push permission state for UI
class PushPermissionState {
  /// Current permission status
  final NotificationPermissionState status;

  /// Whether we've ever asked for permission
  final bool hasAskedBefore;

  /// Whether permission is being requested
  final bool isRequesting;

  /// Error message if request failed
  final String? error;

  const PushPermissionState({
    this.status = NotificationPermissionState.notDetermined,
    this.hasAskedBefore = false,
    this.isRequesting = false,
    this.error,
  });

  /// Whether notifications can be received
  bool get canReceiveNotifications =>
      status == NotificationPermissionState.granted;

  /// Whether we should show pre-permission dialog
  bool get shouldShowPrePermissionDialog =>
      !hasAskedBefore && status == NotificationPermissionState.notDetermined;

  /// Whether permission was denied (show "enable in settings" option)
  bool get wasPermissionDenied =>
      hasAskedBefore && status == NotificationPermissionState.denied;

  PushPermissionState copyWith({
    NotificationPermissionState? status,
    bool? hasAskedBefore,
    bool? isRequesting,
    String? error,
  }) {
    return PushPermissionState(
      status: status ?? this.status,
      hasAskedBefore: hasAskedBefore ?? this.hasAskedBefore,
      isRequesting: isRequesting ?? this.isRequesting,
      error: error,
    );
  }
}

// ============================================================================
// PERMISSION NOTIFIER
// ============================================================================

/// Push permission state notifier
///
/// Manages the complete permission flow:
/// 1. Check current status on init
/// 2. Track whether we've asked before (SharedPreferences)
/// 3. Request permission with pre-dialog flow
/// 4. Open app settings for denied users
class PushPermissionNotifier extends StateNotifier<PushPermissionState> {
  final PushNotificationService _pushService;
  final Future<SharedPreferences> Function() _getPrefs;

  PushPermissionNotifier(
    this._pushService, {
    Future<SharedPreferences> Function()? getPrefs,
  })  : _getPrefs = getPrefs ?? SharedPreferences.getInstance,
        super(const PushPermissionState()) {
    _initialize();
  }

  /// Initialize by checking current status and prefs
  Future<void> _initialize() async {
    try {
      final prefs = await _getPrefs();
      final hasAsked = prefs.getBool(_kHasAskedPermission) ?? false;
      final currentStatus = await _pushService.checkPermissionStatus();

      state = state.copyWith(
        status: currentStatus,
        hasAskedBefore: hasAsked,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  /// Refresh permission status (e.g., after returning from settings)
  Future<void> refreshStatus() async {
    final currentStatus = await _pushService.checkPermissionStatus();
    state = state.copyWith(status: currentStatus);
  }

  /// Request notification permission
  ///
  /// Call this after showing the pre-permission explanation.
  /// Stores "has asked" flag in SharedPreferences.
  Future<NotificationPermissionState> requestPermission() async {
    state = state.copyWith(isRequesting: true, error: null);

    try {
      // Store that we've asked
      final prefs = await _getPrefs();
      await prefs.setBool(_kHasAskedPermission, true);
      await prefs.setInt(
          _kLastAskedTimestamp, DateTime.now().millisecondsSinceEpoch);

      // Request permission
      final result = await _pushService.requestPermission();

      state = state.copyWith(
        status: result,
        hasAskedBefore: true,
        isRequesting: false,
      );

      return result;
    } catch (e) {
      state = state.copyWith(
        isRequesting: false,
        error: e.toString(),
      );
      return NotificationPermissionState.denied;
    }
  }

  /// Open app settings for denied users
  ///
  /// Returns true if settings were opened successfully.
  Future<bool> openAppSettings() async {
    try {
      await AppSettings.openAppSettings(type: AppSettingsType.notification);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Impossibile aprire le impostazioni');
      return false;
    }
  }

  /// Mark that user dismissed the pre-permission dialog
  ///
  /// This allows us to not show it again (they chose "Later")
  Future<void> markAskedLater() async {
    final prefs = await _getPrefs();
    await prefs.setBool(_kHasAskedPermission, true);
    await prefs.setInt(
        _kLastAskedTimestamp, DateTime.now().millisecondsSinceEpoch);

    state = state.copyWith(hasAskedBefore: true);
  }

  /// Clear error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Push permission notifier provider
///
/// Usage:
/// ```dart
/// // Watch state
/// final permissionState = ref.watch(pushPermissionProvider);
///
/// // Request permission
/// final notifier = ref.read(pushPermissionProvider.notifier);
/// final result = await notifier.requestPermission();
///
/// // Open settings (for denied users)
/// await notifier.openAppSettings();
/// ```
final pushPermissionProvider =
    StateNotifierProvider<PushPermissionNotifier, PushPermissionState>((ref) {
  final pushService = ref.watch(pushNotificationServiceProvider);
  return PushPermissionNotifier(pushService);
});
