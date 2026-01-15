// =====================================================================
// User Role Provider - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Provide real-time user role with Supabase subscription
// Architecture: Riverpod StreamProvider with automatic updates
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/enums/user_role.dart';
import 'package:nova/core/providers/core_providers.dart';

/// Provider for current user's role with real-time updates
///
/// Subscribes to user_roles table and returns the highest priority role.
/// Priority: admin > moderator > student
///
/// Returns UserRole.student as default if:
/// - User is not authenticated
/// - User has no role assigned in database
/// - Real-time subscription fails
///
/// Example usage:
/// ```dart
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final roleAsync = ref.watch(userRoleProvider);
///     return roleAsync.when(
///       data: (role) => Text('Role: $role'),
///       loading: () => CircularProgressIndicator(),
///       error: (_, __) => Text('Error loading role'),
///     );
///   }
/// }
/// ```
final userRoleProvider = StreamProvider<UserRole>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;

  // If no user authenticated, return student role
  if (userId == null) {
    return Stream.value(UserRole.student);
  }

  // Subscribe to user_roles table for real-time updates
  return supabase
      .from('user_roles')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .map((data) {
        // If no roles assigned, default to student
        if (data.isEmpty) {
          return UserRole.student;
        }

        // Extract all role strings
        final roles = data.map((json) => json['role'] as String).toList();

        // Return highest priority role: admin > moderator > student
        if (roles.contains('admin')) {
          return UserRole.admin;
        }
        if (roles.contains('moderator')) {
          return UserRole.moderator;
        }
        return UserRole.student;
      });
});

/// Provider to check if user should see moderation queue tab
///
/// Returns true if user is moderator or admin
final shouldShowModerationQueueProvider = Provider<bool>((ref) {
  final roleAsync = ref.watch(userRoleProvider);
  return roleAsync.when(
    data: (role) => role.canModerate,
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider to check if user should see admin panel tab
///
/// Returns true if user is admin
final shouldShowAdminPanelProvider = Provider<bool>((ref) {
  final roleAsync = ref.watch(userRoleProvider);
  return roleAsync.when(
    data: (role) => role.isAdmin,
    loading: () => false,
    error: (_, __) => false,
  );
});
