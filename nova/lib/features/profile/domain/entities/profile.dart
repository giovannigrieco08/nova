// Domain Entity: Profile
// Feature: 006-user-profile
// Purpose: Immutable domain model for student profile

import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

@freezed
class Profile with _$Profile {
  const Profile._(); // Private constructor to enable extension methods

  const factory Profile({
    /// User ID (links to auth.users)
    required String userId,

    /// Student's email (@galileimoro.edu.it)
    required String email,

    /// Student's full name (2-50 characters)
    required String fullName,

    /// Auto-generated username (nome.cognome format)
    required String username,

    /// School class (e.g., "5A", "4B", "Altro")
    /// NULL = incomplete profile
    @JsonKey(name: 'class') String? classYear,

    /// Supabase Storage URL for avatar
    /// NULL = show colored initials fallback
    String? avatarUrl,

    /// Optional bio text (max 150 characters, sanitized)
    String? bio,

    /// User role ('student', 'moderator', 'admin')
    @Default('student') String role,

    /// Privacy toggle: if false, profile hidden from others
    @Default(true) bool profileVisible,

    /// Profile creation timestamp
    required DateTime createdAt,

    /// Last update timestamp (auto-updated)
    required DateTime updatedAt,

    /// Soft delete timestamp (null = not deleted, set = in grace period)
    DateTime? deletedAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  /// Check if user is moderator or admin
  bool get isModerator => role == 'moderator' || role == 'admin';

  /// Check if user is admin
  bool get isAdmin => role == 'admin';

  /// Check if profile is soft-deleted
  bool get isDeleted => deletedAt != null;
}

/// Extension methods for Profile
extension ProfileExtensions on Profile {
  /// Checks if profile is complete (has name AND class)
  bool get isComplete => classYear != null && classYear!.isNotEmpty;

  /// Gets initials for avatar (e.g., "Giovanni Rossi" → "GR")
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    } else {
      return '${parts.first[0].toUpperCase()}${parts.last[0].toUpperCase()}';
    }
  }

  /// Checks if avatar is set (has valid URL)
  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  /// Checks if bio is set
  bool get hasBio => bio != null && bio!.trim().isNotEmpty;

  /// Gets display-friendly class text
  String get classDisplay => classYear ?? 'Non specificato';
}
