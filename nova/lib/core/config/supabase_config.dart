// =====================================================================
// Nova - Supabase Configuration
// =====================================================================
// Purpose: Initialize Supabase client for Flutter app
// Architecture: Singleton pattern with PKCE flow for security
//
// Credentials are injected at compile-time via --dart-define:
//   flutter run \
//     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=eyJ...
// =====================================================================

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration and initialization
class SupabaseConfig {
  // Private constructor (singleton pattern)
  SupabaseConfig._();

  /// Supabase project URL injected at compile-time
  static const String _url =
      String.fromEnvironment('SUPABASE_URL');

  /// Supabase anon (public) key injected at compile-time
  static const String _anonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Supabase project URL from compile-time environment
  static String get supabaseUrl {
    if (_url.isEmpty) {
      throw StateError(
          'SUPABASE_URL not provided. Pass --dart-define=SUPABASE_URL=...');
    }
    return _url;
  }

  /// Supabase anon (public) key from compile-time environment
  static String get supabaseAnonKey {
    if (_anonKey.isEmpty) {
      throw StateError(
          'SUPABASE_ANON_KEY not provided. Pass --dart-define=SUPABASE_ANON_KEY=...');
    }
    return _anonKey;
  }

  /// Initialize Supabase client
  ///
  /// This method MUST be called before runApp() in main.dart
  ///
  /// Configuration:
  /// - PKCE flow: Enhanced security for mobile apps
  /// - Auto refresh token: Automatic token refresh (30 days)
  /// - Persist session: Session persists across app restarts
  ///
  /// Throws:
  /// - Exception if compile-time variables are missing
  /// - Exception if Supabase initialization fails
  static Future<void> initialize() async {
    // Initialize Supabase client
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  }

  /// Get Supabase client instance
  ///
  /// Usage:
  /// ```dart
  /// final supabase = SupabaseConfig.client;
  /// final user = supabase.auth.currentUser;
  /// ```
  static SupabaseClient get client => Supabase.instance.client;

  /// Get current authenticated user (if any)
  ///
  /// Returns:
  /// - User object if authenticated
  /// - null if not authenticated
  static User? get currentUser => client.auth.currentUser;

  /// Check if user is authenticated
  ///
  /// Returns:
  /// - true if user is authenticated
  /// - false if not authenticated
  static bool get isAuthenticated => currentUser != null;

  /// Get current session (if any)
  ///
  /// Returns:
  /// - Session object if authenticated
  /// - null if not authenticated
  static Session? get currentSession => client.auth.currentSession;
}
