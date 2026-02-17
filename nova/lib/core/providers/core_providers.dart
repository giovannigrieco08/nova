/// Core Providers - Unified Provider Definitions
///
/// This file consolidates all shared providers to prevent duplication.
/// All features should import from this file for shared dependencies.
///
/// Usage:
/// ```dart
/// import 'package:nova/core/providers/core_providers.dart';
///
/// final myProvider = Provider((ref) {
///   final supabase = ref.watch(supabaseClientProvider);
///   final userId = ref.watch(currentUserIdProvider);
///   // ...
/// });
/// ```
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// =============================================================================
// SUPABASE PROVIDERS
// =============================================================================

/// Singleton provider for SupabaseClient instance.
///
/// This is the ONLY definition of supabaseClientProvider in the codebase.
/// All features must import from this file.
///
/// Usage:
/// ```dart
/// final supabase = ref.watch(supabaseClientProvider);
/// final response = await supabase.from('events').select();
/// ```
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// =============================================================================
// AUTH PROVIDERS
// =============================================================================

/// Current authenticated user ID.
///
/// Returns empty string if not authenticated. Use [currentUserIdOrNullProvider]
/// if you need to handle unauthenticated state explicitly.
///
/// Usage:
/// ```dart
/// final userId = ref.watch(currentUserIdProvider);
/// if (userId.isEmpty) {
///   // Handle unauthenticated state
/// }
/// ```
final currentUserIdProvider = Provider<String>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentUser?.id ?? '';
});

/// Current authenticated user ID (nullable version).
///
/// Returns null if not authenticated.
///
/// Usage:
/// ```dart
/// final userId = ref.watch(currentUserIdOrNullProvider);
/// if (userId == null) {
///   return const LoginPrompt();
/// }
/// ```
final currentUserIdOrNullProvider = Provider<String?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentUser?.id;
});

/// Current authenticated user email.
///
/// Returns null if not authenticated.
final currentUserEmailProvider = Provider<String?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentUser?.email;
});

/// Stream of auth state changes.
///
/// Useful for reacting to login/logout events.
///
/// Usage:
/// ```dart
/// ref.listen(authStateChangesProvider, (prev, next) {
///   next.whenData((state) {
///     if (state.event == AuthChangeEvent.signedOut) {
///       // Navigate to login
///     }
///   });
/// });
/// ```
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.onAuthStateChange;
});

// =============================================================================
// UTILITY PROVIDERS
// =============================================================================

/// Check if user is currently authenticated.
///
/// Usage:
/// ```dart
/// final isLoggedIn = ref.watch(isAuthenticatedProvider);
/// return isLoggedIn ? MainScreen() : LoginScreen();
/// ```
final isAuthenticatedProvider = Provider<bool>((ref) {
  final userId = ref.watch(currentUserIdOrNullProvider);
  return userId != null;
});

/// Current user's full User object.
///
/// Returns null if not authenticated.
final currentUserProvider = Provider<User?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentUser;
});
