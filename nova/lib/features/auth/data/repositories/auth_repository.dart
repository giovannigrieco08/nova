// =====================================================================
// Nova - Authentication Repository
// =====================================================================
// Purpose: Handle all authentication operations with Supabase
// Architecture: Repository pattern with Supabase Auth API
// =====================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/core/config/supabase_config.dart';
import 'package:nova/core/exceptions/nova_exceptions.dart';
import 'package:nova/core/utils/email_validator.dart';

/// Authentication repository for managing user authentication
///
/// Handles:
/// - Magic link email sending
/// - Magic link token verification
/// - Sign out
/// - Current user access
/// - Auth state changes stream
///
/// All methods include error handling and logging.
class AuthRepository {
  /// Supabase client instance
  final SupabaseClient _supabase;

  /// Constructor with dependency injection
  ///
  /// Defaults to SupabaseConfig.client if not provided
  AuthRepository({SupabaseClient? supabase})
      : _supabase = supabase ?? SupabaseConfig.client;

  /// Send magic link to email address
  ///
  /// Validates email format, checks rate limits (enforced server-side),
  /// and sends OTP magic link via Supabase Auth.
  ///
  /// Parameters:
  /// - [email]: User's email address
  ///
  /// Returns:
  /// - `true` if magic link sent successfully
  /// - `false` if validation failed or error occurred
  ///
  /// Throws:
  /// - [AuthException] with user-friendly message on failure
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   await authRepo.sendMagicLink('student@galileimoro.edu.it');
  ///   // Show success message
  /// } on AuthException catch (e) {
  ///   // Show error: e.message
  /// }
  /// ```
  Future<bool> sendMagicLink(String email) async {
    try {
      // Validate email format (client-side)
      final validationError = EmailValidator.validate(email);
      if (validationError != null) {
        throw AuthException(validationError);
      }

      // Normalize email (trim and lowercase)
      final normalizedEmail = EmailValidator.normalize(email);

      // Send magic link via Supabase Auth
      // Note: Rate limiting (3 per 15 min) is enforced server-side
      // Use HTTPS URL for Universal Links support on iOS (iPad compatibility)
      // The web page at nova-app.shop/auth/callback redirects to the app
      await _supabase.auth.signInWithOtp(
        email: normalizedEmail,
        emailRedirectTo: 'https://nova-app.shop/auth/callback',
      );

      return true;
    } on AuthException catch (e) {
      // Re-throw with user-friendly message
      throw _handleAuthException(e);
    } catch (e) {
      // Wrap unexpected errors
      throw AuthException('Failed to send magic link. Please try again.');
    }
  }

  /// Verify magic link token from deep link
  ///
  /// With PKCE flow, Supabase handles token exchange automatically during redirect.
  /// This method checks for an existing session or extracts it from the URL.
  ///
  /// Parameters:
  /// - [uri]: Deep link URI (e.g., novaapp://auth/callback?...)
  ///
  /// Returns:
  /// - [User] object if verification successful
  ///
  /// Throws:
  /// - [AuthException] if token invalid, expired, or already used
  ///
  /// Example:
  /// ```dart
  /// try {
  ///   final user = await authRepo.verifyMagicLink(deepLinkUri);
  ///   // Navigate to main feed
  /// } on AuthException catch (e) {
  ///   // Show error: e.message
  /// }
  /// ```
  Future<User> verifyMagicLink(Uri uri) async {
    try {
      // Always sign out existing session when processing a new magic link.
      // This ensures the new magic link is processed correctly, even if
      // it's for a different user than the currently logged in one.
      // Use SignOutScope.local to ensure complete local session cleanup.
      var existingUser = _supabase.auth.currentUser;
      if (existingUser != null) {
        debugPrint('🔐 [AUTH_REPO] Signing out existing user ${existingUser.id} before magic link verification');
        await _supabase.auth.signOut(scope: SignOutScope.local);
        debugPrint('🔐 [AUTH_REPO] Sign out complete, currentUser is now: ${_supabase.auth.currentUser?.id}');
      }

      // For HTTPS URLs from Supabase email, use getSessionFromUrl
      // This handles the token parameter automatically
      if (uri.scheme == 'https' && uri.host.contains('supabase.co')) {
        final response = await _supabase.auth.getSessionFromUrl(uri);
        return response.session.user;
      }

      // For custom scheme URLs (novaapp://), extract parameters
      final code = uri.queryParameters['code'];
      final tokenHash = uri.queryParameters['token_hash'];
      final type = uri.queryParameters['type'];
      final email = uri.queryParameters['email'];
      final accessToken = uri.queryParameters['access_token'];
      final refreshToken = uri.queryParameters['refresh_token'];

      // PKCE flow: If we have a 'code' parameter, use exchangeCodeForSession
      // to explicitly exchange the authorization code for a session.
      if (code != null && code.isNotEmpty) {
        debugPrint('🔐 [AUTH_REPO] PKCE code detected: $code');

        try {
          // Exchange the authorization code for a session
          debugPrint('🔐 [AUTH_REPO] Calling exchangeCodeForSession...');
          final response = await _supabase.auth.exchangeCodeForSession(code);
          debugPrint('🔐 [AUTH_REPO] exchangeCodeForSession succeeded!');
          debugPrint('🔐 [AUTH_REPO] New user: ${response.session.user.id}, email: ${response.session.user.email}');

          // exchangeCodeForSession returns AuthSessionUrlResponse with session
          return response.session.user;
        } catch (e) {
          debugPrint('🔐 [AUTH_REPO] exchangeCodeForSession error: $e');

          // The SDK might have already processed it, check for existing session
          // BUT only if the user is DIFFERENT from the one we just signed out
          await Future.delayed(const Duration(milliseconds: 500));
          final newUser = _supabase.auth.currentUser;

          // CRITICAL: Only accept the new user if it's DIFFERENT from the old one
          // If oldUserId is stored in existingUser.id, we compare
          if (newUser != null) {
            // existingUser was set BEFORE sign out, so we can compare
            final oldUserId = existingUser?.id;
            if (oldUserId == null || newUser.id != oldUserId) {
              debugPrint('🔐 [AUTH_REPO] New session found: ${newUser.id}, email: ${newUser.email}');
              return newUser;
            } else {
              debugPrint('🔐 [AUTH_REPO] WARNING: Session is still old user, rejecting');
            }
          }

          // If still no valid session, wait a bit more and check again
          await Future.delayed(const Duration(milliseconds: 1000));
          final finalUser = _supabase.auth.currentUser;
          if (finalUser != null) {
            final oldUserId = existingUser?.id;
            if (oldUserId == null || finalUser.id != oldUserId) {
              debugPrint('🔐 [AUTH_REPO] Session found after second delay: ${finalUser.id}');
              return finalUser;
            } else {
              debugPrint('🔐 [AUTH_REPO] WARNING: Session is STILL old user after delay, rejecting');
            }
          }

          // No valid session found, throw error
          throw AuthException(
              'Magic link verification failed. Please try again.');
        }
      }

      // If we have access_token and refresh_token, set session directly
      // This handles the case where Supabase includes tokens in the callback
      if (accessToken != null && accessToken.isNotEmpty) {
        final response = await _supabase.auth.setSession(refreshToken ?? '');
        if (response.user != null) {
          return response.user!;
        }
      }

      // If we have token_hash, use verifyOTP
      if (tokenHash != null && tokenHash.isNotEmpty) {
        // For verifyOTP, we need email
        if (email == null || email.isEmpty) {
          throw AuthException('Invalid magic link (missing email)');
        }

        // Verify token with Supabase
        final response = await _supabase.auth.verifyOTP(
          tokenHash: tokenHash,
          type: type == 'signup' ? OtpType.signup : OtpType.magiclink,
          email: email,
        );

        // Check if user is authenticated
        if (response.user == null) {
          throw AuthException('Magic link verification failed');
        }

        return response.user!;
      }

      // If no tokens or hash, try to refresh session
      // This handles the case where PKCE flow completed server-side
      try {
        final response = await _supabase.auth.refreshSession();
        if (response.user != null) {
          return response.user!;
        }
      } catch (_) {
        // No valid session to refresh
      }

      // No valid authentication method found
      throw AuthException('Invalid magic link. Please request a new one.');
    } on AuthException catch (e) {
      // Re-throw with user-friendly message
      throw _handleAuthException(e);
    } catch (e) {
      // Wrap unexpected errors
      throw AuthException('Failed to verify magic link. Please try again.');
    }
  }

  /// Sign out current user
  ///
  /// Revokes session and clears local storage.
  ///
  /// Returns:
  /// - `true` if sign out successful
  ///
  /// Throws:
  /// - [AuthException] on failure
  ///
  /// Example:
  /// ```dart
  /// await authRepo.signOut();
  /// // Navigate to login screen
  /// ```
  Future<bool> signOut() async {
    try {
      await _supabase.auth.signOut();

      return true;
    } on AuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AuthException('Failed to sign out. Please try again.');
    }
  }

  /// Get current authenticated user (if any)
  ///
  /// Returns:
  /// - [User] object if authenticated
  /// - `null` if not authenticated
  ///
  /// Example:
  /// ```dart
  /// final user = authRepo.getCurrentUser();
  /// if (user != null) {
  ///   print('Logged in as ${user.email}');
  /// }
  /// ```
  User? getCurrentUser() {
    return _supabase.auth.currentUser;
  }

  /// Stream of authentication state changes
  ///
  /// Emits [AuthChangeEvent] whenever:
  /// - User signs in
  /// - User signs out
  /// - Session expires
  /// - Token refreshes
  ///
  /// Returns:
  /// - Stream of [AuthState] events
  ///
  /// Example:
  /// ```dart
  /// authRepo.streamAuthState().listen((event) {
  ///   switch (event.event) {
  ///     case AuthChangeEvent.signedIn:
  ///       // User logged in
  ///     case AuthChangeEvent.signedOut:
  ///       // User logged out
  ///     case AuthChangeEvent.tokenRefreshed:
  ///       // Token refreshed (silent)
  ///   }
  /// });
  /// ```
  Stream<AuthState> streamAuthState() {
    return _supabase.auth.onAuthStateChange;
  }

  /// Handle AuthException and return user-friendly message
  ///
  /// Maps common Supabase auth errors to readable messages.
  /// Throws [RateLimitException] for rate limit errors (with retryAfter duration).
  /// Throws [AuthException] for other auth errors.
  Exception _handleAuthException(AuthException e) {
    // Map common errors to user-friendly messages
    final message = e.message.toLowerCase();

    if (message.contains('rate limit')) {
      throw RateLimitException(
        'Troppi tentativi. Attendi 15 minuti prima di riprovare.',
        retryAfter: const Duration(minutes: 15),
        technicalMessage: e.message,
      );
    }

    if (message.contains('invalid') || message.contains('expired')) {
      return AuthException(
        'This magic link has expired or is invalid. Please request a new one.',
      );
    }

    if (message.contains('not authorized')) {
      return AuthException(
        'Email not authorized. Please try again.',
      );
    }

    if (message.contains('network') || message.contains('connection')) {
      return AuthException(
        'Network error. Please check your internet connection.',
      );
    }

    // Return original message if no specific match
    return e;
  }
}
