// Use Case: CheckProfileComplete
// Feature: 002-profile-setup
// Purpose: Check if user has completed profile setup

import '../../data/repositories/profile_repository.dart';

/// Use case for checking if user profile is complete
///
/// **Business Rule**:
/// A profile is complete if it has both `fullName` AND `class`
/// Incomplete profiles (skipped setup) have `class = null`
///
/// **Usage**:
/// Used to enforce protected actions:
/// - Create event → requires complete profile
/// - Comment on event → requires complete profile
/// - Access chat → requires complete profile
/// - Browse feed → allowed even with incomplete profile
class CheckProfileComplete {
  final ProfileRepository _repository;

  CheckProfileComplete(this._repository);

  /// Check if profile is complete
  ///
  /// Returns `true` if profile has name AND class
  /// Returns `false` if class is null (incomplete)
  ///
  /// Throws repository exceptions if profile cannot be fetched
  Future<bool> call(String userId) async {
    return await _repository.isProfileComplete(userId);
  }

  /// Check if profile is complete (synchronous, from local cache)
  ///
  /// Useful for UI checks without network call
  /// Requires profile to be loaded in cache first
  bool callSync(String userId) {
    // This would require accessing local datasource directly
    // For now, use the async version
    throw UnimplementedError(
        'Synchronous check not implemented. Use async call() instead.');
  }
}
