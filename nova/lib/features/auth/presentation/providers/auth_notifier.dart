// =====================================================================
// Nova - Authentication Notifier (Riverpod State Management)
// =====================================================================
// Purpose: Manage authentication state with AsyncNotifier pattern
// Architecture: Riverpod 2.0+ AsyncNotifierProvider
// =====================================================================

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:nova/core/models/auth_state.dart';
import 'package:nova/core/services/push_notification_service.dart';
import 'package:nova/features/auth/data/repositories/auth_repository.dart';
import 'package:nova/features/notifications/domain/entities/notification_permission_state.dart';
import 'package:nova/features/notifications/presentation/providers/push_providers.dart';

// =====================================================================
// Provider: Auth Repository Instance
// =====================================================================

/// Provides singleton instance of AuthRepository
///
/// Usage:
/// ```dart
/// final authRepo = ref.read(authRepositoryProvider);
/// await authRepo.sendMagicLink(email);
/// ```
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// =====================================================================
// Provider: Auth Notifier (Main Authentication State)
// =====================================================================

/// Main authentication state provider
///
/// Provides [AsyncValue<AuthState>] that can be:
/// - AsyncData(AuthStateAuthenticated) - User logged in
/// - AsyncData(AuthStateUnauthenticated) - User logged out
/// - AsyncLoading() - Operation in progress
/// - AsyncError() - Error occurred
///
/// Usage in widgets:
/// ```dart
/// final authState = ref.watch(authNotifierProvider);
///
/// return authState.when(
///   data: (state) => switch (state) {
///     AuthStateAuthenticated(:final user) => MainFeedScreen(),
///     AuthStateUnauthenticated() => LoginScreen(),
///     _ => LoadingScreen(),
///   },
///   loading: () => LoadingScreen(),
///   error: (err, stack) => ErrorScreen(err.toString()),
/// );
/// ```
final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

// =====================================================================
// Notifier: Authentication Logic
// =====================================================================

/// Authentication state notifier using AsyncNotifier pattern
///
/// Responsibilities:
/// - Initialize auth state from current session
/// - Send magic link emails
/// - Verify magic link tokens
/// - Handle sign out
/// - Listen to auth state changes from Supabase
///
/// All state changes are reactive and automatically update UI.
class AuthNotifier extends AsyncNotifier<AuthState> {
  /// Auth repository instance (from provider)
  late final AuthRepository _authRepository;

  /// Push notification service for FCM token management
  late final PushNotificationService _pushService;

  /// Auth state subscription (stored for cleanup)
  StreamSubscription<supabase.AuthState>? _authSubscription;

  @override
  Future<AuthState> build() async {
    // Get auth repository from provider
    _authRepository = ref.read(authRepositoryProvider);

    // Get push notification service from provider
    _pushService = ref.read(pushNotificationServiceProvider);

    // Listen to Supabase auth state changes
    _setupAuthStateListener();

    // Register cleanup callback for when provider is disposed
    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    // Get initial auth state from current session
    final currentUser = _authRepository.getCurrentUser();

    if (currentUser != null) {
      return AuthStateAuthenticated(currentUser);
    } else {
      return const AuthStateUnauthenticated();
    }
  }

  /// Setup listener for Supabase auth state changes
  ///
  /// Automatically updates state when:
  /// - User signs in (magic link verified)
  /// - User signs out
  /// - Session expires
  /// - Token refreshes (silent)
  void _setupAuthStateListener() {
    _authSubscription = _authRepository.streamAuthState().listen(
      (authState) {
        switch (authState.event) {
          case supabase.AuthChangeEvent.signedIn:
            // User signed in successfully
            if (authState.session?.user != null) {
              state =
                  AsyncData(AuthStateAuthenticated(authState.session!.user));

              // Register FCM token for push notifications
              _registerFcmTokenAfterLogin();
            }
            break;

          case supabase.AuthChangeEvent.signedOut:
            // User signed out
            state = const AsyncData(AuthStateUnauthenticated());
            break;

          case supabase.AuthChangeEvent.tokenRefreshed:
            // Token refreshed (silent) - update user object
            if (authState.session?.user != null) {
              state =
                  AsyncData(AuthStateAuthenticated(authState.session!.user));
            }
            break;

          case supabase.AuthChangeEvent.userUpdated:
            // User data updated
            if (authState.session?.user != null) {
              state =
                  AsyncData(AuthStateAuthenticated(authState.session!.user));
            }
            break;

          default:
            // Other events (passwordRecovery, etc.) - ignore for now
            break;
        }
      },
      onError: (error) {
        // Handle stream errors - logged silently
      },
    );
  }

  /// Send magic link to email address
  ///
  /// Does NOT change global auth state - loading is handled locally in LoginScreen.
  /// Throws exceptions on failure for the caller to handle.
  ///
  /// Parameters:
  /// - [email]: User's email address
  ///
  /// Returns:
  /// - `true` if magic link sent successfully
  ///
  /// Throws:
  /// - [AuthException] if Supabase auth error
  /// - [Exception] for other errors
  ///
  /// Usage:
  /// ```dart
  /// try {
  ///   final success = await ref.read(authNotifierProvider.notifier).sendMagicLink(email);
  ///   if (success) {
  ///     // Show success UI (handled locally in LoginScreen)
  ///   }
  /// } catch (e) {
  ///   // Show error message
  /// }
  /// ```
  Future<bool> sendMagicLink(String email) async {
    try {
      // Send magic link via repository
      final result = await _authRepository.sendMagicLink(email);

      return result;
    } on supabase.AuthException {
      // Re-throw for LoginScreen to handle
      rethrow;
    } catch (e) {
      // Re-throw for LoginScreen to handle
      rethrow;
    }
  }

  /// Verify magic link token from deep link
  ///
  /// Called when user clicks magic link in email.
  /// With PKCE flow, Supabase may have already created the session
  /// during the redirect, so this method handles multiple scenarios.
  ///
  /// Parameters:
  /// - [uri]: Deep link URI with token
  ///
  /// Returns:
  /// - `true` if verification successful (state will auto-update via listener)
  /// - `false` if verification failed
  ///
  /// Usage:
  /// ```dart
  /// final success = await ref.read(authNotifierProvider.notifier).verifyMagicLink(uri);
  /// if (success) {
  ///   // Navigate to main feed (or wait for state change)
  /// }
  /// ```
  Future<bool> verifyMagicLink(Uri uri) async {
    try {
      // Check if already authenticated (Supabase may have already verified
      // the token server-side during the redirect, creating a session before
      // the app receives the deep link callback)
      final existingUser = _authRepository.getCurrentUser();
      if (existingUser != null) {
        // Session already exists - Supabase verified token during redirect
        // Update state immediately and register FCM token
        state = AsyncData(AuthStateAuthenticated(existingUser));
        _registerFcmTokenAfterLogin();
        return true;
      }

      // Set loading state
      state = const AsyncLoading();

      // Verify token via repository - this handles multiple scenarios:
      // 1. Session exists (PKCE completed server-side)
      // 2. token_hash in URL (traditional OTP)
      // 3. access_token/refresh_token in URL
      final user = await _authRepository.verifyMagicLink(uri);

      // State will be updated by auth state listener
      // But we can set it immediately for faster UI update
      state = AsyncData(AuthStateAuthenticated(user));

      // Note: FCM registration will be triggered by auth state listener
      // when it receives the signedIn event

      return true;
    } on supabase.AuthException catch (e) {
      // Check if user got authenticated despite the error
      // (can happen if token was already verified server-side)
      final currentUser = _authRepository.getCurrentUser();
      if (currentUser != null) {
        state = AsyncData(AuthStateAuthenticated(currentUser));
        _registerFcmTokenAfterLogin();
        return true;
      }

      // Set error state
      state = AsyncError(e.message, StackTrace.current);
      return false;
    } catch (e, stackTrace) {
      // Check if user got authenticated despite the error
      final currentUser = _authRepository.getCurrentUser();
      if (currentUser != null) {
        state = AsyncData(AuthStateAuthenticated(currentUser));
        _registerFcmTokenAfterLogin();
        return true;
      }

      // Set error state for unexpected errors
      state = AsyncError(e, stackTrace);
      return false;
    }
  }

  /// Sign out current user
  ///
  /// Revokes session and updates state to unauthenticated.
  ///
  /// Returns:
  /// - `true` if sign out successful
  /// - `false` if error occurred
  ///
  /// Usage:
  /// ```dart
  /// await ref.read(authNotifierProvider.notifier).signOut();
  /// // Navigate to login screen
  /// ```
  Future<bool> signOut() async {
    try {
      // Set loading state
      state = const AsyncLoading();

      // Remove FCM token before signing out (to stop push notifications)
      await _removeFcmTokenBeforeLogout();

      // Sign out via repository
      await _authRepository.signOut();

      // State will be updated by auth state listener
      // But we can set it immediately for faster UI update
      state = const AsyncData(AuthStateUnauthenticated());

      return true;
    } on supabase.AuthException catch (e) {
      // Set error state
      state = AsyncError(e.message, StackTrace.current);
      return false;
    } catch (e, stackTrace) {
      // Set error state for unexpected errors
      state = AsyncError(e, stackTrace);
      return false;
    }
  }

  // ===========================================================================
  // Push Notification Token Management
  // ===========================================================================

  /// Register FCM token after successful login
  ///
  /// Called automatically when user signs in.
  /// Requests notification permission if not already granted.
  void _registerFcmTokenAfterLogin() {
    // Run async without awaiting (fire-and-forget)
    // This prevents blocking the auth flow
    Future(() async {
      try {
        // Initialize push notifications service
        await _pushService.initialize();

        // Request permission and register token
        final permission = await _pushService.requestPermission();
        if (permission == NotificationPermissionState.granted) {
          await _pushService.registerToken();
        }
      } catch (e) {
        // Silently fail - don't block auth flow for push notification issues
      }
    });
  }

  /// Remove FCM token before logout
  ///
  /// Called before sign out to stop push notifications.
  Future<void> _removeFcmTokenBeforeLogout() async {
    try {
      // Remove token from Supabase
      await _pushService.removeToken();
    } catch (e) {
      // Silently fail - don't block logout flow for push notification issues
    }
  }
}
