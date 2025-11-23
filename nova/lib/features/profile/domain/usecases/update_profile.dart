// Usecase: UpdateProfile
// Feature: 006-user-profile (User Story 1)
// Purpose: Update profile fields with optimistic UI and offline queueing

import '../entities/profile.dart';
import '../../data/repositories/profile_repository.dart';

/// Update user profile with partial field updates
///
/// **Usage**:
/// ```dart
/// final updateProfile = ref.read(updateProfileUseCaseProvider);
/// await updateProfile(userId, {'full_name': 'Marco Rossi', 'class': '3A'});
/// ```
///
/// **Strategy**: Optimistic UI with offline queueing
/// - Updates Hive cache immediately (optimistic)
/// - Syncs to Supabase in background
/// - Rollback on error
/// - Offline: Queues for sync when network returns
///
/// **Updatable Fields**:
/// - `full_name` (String)
/// - `class` (String, validated by database CHECK constraint)
/// - `bio` (String, max 150 chars, auto-sanitized by database trigger)
/// - `avatar_url` (String?)
/// - `profile_visible` (bool)
///
/// **Read-Only Fields** (protected by application logic):
/// - `username` (auto-generated, immutable)
/// - `email` (managed by Supabase Auth)
/// - `role` (admin-only, not editable in UI)
///
/// **Throws**:
/// - `ProfileCacheNotFoundException` if no cached profile to update
/// - `PostgrestException` if remote update fails
/// - `OfflineModeException` if offline (changes queued for sync)
class UpdateProfile {
  final ProfileRepository _repository;

  UpdateProfile(this._repository);

  /// Execute the usecase to update profile fields
  ///
  /// **Parameters**:
  /// - `userId`: UUID of the user to update
  /// - `updates`: Map of field names to new values
  ///
  /// **Returns**: Updated Profile entity
  ///
  /// **Example**:
  /// ```dart
  /// await updateProfile('uuid-here', {
  ///   'full_name': 'Marco Rossi',
  ///   'class': '3A',
  ///   'bio': 'Appassionato di fisica e matematica!',
  /// });
  /// ```
  Future<Profile> call(String userId, Map<String, dynamic> updates) async {
    return await _repository.updateProfile(userId, updates);
  }
}
