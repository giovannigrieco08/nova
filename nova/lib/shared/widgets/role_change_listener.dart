// =====================================================================
// RoleChangeListener Widget - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Listen for role changes and show notifications
// Architecture: ConsumerWidget that wraps app and listens to userRoleProvider
// =====================================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/enums/user_role.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/features/auth/providers/user_role_provider.dart';

/// Role change listener widget
///
/// Listens to userRoleProvider changes and:
/// - Shows SnackBar when role changes (promotion/demotion)
/// - Navigates away from restricted routes when demoted
/// - Provides action button to navigate to new features
class RoleChangeListener extends ConsumerWidget {
  final Widget child;

  const RoleChangeListener({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to role changes
    ref.listen<AsyncValue<UserRole>>(
      userRoleProvider,
      (previous, next) {
        // Only handle when both previous and next have values
        if (previous is! AsyncData || next is! AsyncData) {
          return;
        }

        final prevRole = previous.value;
        final newRole = next.value;

        // Check if role actually changed
        if (prevRole == newRole) {
          return;
        }

        // Handle promotion to moderator
        if (newRole == UserRole.moderator && prevRole == UserRole.student) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Congratulazioni! Sei stato promosso a moderatore.'),
              backgroundColor: NovaColors.success(context),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Vai',
                textColor: Colors.white,
                onPressed: () {
                  // Navigate to moderation queue
                  Navigator.of(context).pushNamed('/moderation');
                },
              ),
            ),
          );
        }

        // Handle promotion to admin
        if (newRole == UserRole.admin &&
            (prevRole == UserRole.student || prevRole == UserRole.moderator)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Congratulazioni! Sei stato promosso ad amministratore.'),
              backgroundColor: NovaColors.success(context),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Vai',
                textColor: Colors.white,
                onPressed: () {
                  // Navigate to admin panel
                  Navigator.of(context).pushNamed('/admin');
                },
              ),
            ),
          );
        }

        // Handle demotion from moderator
        if (newRole == UserRole.student && prevRole == UserRole.moderator) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Il tuo ruolo di moderatore è stato rimosso.'),
              backgroundColor: NovaColors.warning(context),
              duration: const Duration(seconds: 5),
            ),
          );

          // Navigate away from /moderation route if currently there
          // Get current route using ModalRoute
          final currentRoute = ModalRoute.of(context)?.settings.name;
          if (currentRoute != null &&
              (currentRoute.startsWith('/moderation') ||
                  currentRoute.startsWith('/admin'))) {
            Navigator.of(context).pushReplacementNamed('/events');
          }
        }

        // Handle demotion from admin
        if (newRole != UserRole.admin && prevRole == UserRole.admin) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Il tuo ruolo di amministratore è stato rimosso.'),
              backgroundColor: NovaColors.warning(context),
              duration: const Duration(seconds: 5),
            ),
          );

          // Navigate away from /admin route if currently there
          final currentRoute = ModalRoute.of(context)?.settings.name;
          if (currentRoute != null && currentRoute.startsWith('/admin')) {
            // If still moderator, go to moderation queue
            if (newRole == UserRole.moderator) {
              Navigator.of(context).pushReplacementNamed('/moderation');
            } else {
              // Otherwise go to events feed
              Navigator.of(context).pushReplacementNamed('/events');
            }
          }
        }
      },
    );

    return child;
  }
}
