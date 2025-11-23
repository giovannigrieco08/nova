// Usecase: GetProfile
// Feature: 006-user-profile (User Story 1)
// Purpose: Load profile by user_id with offline-first caching

import '../entities/profile.dart';
import '../../data/repositories/profile_repository.dart';

/// Get user profile by ID with offline-first caching
///
/// **Usage**:
/// ```dart
/// final getProfile = ref.read(getProfileUseCaseProvider);
/// final profile = await getProfile(userId);
/// ```
///
/// **Strategy**: Remote-first with local cache fallback
/// - Online: Fetch from Supabase, update Hive cache
/// - Offline: Load from Hive cache
/// - Error: Fallback to cache if available
///
/// **Throws**:
/// - `ProfileCacheNotFoundException` if offline and no cache available
/// - `PostgrestException` if remote query fails and no cache
class GetProfile {
  final ProfileRepository _repository;

  GetProfile(this._repository);

  /// Execute the usecase to get profile by user ID
  ///
  /// **Parameters**:
  /// - `userId`: UUID of the user to fetch profile for
  ///
  /// **Returns**: Profile entity with complete data
  Future<Profile> call(String userId) async {
    return await _repository.getProfile(userId);
  }
}
