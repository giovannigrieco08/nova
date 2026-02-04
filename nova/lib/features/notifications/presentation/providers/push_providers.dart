// =====================================================================
// Push Notification Providers - Push Notifications Feature (009)
// =====================================================================
// Purpose: Riverpod providers for push notification state management
// Includes: Service provider, repository provider, permission state
// =====================================================================

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/push_notification_service.dart';
import '../../domain/entities/fcm_token.dart';
import '../../domain/entities/notification_permission_state.dart';
import '../../domain/repositories/push_repository_interface.dart';
// TODO: handle_push_tap imports missing notification_repository
// import '../../domain/usecases/handle_push_tap.dart';
import '../../data/datasources/fcm_token_remote_datasource.dart';
import '../../data/repositories/push_repository.dart';
// TODO: notification_providers.dart not yet implemented
// import 'notification_providers.dart';

// ============================================================================
// DEPENDENCY INJECTION PROVIDERS
// ============================================================================

/// Supabase client provider (re-export for feature isolation)
final _supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Firebase Messaging instance provider
final _firebaseMessagingProvider = Provider<FirebaseMessaging>((ref) {
  return FirebaseMessaging.instance;
});

/// Flutter Local Notifications plugin provider
final _localNotificationsProvider =
    Provider<FlutterLocalNotificationsPlugin>((ref) {
  return FlutterLocalNotificationsPlugin();
});

/// FCM token remote datasource provider
final fcmTokenRemoteDataSourceProvider =
    Provider<FcmTokenRemoteDataSource>((ref) {
  final supabase = ref.watch(_supabaseClientProvider);
  return FcmTokenRemoteDataSource(supabase);
});

/// Push repository provider
final pushRepositoryProvider = Provider<PushRepository>((ref) {
  final dataSource = ref.watch(fcmTokenRemoteDataSourceProvider);
  return PushRepositoryImpl(dataSource);
});

/// Push notification service provider
///
/// Usage:
/// ```dart
/// final pushService = ref.read(pushNotificationServiceProvider);
/// await pushService.initialize();
/// await pushService.registerToken();
/// ```
final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  final messaging = ref.watch(_firebaseMessagingProvider);
  final localNotifications = ref.watch(_localNotificationsProvider);
  final repository = ref.watch(pushRepositoryProvider);

  return PushNotificationService(
    messaging: messaging,
    localNotifications: localNotifications,
    repository: repository,
  );
});

// ============================================================================
// STATE PROVIDERS
// ============================================================================

/// Push permission state provider
///
/// Provides current notification permission status.
/// Invalidate to recheck after permission request.
///
/// Usage:
/// ```dart
/// final permissionAsync = ref.watch(pushPermissionStateProvider);
/// permissionAsync.when(
///   data: (state) => state.canReceiveNotifications ? ... : ...,
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => Text('Error'),
/// );
/// ```
final pushPermissionStateProvider =
    FutureProvider<NotificationPermissionState>((ref) async {
  final pushService = ref.watch(pushNotificationServiceProvider);
  return pushService.checkPermissionStatus();
});

/// Push enabled state provider (from user profile)
///
/// Returns whether push notifications are globally enabled for user.
/// This is the user preference stored in profiles.push_enabled.
///
/// Usage:
/// ```dart
/// final isPushEnabled = ref.watch(pushEnabledProvider);
/// isPushEnabled.when(
///   data: (enabled) => Switch(value: enabled, onChanged: ...),
///   loading: () => CircularProgressIndicator(),
///   error: (_, __) => Switch(value: true, onChanged: null),
/// );
/// ```
final pushEnabledProvider = FutureProvider<bool>((ref) async {
  final repository = ref.watch(pushRepositoryProvider);
  return repository.isPushEnabled();
});

/// User's FCM tokens provider (all registered devices)
///
/// Returns list of all FCM tokens for current user.
/// Useful for "Logged in devices" UI in settings.
///
/// Usage:
/// ```dart
/// final tokensAsync = ref.watch(userFcmTokensProvider);
/// tokensAsync.when(
///   data: (tokens) => ListView.builder(
///     itemCount: tokens.length,
///     itemBuilder: (ctx, i) => DeviceTile(token: tokens[i]),
///   ),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => Text('Error loading devices'),
/// );
/// ```
final userFcmTokensProvider = FutureProvider<List<FcmToken>>((ref) async {
  final repository = ref.watch(pushRepositoryProvider);
  return repository.getUserTokens();
});

// ============================================================================
// STATE NOTIFIERS
// ============================================================================

/// Push settings state
class PushSettingsState {
  final bool isEnabled;
  final bool isLoading;
  final String? error;

  const PushSettingsState({
    this.isEnabled = true,
    this.isLoading = false,
    this.error,
  });

  PushSettingsState copyWith({
    bool? isEnabled,
    bool? isLoading,
    String? error,
  }) =>
      PushSettingsState(
        isEnabled: isEnabled ?? this.isEnabled,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

/// Push settings notifier for managing push_enabled toggle
class PushSettingsNotifier extends StateNotifier<PushSettingsState> {
  final PushRepository _repository;

  PushSettingsNotifier(this._repository) : super(const PushSettingsState()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    state = state.copyWith(isLoading: true);
    try {
      final isEnabled = await _repository.isPushEnabled();
      state = state.copyWith(isEnabled: isEnabled, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        isEnabled: true, // Default to enabled on error
      );
    }
  }

  /// Toggle push enabled state
  Future<void> setPushEnabled(bool enabled) async {
    final previousState = state;
    state = state.copyWith(isEnabled: enabled, isLoading: true);

    try {
      await _repository.setPushEnabled(enabled);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      // Rollback on error
      state = previousState.copyWith(error: e.toString());
      rethrow;
    }
  }
}

/// Push settings notifier provider
///
/// Usage:
/// ```dart
/// // Read state
/// final settings = ref.watch(pushSettingsNotifierProvider);
///
/// // Toggle
/// final notifier = ref.read(pushSettingsNotifierProvider.notifier);
/// await notifier.setPushEnabled(false);
/// ```
final pushSettingsNotifierProvider =
    StateNotifierProvider<PushSettingsNotifier, PushSettingsState>((ref) {
  final repository = ref.watch(pushRepositoryProvider);
  return PushSettingsNotifier(repository);
});

// ============================================================================
// PERMISSION REQUEST NOTIFIER
// ============================================================================

/// Permission request state
class PermissionRequestState {
  final NotificationPermissionState status;
  final bool isRequesting;
  final String? error;

  const PermissionRequestState({
    this.status = NotificationPermissionState.notDetermined,
    this.isRequesting = false,
    this.error,
  });

  PermissionRequestState copyWith({
    NotificationPermissionState? status,
    bool? isRequesting,
    String? error,
  }) =>
      PermissionRequestState(
        status: status ?? this.status,
        isRequesting: isRequesting ?? this.isRequesting,
        error: error,
      );
}

/// Permission request notifier
class PermissionRequestNotifier extends StateNotifier<PermissionRequestState> {
  final PushNotificationService _pushService;

  PermissionRequestNotifier(this._pushService)
      : super(const PermissionRequestState()) {
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final status = await _pushService.checkPermissionStatus();
    state = state.copyWith(status: status);
  }

  /// Request notification permission
  Future<NotificationPermissionState> requestPermission() async {
    state = state.copyWith(isRequesting: true, error: null);

    try {
      final status = await _pushService.requestPermission();
      state = state.copyWith(status: status, isRequesting: false);
      return status;
    } catch (e) {
      state = state.copyWith(
        isRequesting: false,
        error: e.toString(),
      );
      return NotificationPermissionState.denied;
    }
  }

  /// Refresh permission status (after returning from settings)
  Future<void> refreshStatus() async {
    await _checkStatus();
  }
}

/// Permission request notifier provider
///
/// Usage:
/// ```dart
/// final state = ref.watch(permissionRequestNotifierProvider);
///
/// // Request permission
/// final notifier = ref.read(permissionRequestNotifierProvider.notifier);
/// final status = await notifier.requestPermission();
/// ```
final permissionRequestNotifierProvider =
    StateNotifierProvider<PermissionRequestNotifier, PermissionRequestState>(
        (ref) {
  final pushService = ref.watch(pushNotificationServiceProvider);
  return PermissionRequestNotifier(pushService);
});

// ============================================================================
// USE CASE PROVIDERS
// ============================================================================

// TODO: Uncomment when notification_repository is implemented
// /// HandlePushTap use case provider
// ///
// /// Handles push notification taps and converts to navigation actions.
// ///
// /// Usage:
// /// ```dart
// /// final handlePushTap = ref.read(handlePushTapProvider);
// /// final result = await handlePushTap.execute(payload);
// /// if (result.isValid) {
// ///   // Navigate based on result.type
// /// }
// /// ```
// final handlePushTapProvider = Provider<HandlePushTap>((ref) {
//   final repository = ref.watch(notificationRepositoryProvider);
//   return HandlePushTap(repository);
// });
