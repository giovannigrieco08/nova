// =====================================================================
// Nova - Authentication Notifier (Riverpod State Management)
// =====================================================================
// Purpose: Manage authentication state with AsyncNotifier pattern
// Architecture: Riverpod 2.0+ AsyncNotifierProvider
// =====================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:nova/core/models/auth_state.dart';
import 'package:nova/features/auth/data/repositories/auth_repository.dart';

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

  @override
  Future<AuthState> build() async {
    // Get auth repository from provider
    _authRepository = ref.read(authRepositoryProvider);

    // Debug logging
    assert(() {
      debugPrint('🔧 AuthNotifier: Initializing');
      return true;
    }());

    // Listen to Supabase auth state changes
    _setupAuthStateListener();

    // Get initial auth state from current session
    final currentUser = _authRepository.getCurrentUser();

    if (currentUser != null) {
      // Debug logging
      assert(() {
        debugPrint('✅ AuthNotifier: User already authenticated');
        debugPrint('   User ID: ${currentUser.id}');
        debugPrint('   Email: ${currentUser.email}');
        return true;
      }());

      return AuthStateAuthenticated(currentUser);
    } else {
      // Debug logging
      assert(() {
        debugPrint('ℹ️ AuthNotifier: No active session');
        return true;
      }());

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
    _authRepository.streamAuthState().listen((authState) {
      // Debug logging
      assert(() {
        debugPrint('🔔 AuthNotifier: Auth state changed');
        debugPrint('   Event: ${authState.event}');
        return true;
      }());

      switch (authState.event) {
        case supabase.AuthChangeEvent.signedIn:
          // User signed in successfully
          if (authState.session?.user != null) {
            assert(() {
              debugPrint('✅ User signed in: ${authState.session!.user.email}');
              return true;
            }());
            state = AsyncData(AuthStateAuthenticated(authState.session!.user));
          }
          break;

        case supabase.AuthChangeEvent.signedOut:
          // User signed out
          assert(() {
            debugPrint('🚪 User signed out');
            return true;
          }());
          state = const AsyncData(AuthStateUnauthenticated());
          break;

        case supabase.AuthChangeEvent.tokenRefreshed:
          // Token refreshed (silent) - update user object
          if (authState.session?.user != null) {
            assert(() {
              debugPrint('🔄 Token refreshed');
              return true;
            }());
            state = AsyncData(AuthStateAuthenticated(authState.session!.user));
          }
          break;

        case supabase.AuthChangeEvent.userUpdated:
          // User data updated
          if (authState.session?.user != null) {
            assert(() {
              debugPrint('👤 User data updated');
              return true;
            }());
            state = AsyncData(AuthStateAuthenticated(authState.session!.user));
          }
          break;

        default:
          // Other events (passwordRecovery, etc.) - ignore for now
          assert(() {
            debugPrint('ℹ️ Unhandled auth event: ${authState.event}');
            return true;
          }());
      }
    });
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
    // Debug logging
    assert(() {
      debugPrint('📧 AuthNotifier: Sending magic link to $email');
      return true;
    }());

    try {
      // Send magic link via repository
      final result = await _authRepository.sendMagicLink(email);

      // Debug logging
      assert(() {
        debugPrint('✅ AuthNotifier: Magic link sent successfully');
        return true;
      }());

      return result;
    } on supabase.AuthException catch (e) {
      // Debug logging
      assert(() {
        debugPrint('❌ AuthNotifier: Magic link send failed - ${e.message}');
        return true;
      }());

      // Re-throw for LoginScreen to handle
      rethrow;
    } catch (e) {
      // Debug logging
      assert(() {
        debugPrint('❌ AuthNotifier: Unexpected error - $e');
        return true;
      }());

      // Re-throw for LoginScreen to handle
      rethrow;
    }
  }

  /// Verify magic link token from deep link
  ///
  /// Called when user clicks magic link in email.
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
      // Set loading state
      state = const AsyncLoading();

      // Debug logging
      assert(() {
        debugPrint('🔐 AuthNotifier: Verifying magic link');
        return true;
      }());

      // Verify token via repository
      final user = await _authRepository.verifyMagicLink(uri);

      // State will be updated by auth state listener
      // But we can set it immediately for faster UI update
      state = AsyncData(AuthStateAuthenticated(user));

      // Debug logging
      assert(() {
        debugPrint('✅ AuthNotifier: Magic link verified successfully');
        return true;
      }());

      return true;
    } on supabase.AuthException catch (e) {
      // Set error state
      assert(() {
        debugPrint('❌ AuthNotifier: Magic link verification failed - ${e.message}');
        return true;
      }());

      state = AsyncError(e.message, StackTrace.current);
      return false;
    } catch (e, stackTrace) {
      // Set error state for unexpected errors
      assert(() {
        debugPrint('❌ AuthNotifier: Unexpected error - $e');
        return true;
      }());

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

      // Debug logging
      assert(() {
        debugPrint('🚪 AuthNotifier: Signing out');
        return true;
      }());

      // Sign out via repository
      await _authRepository.signOut();

      // State will be updated by auth state listener
      // But we can set it immediately for faster UI update
      state = const AsyncData(AuthStateUnauthenticated());

      // Debug logging
      assert(() {
        debugPrint('✅ AuthNotifier: Signed out successfully');
        return true;
      }());

      return true;
    } on supabase.AuthException catch (e) {
      // Set error state
      assert(() {
        debugPrint('❌ AuthNotifier: Sign out failed - ${e.message}');
        return true;
      }());

      state = AsyncError(e.message, StackTrace.current);
      return false;
    } catch (e, stackTrace) {
      // Set error state for unexpected errors
      assert(() {
        debugPrint('❌ AuthNotifier: Unexpected error - $e');
        return true;
      }());

      state = AsyncError(e, stackTrace);
      return false;
    }
  }
}
