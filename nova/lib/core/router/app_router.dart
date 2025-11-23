// =====================================================================
// App Router - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Centralized routing with role-based guards
// Architecture: Simple route registry with role checks
// =====================================================================

import 'package:flutter/material.dart';
import 'package:nova/core/enums/user_role.dart';

/// Route configuration
class AppRoute {
  final String path;
  final WidgetBuilder builder;
  final List<UserRole> allowedRoles;

  const AppRoute({
    required this.path,
    required this.builder,
    this.allowedRoles = const [UserRole.student, UserRole.moderator, UserRole.admin],
  });
}

/// App router with role-based access control
class AppRouter {
  AppRouter._();

  /// Route paths
  static const String home = '/';
  static const String events = '/events';
  static const String profile = '/profile';
  static const String moderation = '/moderation';
  static const String admin = '/admin';
  static const String eventDetail = '/event';

  /// Check if user can access route based on role
  static bool canAccessRoute(String path, UserRole userRole) {
    // Students can access all base routes except moderation and admin
    if (path == moderation) {
      return userRole == UserRole.moderator || userRole == UserRole.admin;
    }

    if (path == admin) {
      return userRole == UserRole.admin;
    }

    // All users can access other routes
    return true;
  }

  /// Get redirect path if user cannot access requested route
  ///
  /// Returns null if access is allowed, otherwise returns redirect path
  static String? getRedirectPath(String requestedPath, UserRole userRole) {
    if (!canAccessRoute(requestedPath, userRole)) {
      return events; // Redirect to events feed
    }
    return null; // Access allowed
  }

  /// Navigate to route with role check
  ///
  /// Returns true if navigation succeeded, false if blocked by role check
  static bool navigateTo(
    BuildContext context,
    String path,
    UserRole userRole, {
    Object? arguments,
  }) {
    final redirectPath = getRedirectPath(path, userRole);

    if (redirectPath != null) {
      // User doesn't have permission, redirect to events
      Navigator.of(context).pushReplacementNamed(redirectPath);
      return false;
    }

    // User has permission, navigate to requested route
    Navigator.of(context).pushNamed(path, arguments: arguments);
    return true;
  }
}
