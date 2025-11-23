// Riverpod Provider: Supabase Client
// Feature: Core infrastructure
// Purpose: Provide singleton SupabaseClient instance for dependency injection
//
// This provider is used by all repository providers to inject SupabaseClient
// into data sources that need database/storage access.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider for SupabaseClient singleton
///
/// Usage in other providers:
/// ```dart
/// final eventRepositoryProvider = Provider<EventRepository>((ref) {
///   final supabase = ref.watch(supabaseClientProvider);
///   // ...
/// });
/// ```
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
