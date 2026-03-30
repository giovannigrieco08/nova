// =====================================================================
// Nova - Authentication Notifier (Riverpod State Management)
// =====================================================================
// Purpose: Manage authentication state with AsyncNotifier pattern
// Architecture: Riverpod 2.0+ AsyncNotifierProvider
// =====================================================================

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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
      // Apple Guideline 5.1.1: Start in guest mode, not login screen
      // Users can browse events without logging in
      return const AuthStateGuest();
    }
  }

  /// Track last authenticated user ID to deduplicate events
  String? _lastAuthenticatedUserId;

  /// Track user ID being replaced during magic link switch
  /// Events from this user should be IGNORED during transition
  String? _userIdBeingReplaced;

  /// Track processed magic link codes to avoid duplicate processing
  /// This prevents issues when both Universal Links and custom scheme deliver the same code
  final Set<String> _processedCodes = {};

  /// Check if already authenticated with same user
  bool _isAlreadyAuthenticated(String? userId) {
    final currentState = state.valueOrNull;
    if (currentState is AuthStateAuthenticated && userId != null) {
      return currentState.user.id == userId;
    }
    return false;
  }

  /// Safely update state, catching defunct widget errors
  /// This can happen when widgets are disposed during state transitions
  void _safeSetState(AsyncValue<AuthState> newState) {
    try {
      state = newState;
    } catch (e) {
      // Ignore defunct widget errors - the state update will be picked up
      // by any active widgets on their next build
      debugPrint(
          '🔐 [AUTH] State update caught error (likely defunct widget): $e');
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
    debugPrint('🔐 [AUTH_LISTENER] Setting up auth state listener...');
    _authSubscription = _authRepository.streamAuthState().listen(
      (authState) {
        debugPrint('🔐 [AUTH_LISTENER] Event received: ${authState.event}');
        debugPrint('🔐 [AUTH_LISTENER] User: ${authState.session?.user?.id}');

        switch (authState.event) {
          case supabase.AuthChangeEvent.signedIn:
            // User signed in successfully
            debugPrint('🔐 [AUTH_LISTENER] SignedIn event!');
            final user = authState.session?.user;
            if (user != null) {
              // CRITICAL: Skip if this is the OLD user being replaced
              // This prevents race conditions during account switching
              if (_userIdBeingReplaced != null && user.id == _userIdBeingReplaced) {
                debugPrint(
                    '🔐 [AUTH_LISTENER] IGNORING signedIn for user being replaced: ${user.id}');
                return;
              }

              // DEDUPLICATE: Skip if already authenticated with same user
              if (_lastAuthenticatedUserId == user.id) {
                debugPrint(
                    '🔐 [AUTH_LISTENER] Skipping duplicate signedIn event');
                return;
              }

              // Use _forceAuthStateUpdate for synchronous state update
              // This ensures Riverpod listeners are notified immediately
              debugPrint('🔐 [AUTH_LISTENER] Calling _forceAuthStateUpdate...');
              _forceAuthStateUpdate(user);
            }
            break;

          case supabase.AuthChangeEvent.signedOut:
            // User signed out - return to guest mode (Instagram-style)
            debugPrint('🔐 [AUTH_LISTENER] SignedOut event!');
            _lastAuthenticatedUserId = null;
            // Update state synchronously - go to Guest, not Unauthenticated
            final currentState = state.valueOrNull;
            if (currentState is! AuthStateGuest) {
              debugPrint('🔐 [AUTH_LISTENER] Setting state to Guest...');
              try {
                state = const AsyncData(AuthStateGuest());
                debugPrint('🔐 [AUTH_LISTENER] State set to Guest');
              } catch (e) {
                debugPrint('🔐 [AUTH_LISTENER] State update error: $e');
              }
            }
            break;

          case supabase.AuthChangeEvent.tokenRefreshed:
            // Token refreshed (silent) - no need to update UI state
            debugPrint('🔐 [AUTH_LISTENER] TokenRefreshed event (ignored)');
            break;

          case supabase.AuthChangeEvent.userUpdated:
            // User data updated - only update if user object actually changed
            debugPrint('🔐 [AUTH_LISTENER] UserUpdated event');
            final user = authState.session?.user;
            if (user != null) {
              final currentState = state.valueOrNull;
              if (currentState is AuthStateAuthenticated) {
                // Only update if user data actually changed
                if (currentState.user.id == user.id) {
                  try {
                    state = AsyncData(AuthStateAuthenticated(user));
                    debugPrint('🔐 [AUTH_LISTENER] User data updated');
                  } catch (e) {
                    debugPrint('🔐 [AUTH_LISTENER] User update error: $e');
                  }
                }
              }
            }
            break;

          default:
            // Other events (passwordRecovery, etc.) - ignore for now
            debugPrint(
                '🔐 [AUTH_LISTENER] Unhandled event: ${authState.event}');
            break;
        }
      },
      onError: (error) {
        // Handle stream errors - logged
        debugPrint('🔐 [AUTH_LISTENER] Stream error: $error');
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
  /// Flag to prevent _checkAuthStateOnResume from interfering during magic link processing
  bool _isProcessingMagicLink = false;

  /// Check if currently processing a magic link (used by main.dart)
  bool get isProcessingMagicLink => _isProcessingMagicLink;

  Future<bool> verifyMagicLink(Uri uri) async {
    // Note: Don't log full URI as it may contain sensitive tokens
    debugPrint('🔐 [AUTH] verifyMagicLink called for path: ${uri.path}');

    // Skip dummy resume URIs - these are from _checkAuthStateOnResume
    // and should not interfere with actual magic link processing
    if (uri.path == '/resume' || uri.toString() == 'novaapp://auth/resume') {
      debugPrint('🔐 [AUTH] Skipping resume URI, checking current user...');
      final currentUser = _authRepository.getCurrentUser();
      if (currentUser != null) {
        _forceAuthStateUpdate(currentUser);
        return true;
      }
      return false;
    }

    // CRITICAL: Check if this code was already processed
    // This happens when both Universal Links and custom scheme deliver the same magic link
    final code = uri.queryParameters['code'];
    if (code != null && _processedCodes.contains(code)) {
      debugPrint('🔐 [AUTH] Code already processed, skipping duplicate: ${code.substring(0, 8)}...');
      // Check current auth state - if authenticated, return success
      final currentUser = _authRepository.getCurrentUser();
      if (currentUser != null) {
        return true;
      }
      return false;
    }

    // Mark code as being processed
    if (code != null) {
      _processedCodes.add(code);
      // Clean up old codes (keep last 5)
      while (_processedCodes.length > 5) {
        _processedCodes.remove(_processedCodes.first);
      }
    }

    // CRITICAL: Set flag to prevent resume check from interfering
    _isProcessingMagicLink = true;

    try {
      // STEP 1: Reset internal state to ensure clean slate
      debugPrint('🔐 [AUTH] Step 1: Resetting internal state...');
      _lastAuthenticatedUserId = null;

      // STEP 2: Sign out any existing user BEFORE processing magic link
      // This is critical to ensure the new magic link is for the correct user
      final existingUser = _authRepository.getCurrentUser();
      if (existingUser != null) {
        // CRITICAL: Track the user being replaced to ignore their events
        _userIdBeingReplaced = existingUser.id;
        debugPrint('🔐 [AUTH] Step 2: Marking user ${existingUser.id} as being replaced...');
        debugPrint('🔐 [AUTH] Step 2: Signing out existing user ${existingUser.id}...');
        try {
          await _authRepository.signOut();
          // Wait for signOut to fully complete
          await Future.delayed(const Duration(milliseconds: 200));
        } catch (e) {
          debugPrint('🔐 [AUTH] SignOut error (continuing anyway): $e');
        }
      }

      // STEP 3: Verify the magic link via repository
      debugPrint('🔐 [AUTH] Step 3: Calling repository.verifyMagicLink...');
      final user = await _authRepository.verifyMagicLink(uri);
      debugPrint('🔐 [AUTH] Repository returned user: ${user.id}, email: ${user.email}');

      // STEP 4: Force update state with the NEW user
      debugPrint('🔐 [AUTH] Step 4: Force updating state with new user...');
      _forceAuthStateUpdate(user);

      return true;
    } on supabase.AuthException catch (e) {
      debugPrint('🔐 [AUTH] AuthException: ${e.message}');
      // Check if user got authenticated despite the error
      final currentUser = _authRepository.getCurrentUser();
      if (currentUser != null) {
        // CRITICAL: Don't accept the old user
        if (_userIdBeingReplaced != null && currentUser.id == _userIdBeingReplaced) {
          debugPrint('🔐 [AUTH] Rejecting old user after error');
          return false;
        }
        debugPrint('🔐 [AUTH] User authenticated despite error: ${currentUser.email}');
        _forceAuthStateUpdate(currentUser);
        return true;
      }
      debugPrint('🔐 [AUTH] Verification failed');
      return false;
    } catch (e, stackTrace) {
      debugPrint('🔐 [AUTH] Unexpected error: $e');
      final currentUser = _authRepository.getCurrentUser();
      if (currentUser != null) {
        // CRITICAL: Don't accept the old user
        if (_userIdBeingReplaced != null && currentUser.id == _userIdBeingReplaced) {
          debugPrint('🔐 [AUTH] Rejecting old user after error');
          return false;
        }
        debugPrint('🔐 [AUTH] User authenticated despite error: ${currentUser.email}');
        _forceAuthStateUpdate(currentUser);
        return true;
      }
      debugPrint('🔐 [AUTH] Verification failed: $e');
      return false;
    } finally {
      // Always reset the flags
      _isProcessingMagicLink = false;
      _userIdBeingReplaced = null;
    }
  }

  /// Force auth state update to Authenticated
  ///
  /// This is called when we detect the user is authenticated but the
  /// Riverpod state hasn't been updated yet (e.g., after PKCE redirect).
  void _forceAuthStateUpdate(supabase.User user) {
    debugPrint('🔐 [AUTH] _forceAuthStateUpdate called for user: ${user.id}, email: ${user.email}');

    // CRITICAL: Reject updates for the user being replaced
    if (_userIdBeingReplaced != null && user.id == _userIdBeingReplaced) {
      debugPrint('🔐 [AUTH] REJECTING update for user being replaced: ${user.id}');
      return;
    }

    // Check if already authenticated with same user
    if (_lastAuthenticatedUserId == user.id) {
      debugPrint(
          '🔐 [AUTH] Already authenticated with same user, checking state...');
      final currentState = state.valueOrNull;
      if (currentState is AuthStateAuthenticated) {
        debugPrint('🔐 [AUTH] State already correct, skipping update');
        return;
      }
    }

    _lastAuthenticatedUserId = user.id;

    // Update state synchronously - this MUST trigger Riverpod listeners
    final newState = AsyncData(AuthStateAuthenticated(user));
    debugPrint('🔐 [AUTH] Setting state to: $newState');

    try {
      // Direct state assignment triggers Riverpod notifications
      state = newState;
      debugPrint(
          '🔐 [AUTH] State set successfully! Riverpod should notify listeners now.');
    } catch (e) {
      debugPrint('🔐 [AUTH] State set error: $e');
      // This error might happen if the notifier is in a weird state
      // Try using a microtask to update in the next event loop iteration
      Future.microtask(() {
        try {
          state = newState;
          debugPrint('🔐 [AUTH] Microtask state set successful');
        } catch (e2) {
          debugPrint('🔐 [AUTH] Microtask state set also failed: $e2');
        }
      });
    }

    // Verify state was updated
    final currentState = state.valueOrNull;
    debugPrint('🔐 [AUTH] Current state after update: $currentState');
    debugPrint(
        '🔐 [AUTH] Is authenticated: ${currentState is AuthStateAuthenticated}');

    // Register FCM token
    _registerFcmTokenAfterLogin();
  }

  // ===========================================================================
  // Guest Mode (Apple Guideline 5.1.1 Compliance)
  // ===========================================================================

  /// Enter guest mode - show login screen
  ///
  /// Called when guest user wants to sign in (e.g., taps "Accedi" button).
  /// Transitions from Guest state to Unauthenticated state to show login.
  void showLogin() {
    debugPrint('🔐 [AUTH] Showing login screen...');
    state = const AsyncData(AuthStateUnauthenticated());
  }

  /// Return to guest mode from login screen
  ///
  /// Called when user cancels login and wants to continue browsing.
  void returnToGuest() {
    debugPrint('🔐 [AUTH] Returning to guest mode...');
    state = const AsyncData(AuthStateGuest());
  }

  /// Sign out and return to guest mode (not login screen)
  ///
  /// Instagram-style: after logout, user can still browse.
  Future<bool> signOutToGuest() async {
    try {
      state = const AsyncLoading();
      await _removeFcmTokenBeforeLogout();
      await _authRepository.signOut();
      _lastAuthenticatedUserId = null;
      state = const AsyncData(AuthStateGuest());
      return true;
    } catch (e) {
      state = const AsyncData(AuthStateGuest());
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
