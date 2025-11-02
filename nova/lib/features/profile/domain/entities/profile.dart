// Domain Entity: Profile
// Feature: 002-profile-setup
// Purpose: Immutable domain model for student profile

import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

@freezed
class Profile with _$Profile {
  const factory Profile({
    /// User ID (links to auth.users)
    required String userId,

    /// Student's full name (2-50 characters)
    required String fullName,

    /// School class (e.g., "3A Scientifico", "2B Classico")
    /// NULL = incomplete profile (user skipped setup)
    String? classValue,

    /// Optional pronouns ("Lui", "Lei", "They", "Altro", "Preferisco non dire")
    /// NULL = "Non specificato" (not displayed)
    String? pronouns,

    /// Supabase Storage signed URL (1-hour expiry)
    /// NULL = show colored initials fallback
    String? avatarUrl,

    /// Optional bio text (max 150 characters, sanitized)
    String? bio,

    /// Profile creation timestamp
    required DateTime createdAt,

    /// Last update timestamp (auto-updated)
    required DateTime updatedAt,
  }) = _Profile;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);
}

/// Extension methods for Profile
extension ProfileExtensions on Profile {
  /// Checks if profile is complete (has name AND class)
  bool get isComplete => classValue != null && classValue!.isNotEmpty;

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

  /// Checks if pronouns are specified
  bool get hasPronouns => pronouns != null && pronouns!.isNotEmpty;

  /// Gets display-friendly pronouns text
  String get pronounsDisplay => pronouns ?? 'Non specificato';
}
