// Domain Entity: UserProfile
// Feature: 003-events-feed
// Purpose: Business logic representation of a user profile (for event creators, commenters, participants)

class UserProfile {
  final String id;
  final String email;
  final String name;
  final String? classValue; // Optional class (e.g., "5A")
  final String? avatarUrl;
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.email,
    required this.name,
    this.classValue,
    this.avatarUrl,
    required this.createdAt,
  });

  /// Get display name (name + class if available)
  String get displayName {
    if (classValue != null && classValue!.isNotEmpty) {
      return '$name ($classValue)';
    }
    return name;
  }

  /// Get initials for avatar fallback (first + last name)
  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  /// Check if profile has avatar
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  /// Check if profile is complete (has class)
  bool get isComplete => classValue != null && classValue!.isNotEmpty;

  /// CopyWith for partial updates
  UserProfile copyWith({
    String? id,
    String? email,
    String? name,
    String? classValue,
    String? avatarUrl,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      classValue: classValue ?? this.classValue,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'UserProfile(id: $id, name: $name, class: $classValue)';
  }
}
