// =====================================================================
// Nova - Authentication Repository
// =====================================================================
// Purpose: Handle all authentication operations with Supabase
// Architecture: Repository pattern with Supabase Auth API
// =====================================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nova/core/config/supabase_config.dart';
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
  /// - [email]: User's email address (@galileimoro.edu.it)
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

      // Debug logging
      assert(() {
        debugPrint('📧 Sending magic link to: $normalizedEmail');
        return true;
      }());

      // Send magic link via Supabase Auth
      // Note: Rate limiting (3 per 15 min) is enforced server-side
      // Use custom URL scheme (novaapp://) for direct app opening
      // This bypasses the need for assetlinks.json and works immediately
      await _supabase.auth.signInWithOtp(
        email: normalizedEmail,
        emailRedirectTo: 'novaapp://auth/callback',
      );

      // Debug logging
      assert(() {
        debugPrint('✅ Magic link sent successfully');
        return true;
      }());

      return true;
    } on AuthException catch (e) {
      // Debug logging
      assert(() {
        debugPrint('❌ Magic link send failed: ${e.message}');
        return true;
      }());

      // Re-throw with user-friendly message
      throw _handleAuthException(e);
    } catch (e) {
      // Debug logging
      assert(() {
        debugPrint('❌ Unexpected error sending magic link: $e');
        return true;
      }());

      // Wrap unexpected errors
      throw AuthException('Failed to send magic link. Please try again.');
    }
  }

  /// Verify magic link token from deep link
  ///
  /// Extracts token from deep link URL and verifies with Supabase.
  ///
  /// Parameters:
  /// - [uri]: Deep link URI (e.g., novaapp://auth/callback?token=...&type=magiclink)
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
      // Debug logging
      assert(() {
        debugPrint('🔐 Verifying magic link token');
        debugPrint('   URI: $uri');
        return true;
      }());

      // For HTTPS URLs from Supabase email, use getSessionFromUrl
      // This handles the token parameter automatically
      if (uri.scheme == 'https' && uri.host.contains('supabase.co')) {
        final response = await _supabase.auth.getSessionFromUrl(uri);

        if (response.session?.user == null) {
          throw AuthException('Magic link verification failed');
        }

        // Debug logging
        assert(() {
          debugPrint('✅ Magic link verified successfully (HTTPS)');
          debugPrint('   User ID: ${response.session!.user.id}');
          debugPrint('   Email: ${response.session!.user.email}');
          return true;
        }());

        return response.session!.user;
      }

      // For custom scheme URLs (novaapp://), use verifyOTP
      final tokenHash = uri.queryParameters['token_hash'];
      final type = uri.queryParameters['type'];
      final email = uri.queryParameters['email'];

      // Validate required parameters
      if (tokenHash == null || tokenHash.isEmpty) {
        throw AuthException('Invalid magic link (missing token)');
      }

      if (type != 'magiclink') {
        throw AuthException('Invalid magic link type');
      }

      if (email == null || email.isEmpty) {
        throw AuthException('Invalid magic link (missing email)');
      }

      // Verify token with Supabase
      // Both tokenHash and email are required by Supabase verifyOTP API
      final response = await _supabase.auth.verifyOTP(
        tokenHash: tokenHash,
        type: OtpType.magiclink,
        email: email,
      );

      // Check if user is authenticated
      if (response.user == null) {
        throw AuthException('Magic link verification failed');
      }

      // Debug logging
      assert(() {
        debugPrint('✅ Magic link verified successfully (custom scheme)');
        debugPrint('   User ID: ${response.user!.id}');
        debugPrint('   Email: ${response.user!.email}');
        return true;
      }());

      return response.user!;
    } on AuthException catch (e) {
      // Debug logging
      assert(() {
        debugPrint('❌ Magic link verification failed: ${e.message}');
        return true;
      }());

      // Re-throw with user-friendly message
      throw _handleAuthException(e);
    } catch (e) {
      // Debug logging
      assert(() {
        debugPrint('❌ Unexpected error verifying magic link: $e');
        return true;
      }());

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
      // Debug logging
      assert(() {
        debugPrint('🚪 Signing out user');
        return true;
      }());

      await _supabase.auth.signOut();

      // Debug logging
      assert(() {
        debugPrint('✅ User signed out successfully');
        return true;
      }());

      return true;
    } on AuthException catch (e) {
      // Debug logging
      assert(() {
        debugPrint('❌ Sign out failed: ${e.message}');
        return true;
      }());

      throw _handleAuthException(e);
    } catch (e) {
      // Debug logging
      assert(() {
        debugPrint('❌ Unexpected error signing out: $e');
        return true;
      }());

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
  AuthException _handleAuthException(AuthException e) {
    // Debug logging
    assert(() {
      debugPrint('🔍 Handling AuthException: ${e.message}');
      debugPrint('   Status code: ${e.statusCode}');
      return true;
    }());

    // Map common errors to user-friendly messages
    final message = e.message.toLowerCase();

    if (message.contains('rate limit')) {
      return AuthException(
        'Too many attempts. Please wait 15 minutes before trying again.',
      );
    }

    if (message.contains('invalid') || message.contains('expired')) {
      return AuthException(
        'This magic link has expired or is invalid. Please request a new one.',
      );
    }

    if (message.contains('not authorized') || message.contains('domain')) {
      return AuthException(
        'Please use your school email address (@galileimoro.edu.it)',
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
