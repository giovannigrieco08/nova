// Repository: ProfileRepository
// Feature: 006-user-profile (evolved from 002-profile-setup)
// Purpose: Combines remote + local datasources with offline-first logic

import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/profile_stats.dart';
import '../datasources/profile_local_datasource.dart';
import '../datasources/profile_remote_datasource.dart';
import '../models/profile_model.dart';

/// Repository for profile operations with offline-first strategy
///
/// Responsibilities:
/// - Profile CRUD operations
/// - Profile statistics (events created, participations)
/// - GDPR data export and deletion
/// - Offline-first caching with Hive
/// - Profile visibility toggle
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

  /// Get user profile by username (for deep link navigation)
  /// **Strategy**: Remote-only (no caching for username lookups)
  Future<Profile> getProfileByUsername(String username) async {
    final remoteProfile = await _remoteDataSource.getProfileByUsername(username);
    return remoteProfile.toEntity();
  }

  /// Get profile statistics (events created, participations count)
  /// **Strategy**: Remote-only (computed from database)
  Future<ProfileStats> getProfileStats(String userId) async {
    final statsModel = await _remoteDataSource.getProfileStats(userId);
    return statsModel.toEntity();
  }

  /// Update profile visibility toggle (privacy setting)
  /// **Strategy**: Optimistic UI (update local immediately, sync in background)
  Future<void> updateProfileVisibility(String userId, bool visible) async {
    // Update local cache immediately (optimistic)
    final currentProfile = _localDataSource.getProfile(userId);
    if (currentProfile != null) {
      final updatedModel = currentProfile.copyWith(profileVisible: visible);
      await _localDataSource.saveProfile(updatedModel);
    }

    // Sync to remote
    try {
      await _remoteDataSource.updateProfileVisibility(userId, visible);
    } catch (e) {
      // Revert local cache on error
      if (currentProfile != null) {
        await _localDataSource.saveProfile(currentProfile);
      }
      rethrow;
    }
  }

  /// Soft delete profile (GDPR Right to Erasure)
  /// Sets deleted_at timestamp, triggering 30-day grace period
  /// **Strategy**: Online-only (cannot delete offline)
  Future<void> softDeleteProfile(String userId) async {
    await _remoteDataSource.softDeleteProfile(userId);

    // Clear local cache
    await _localDataSource.deleteProfile(userId);
    await _localDataSource.removeFromPendingSync(userId);
  }

  /// Export user data (GDPR Right to Access, Art. 15)
  /// Returns JSON with profile, events, participations, comments
  /// **Strategy**: Remote-only (requires fresh data from database)
  Future<Map<String, dynamic>> exportUserData(String userId) async {
    return await _remoteDataSource.exportUserData(userId);
  }

  /// Delete profile (hard delete, admin-only)
  /// **Strategy**: Online-only (cannot delete offline)
  @deprecated
  Future<void> deleteProfile(String userId) async {
    await _remoteDataSource.hardDeleteProfile(userId);

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
        // TODO(sync/future): Add structured logging with error tracking service
        continue;
      }
    }
  }

  /// Search profiles by name, username, or class
  /// **Strategy**: Remote-only (no local cache needed)
  Future<List<Profile>> searchProfiles(String query) async {
    if (query.trim().isEmpty) {
      return [];
    }

    final profiles = await _remoteDataSource.searchProfiles(query);
    return profiles.map((model) => model.toEntity()).toList();
  }

  /// Helper: Apply updates to profile model
  ProfileModel _applyUpdates(
    ProfileModel current,
    Map<String, dynamic> updates,
  ) {
    return ProfileModel(
      id: current.id,
      email: current.email,
      fullName: updates['full_name'] as String? ?? current.fullName,
      username: current.username, // Username is read-only
      classYear: updates['class'] as String? ?? current.classYear,
      avatarUrl: updates.containsKey('avatar_url')
          ? updates['avatar_url'] as String?
          : current.avatarUrl,
      bio: updates.containsKey('bio') ? updates['bio'] as String? : current.bio,
      role: current.role, // Role is read-only in UI
      profileVisible: updates.containsKey('profile_visible')
          ? updates['profile_visible'] as bool
          : current.profileVisible,
      createdAt: current.createdAt,
      deletedAt: current.deletedAt, // Managed by softDeleteProfile
    );
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
