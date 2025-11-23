// =====================================================================
// User Role Enum - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Define user roles for role-based access control
// Architecture: Simple enum with string conversion methods
// =====================================================================

/// User role in the Nova system
///
/// Defines three-tier role hierarchy:
/// - student: Default role, can create events and view approved content
/// - moderator: Can approve/reject pending events
/// - admin: Can promote/remove moderators and view system statistics
enum UserRole {
  /// Student (default role)
  student,

  /// Moderator (can review pending events)
  moderator,

  /// Admin (can manage moderators)
  admin;

  /// Convert from database string value
  static UserRole fromString(String value) {
    switch (value.toLowerCase()) {
      case 'student':
        return UserRole.student;
      case 'moderator':
        return UserRole.moderator;
      case 'admin':
        return UserRole.admin;
      default:
        throw ArgumentError('Invalid user role: $value');
    }
  }

  /// Convert to database string value
  @override
  String toString() {
    switch (this) {
      case UserRole.student:
        return 'student';
      case UserRole.moderator:
        return 'moderator';
      case UserRole.admin:
        return 'admin';
    }
  }

  /// Check if role is moderator or admin
  bool get canModerate => this == UserRole.moderator || this == UserRole.admin;

  /// Check if role is admin
  bool get isAdmin => this == UserRole.admin;
}
