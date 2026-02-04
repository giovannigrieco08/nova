// =====================================================================
// Nova - Supabase Configuration
// =====================================================================
// Purpose: Initialize Supabase client for Flutter app
// Architecture: Singleton pattern with PKCE flow for security
// =====================================================================

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase configuration and initialization
class SupabaseConfig {
  // Private constructor (singleton pattern)
  SupabaseConfig._();

  /// Supabase project URL from environment variables
  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL'];
    if (url == null || url.isEmpty) {
      throw Exception('SUPABASE_URL not found in .env file');
    }
    return url;
  }

  /// Supabase anon (public) key from environment variables
  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY'];
    if (key == null || key.isEmpty) {
      throw Exception('SUPABASE_ANON_KEY not found in .env file');
    }
    return key;
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
  /// - Exception if environment variables are missing
  /// - Exception if Supabase initialization fails
  static Future<void> initialize() async {
    try {
      // Load environment variables from .env file
      try {
        await dotenv.load(fileName: '.env');
      } catch (e) {
        throw Exception('⚠️  Missing .env file!\n\n'
            'Setup steps:\n'
            '1. Copy .env.example to .env\n'
            '2. Fill in your Supabase credentials\n\n'
            'See CREDENTIALS.md for detailed instructions');
      }

      // Validate required environment variables
      final url = dotenv.env['SUPABASE_URL'];
      final anonKey = dotenv.env['SUPABASE_ANON_KEY'];

      if (url == null || url.isEmpty || anonKey == null || anonKey.isEmpty) {
        throw Exception('⚠️  Incomplete .env configuration!\n\n'
            'Required variables:\n'
            '- SUPABASE_URL\n'
            '- SUPABASE_ANON_KEY\n\n'
            'Check CREDENTIALS.md for setup guide');
      }

      // Initialize Supabase client
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
    } catch (e) {
      rethrow;
    }
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
