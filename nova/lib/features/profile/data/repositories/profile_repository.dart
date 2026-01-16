// Repository: ProfileRepository
// Feature: 002-profile-setup
// Purpose: Combines remote + local datasources with offline-first logic

import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/profile_stats.dart';
import '../datasources/profile_local_datasource.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/profile_model.dart';

// Re-export ProfileStats for convenience
export '../../domain/entities/profile_stats.dart';

/// Repository for profile operations with offline-first strategy
class ProfileRepository {
  final ProfileRemoteDataSource _remoteDataSource;
  final ProfileLocalDataSource _localDataSource;
  final Connectivity _connectivity;

  ProfileRepository(
    this._remoteDataSource,
    this._localDataSource,
    this._connectivity,
  );

  /// Get current user's profile
  /// **Strategy**: Try remote first, fallback to local cache on error
  Future<Profile> getProfile(String userId) async {
    try {
      // Check network connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;

      if (isOnline) {
        // Try remote first
        final remoteProfile = await _remoteDataSource.getProfile(userId);

        // Cache locally
        await _localDataSource.saveProfile(remoteProfile);

        return remoteProfile.toEntity();
      } else {
        // Offline: use local cache
        final localProfile = _localDataSource.getProfile(userId);

        if (localProfile == null) {
          throw ProfileCacheNotFoundException(
              'No cached profile found for user $userId');
        }

        return localProfile.toEntity();
      }
    } catch (e) {
      // On error, try local cache as fallback
      final localProfile = _localDataSource.getProfile(userId);

      if (localProfile != null) {
        return localProfile.toEntity();
      }

      rethrow; // No cache available, propagate error
    }
  }

  /// Get another user's profile (for viewing)
  /// **Strategy**: Remote-only (no local cache for other users' profiles)
  Future<Profile> getProfileById(String userId) async {
    final remoteProfile = await _remoteDataSource.getProfileById(userId);
    return remoteProfile.toEntity();
  }

  /// Create new profile
  /// **Strategy**: Online-first with local cache on success
  Future<Profile> createProfile(Profile profile) async {
    final profileModel = ProfileModel.fromEntity(profile);

    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;

      if (isOnline) {
        // Create remotely
        final createdProfile =
            await _remoteDataSource.createProfile(profileModel);

        // Cache locally
        await _localDataSource.saveProfile(createdProfile);

        return createdProfile.toEntity();
      } else {
        // Offline: save locally and queue for sync
        await _localDataSource.saveProfile(profileModel);
        await _localDataSource.saveToPendingSync(profileModel);

        throw OfflineModeException(
            'Profilo salvato offline. Sarà sincronizzato quando tornerà la connessione.');
      }
    } catch (e) {
      // If error and not offline exception, save locally for retry
      if (e is! OfflineModeException) {
        await _localDataSource.saveProfile(profileModel);
        await _localDataSource.saveToPendingSync(profileModel);
      }
      rethrow;
    }
  }

  /// Update profile with partial fields
  /// **Strategy**: Optimistic UI (update local immediately, sync in background)
  Future<Profile> updateProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Get current profile from cache
      final currentProfile = _localDataSource.getProfile(userId);

      if (currentProfile == null) {
        throw ProfileCacheNotFoundException(
            'No cached profile to update for user $userId');
      }

      // Apply updates to create new profile (optimistic UI)
      final updatedModel = _applyUpdates(currentProfile, updates);

      // Save locally immediately (optimistic)
      await _localDataSource.saveProfile(updatedModel);

      // Check connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;

      if (isOnline) {
        try {
          // Sync to remote
          final remoteProfile =
              await _remoteDataSource.updateProfile(userId, updates);

          // Update local cache with server response
          await _localDataSource.saveProfile(remoteProfile);

          // Remove from pending sync if it was there
          await _localDataSource.removeFromPendingSync(userId);

          return remoteProfile.toEntity();
        } catch (e) {
          // Remote update failed, queue for retry
          await _localDataSource.saveToPendingSync(updatedModel);
          rethrow;
        }
      } else {
        // Offline: queue for sync
        await _localDataSource.saveToPendingSync(updatedModel);

        throw OfflineModeException(
            'Modifiche salvate offline. Saranno sincronizzate quando tornerà la connessione.');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Delete profile (GDPR Right to Erasure)
  /// **Strategy**: Online-only (cannot delete offline)
  Future<void> deleteProfile(String userId) async {
    await _remoteDataSource.deleteProfile(userId);

    // Clear local cache
    await _localDataSource.deleteProfile(userId);
    await _localDataSource.removeFromPendingSync(userId);
  }

  /// Sync pending changes to remote (called when network returns)
  Future<void> syncPendingChanges() async {
    final pendingProfiles = _localDataSource.getPendingSync();

    if (pendingProfiles.isEmpty) {
      return; // Nothing to sync
    }

    final connectivityResult = await _connectivity.checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;

    if (!isOnline) {
      return; // Still offline, skip sync
    }

    for (final entry in pendingProfiles.entries) {
      final userId = entry.key;
      final profile = entry.value;

      try {
        // Check if profile exists locally
        final exists = _localDataSource.hasProfile(userId);

        if (exists) {
          // Update existing profile
          await _remoteDataSource.updateProfile(userId, profile.toJson());
        } else {
          // Create new profile
          await _remoteDataSource.createProfile(profile);
        }

        // Remove from pending queue on success
        await _localDataSource.removeFromPendingSync(userId);
      } catch (e) {
        // Keep in queue for next sync attempt
        // TODO: Add logging here
        continue;
      }
    }
  }

  /// Check if profile is complete (has class)
  Future<bool> isProfileComplete(String userId) async {
    try {
      // Try remote first
      return await _remoteDataSource.isProfileComplete(userId);
    } catch (e) {
      // Fallback to local cache
      final localProfile = _localDataSource.getProfile(userId);

      if (localProfile != null) {
        return localProfile.classYear != null &&
            localProfile.classYear!.isNotEmpty;
      }

      return false;
    }
  }

  /// Parse name from email
  Future<String?> parseNameFromEmail(String email) async {
    return await _remoteDataSource.parseNameFromEmail(email);
  }

  /// Check if username is available (case-insensitive)
  Future<bool> isUsernameAvailable(String username) async {
    return await _remoteDataSource.isUsernameAvailable(username);
  }

  /// Helper: Apply updates to profile model
  ProfileModel _applyUpdates(
    ProfileModel current,
    Map<String, dynamic> updates,
  ) {
    return ProfileModel(
      userId: current.userId,
      email: current.email,
      fullName: updates['full_name'] as String? ?? current.fullName,
      username: current.username,
      classYear: updates['class'] as String? ?? current.classYear,
      avatarUrl: updates.containsKey('avatar_url')
          ? updates['avatar_url'] as String?
          : current.avatarUrl,
      bio: updates.containsKey('bio') ? updates['bio'] as String? : current.bio,
      role: current.role,
      profileVisible: updates['profile_visible'] as bool? ?? current.profileVisible,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(), // Update timestamp
      deletedAt: current.deletedAt,
    );
  }

  /// Get profile statistics (events created, participations)
  Future<ProfileStats> getProfileStats(String userId) async {
    try {
      return await _remoteDataSource.getProfileStats(userId);
    } catch (e) {
      // Return empty stats on error
      return ProfileStats.empty();
    }
  }

  /// Get profile statistics stream (real-time updates)
  /// Listens to events and event_participants tables for changes
  Stream<ProfileStats> watchProfileStats(String userId) async* {
    // Emit initial value
    yield await getProfileStats(userId);

    // Listen to events table changes (for events_created_count)
    // Listen to event_participants table changes (for participations_count)
    // We use a simple approach: whenever any change happens, re-fetch stats
    await for (final _ in _remoteDataSource.watchStatsChanges(userId)) {
      yield await getProfileStats(userId);
    }
  }

  /// Get public profile by userId (for other users)
  Future<Profile?> getPublicProfile(String userId) async {
    try {
      final model = await _remoteDataSource.getProfileById(userId);
      if (model.profileVisible) {
        return model.toEntity();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

/// Custom exceptions

class ProfileCacheNotFoundException implements Exception {
  final String message;
  ProfileCacheNotFoundException(this.message);

  @override
  String toString() => 'ProfileCacheNotFoundException: $message';
}

class OfflineModeException implements Exception {
  final String message;
  OfflineModeException(this.message);

  @override
  String toString() => 'OfflineModeException: $message';
}
