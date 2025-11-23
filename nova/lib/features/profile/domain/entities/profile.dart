// Domain Entity: Profile
// Feature: 006-user-profile (evolved from 002-profile-setup)
// Purpose: Immutable domain model for complete user profile system

import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

/// User profile entity with complete profile system fields
///
/// Schema matches supabase/migrations/006_user_profile_system.sql
///
/// Fields:
/// - [id]: Supabase user UUID (primary key, renamed from userId)
/// - [email]: User email (@galileimoro.edu.it, required for username generation)
/// - [fullName]: Display name (editable, 2-50 characters)
/// - [username]: Auto-generated unique username (read-only, format: nome.cognome)
/// - [classYear]: Student class (38 options + "Altro", editable, renamed from classValue)
/// - [bio]: User bio max 150 characters (editable, auto-sanitized)
/// - [avatarUrl]: Avatar image URL from Supabase Storage (editable)
/// - [role]: User role (student/moderator/admin, read-only in UI)
/// - [profileVisible]: Privacy toggle for profile visibility (editable)
/// - [createdAt]: Account creation timestamp
/// - [deletedAt]: Soft delete timestamp (null = active, non-null = in 30-day grace period)
@freezed
class Profile with _$Profile {
  const factory Profile({
    /// User ID (Supabase auth.users UUID, primary key)
    required String id,

    /// User email (@galileimoro.edu.it)
    required String email,

    /// Student's full name (2-50 characters, editable)
    String? fullName,

    /// Auto-generated unique username (read-only, format: nome.cognome)
    required String username,

    /// School class (38 classes: Scientifico A-E, F partial, Classico Ac-Bc, or "Altro")
    /// NULL = incomplete profile (user hasn't selected class yet)
    String? classYear,

    /// Optional bio text (max 150 characters, auto-sanitized by database trigger)
    String? bio,

    /// Supabase Storage avatar URL (public bucket: avatars/{user_id}/avatar.webp)
    /// NULL = show colored initials fallback
    String? avatarUrl,

    /// User role (student/moderator/admin, determines badge visibility)
    @Default('student') String role,

    /// Profile visibility toggle (true = public, false = hidden from others)
    @Default(true) bool profileVisible,

    /// Profile creation timestamp
    required DateTime createdAt,

    /// Soft delete timestamp (null = active, non-null = in 30-day grace period before hard delete)
    DateTime? deletedAt,
  }) = _Profile;

  const Profile._();

  factory Profile.fromJson(Map<String, dynamic> json) =>
      _$ProfileFromJson(json);

  /// Whether this profile is soft-deleted (in 30-day grace period)
  bool get isDeleted => deletedAt != null;

  /// Whether this profile is a moderator or admin
  bool get isModerator => role == 'moderator' || role == 'admin';

  /// Whether this profile is publicly viewable
  /// (profile_visible = true AND not soft-deleted)
  bool get isPublic => profileVisible && !isDeleted;

  /// Checks if profile setup is complete (has name AND class)
  /// Required for accessing main app (enforced by profile_setup_screen)
  bool get isSetupComplete =>
      fullName != null &&
      fullName!.isNotEmpty &&
      classYear != null &&
      classYear!.isNotEmpty;

  /// Profile completion percentage (0.0 to 1.0) for progress indicator
  /// Considers: fullName, classYear, bio, avatarUrl
  double get completionPercentage {
    int completedFields = 0;
    int totalFields = 4;

    if (fullName != null && fullName!.isNotEmpty) completedFields++;
    if (classYear != null && classYear!.isNotEmpty) completedFields++;
    if (bio != null && bio!.isNotEmpty) completedFields++;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) completedFields++;

    return completedFields / totalFields;
  }

  /// Gets initials for avatar fallback (e.g., "Giovanni Rossi" → "GR")
  String get initials {
    final name = fullName ?? username;
    final parts = name.trim().split(' ');
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
}
