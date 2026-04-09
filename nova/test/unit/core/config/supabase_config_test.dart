/// Tests for SupabaseConfig
///
/// Tests configuration getters and validation logic.
/// Credentials are injected at compile-time via --dart-define.
/// Without --dart-define, String.fromEnvironment returns '' so getters throw.

import 'package:flutter_test/flutter_test.dart';

import 'package:nova/core/config/supabase_config.dart';

void main() {
  group('SupabaseConfig', () {
    // =========================================================================
    // HAPPY PATH
    // =========================================================================

    group('structure', () {
      test('supabaseUrl throws when dart-define not provided', () {
        // Without --dart-define=SUPABASE_URL, the const is '' so getter throws
        expect(
          () => SupabaseConfig.supabaseUrl,
          throwsA(isA<Exception>()),
        );
      });

      test('supabaseAnonKey throws when dart-define not provided', () {
        expect(
          () => SupabaseConfig.supabaseAnonKey,
          throwsA(isA<Exception>()),
        );
      });
    });

    // =========================================================================
    // EDGE CASES
    // =========================================================================

    group('edge cases', () {
      test('client accessor throws when not initialized (edge)', () {
        // Supabase.instance.client throws when not initialized
        expect(
          () => SupabaseConfig.client,
          throwsA(anything),
        );
      });
    });
  });
}
