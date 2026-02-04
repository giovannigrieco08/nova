// Provider: ConnectivityProvider
// Feature: 002-profile-setup
// Purpose: Network status monitoring for offline-first functionality

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stream provider that monitors network connectivity status
///
/// Returns ConnectivityResult which can be:
/// - ConnectivityResult.wifi: Connected via WiFi
/// - ConnectivityResult.mobile: Connected via mobile data
/// - ConnectivityResult.none: No network connection
///
/// Usage in widgets:
/// ```dart
/// final connectivity = ref.watch(connectivityProvider);
///
/// connectivity.when(
///   data: (result) {
///     if (result == ConnectivityResult.none) {
///       return Text('Offline mode');
///     }
///     return Text('Online');
///   },
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => Text('Error checking connectivity'),
/// );
/// ```
final connectivityProvider = StreamProvider<ConnectivityResult>((ref) {
  return Connectivity().onConnectivityChanged;
});

/// Helper provider to check if device is online
///
/// Returns true if connected to WiFi or mobile data
/// Returns false if no connection
///
/// Usage:
/// ```dart
/// final isOnline = ref.watch(isOnlineProvider);
///
/// isOnline.when(
///   data: (online) => Text(online ? 'Online' : 'Offline'),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => Text('Error'),
/// );
/// ```
final isOnlineProvider = Provider<AsyncValue<bool>>((ref) {
  final connectivity = ref.watch(connectivityProvider);

  return connectivity.when(
    data: (result) => AsyncValue.data(result != ConnectivityResult.none),
    loading: () => const AsyncValue.loading(),
    error: (err, stack) => AsyncValue.error(err, stack),
  );
});

/// One-time connectivity check provider
///
/// Unlike the stream provider above, this performs a single check
/// Useful for initial state or one-off checks
///
/// Usage:
/// ```dart
/// final initialConnectivity = await ref.read(checkConnectivityProvider.future);
/// ```
final checkConnectivityProvider = FutureProvider<ConnectivityResult>((ref) {
  return Connectivity().checkConnectivity();
});

/// Connectivity notifier for manual refresh
///
/// Allows manual connectivity checks and provides current state
class ConnectivityNotifier
    extends StateNotifier<AsyncValue<ConnectivityResult>> {
  final Connectivity _connectivity;

  ConnectivityNotifier(this._connectivity) : super(const AsyncValue.loading()) {
    _checkConnectivity();
  }

  /// Check connectivity status
  Future<void> _checkConnectivity() async {
    state = const AsyncValue.loading();

    try {
      final result = await _connectivity.checkConnectivity();
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Manually refresh connectivity status
  Future<void> refresh() async {
    await _checkConnectivity();
  }

  /// Check if currently online
  bool get isOnline {
    return state.when(
      data: (result) => result != ConnectivityResult.none,
      loading: () => false,
      error: (_, __) => false,
    );
  }
}

/// Provider for manual connectivity checks with refresh capability
final connectivityNotifierProvider =
    StateNotifierProvider<ConnectivityNotifier, AsyncValue<ConnectivityResult>>(
  (ref) => ConnectivityNotifier(Connectivity()),
);
