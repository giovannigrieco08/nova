// Data Source: ProfileLocalDataSource
// Feature: 002-profile-setup
// Purpose: Hive offline storage for profile data

import 'package:hive/hive.dart';
import '../models/profile_model.dart';

/// Local data source for profile operations using Hive
class ProfileLocalDataSource {
  final Box<ProfileModel> _profileBox;

  ProfileLocalDataSource(this._profileBox);

  /// Save profile to local storage
  /// Key format: 'profile_{userId}'
  Future<void> saveProfile(ProfileModel profile) async {
    await _profileBox.put('profile_${profile.userId}', profile);
  }

  /// Get profile from local storage
  /// Returns null if not found
  ProfileModel? getProfile(String userId) {
    return _profileBox.get('profile_$userId');
  }

  /// Delete profile from local storage
  Future<void> deleteProfile(String userId) async {
    await _profileBox.delete('profile_$userId');
  }

  /// Save profile to pending sync queue (for offline edits)
  /// Key format: 'pending_sync_{userId}'
  Future<void> saveToPendingSync(ProfileModel profile) async {
    await _profileBox.put('pending_sync_${profile.userId}', profile);
  }

  /// Get all profiles pending sync
  /// Returns map of userId → ProfileModel
  Map<String, ProfileModel> getPendingSync() {
    final pendingMap = <String, ProfileModel>{};

    for (final key in _profileBox.keys) {
      if (key.toString().startsWith('pending_sync_')) {
        final userId = key.toString().replaceFirst('pending_sync_', '');
        final profile = _profileBox.get(key);
        if (profile != null) {
          pendingMap[userId] = profile;
        }
      }
    }

    return pendingMap;
  }

  /// Remove profile from pending sync queue
  Future<void> removeFromPendingSync(String userId) async {
    await _profileBox.delete('pending_sync_$userId');
  }

  /// Clear all pending sync profiles (after successful sync)
  Future<void> clearPendingSync() async {
    final keysToDelete = <String>[];

    for (final key in _profileBox.keys) {
      if (key.toString().startsWith('pending_sync_')) {
        keysToDelete.add(key.toString());
      }
    }

    for (final key in keysToDelete) {
      await _profileBox.delete(key);
    }
  }

  /// Check if profile exists locally
  bool hasProfile(String userId) {
    return _profileBox.containsKey('profile_$userId');
  }

  /// Get all cached profiles (useful for testing/debugging)
  List<ProfileModel> getAllProfiles() {
    final profiles = <ProfileModel>[];

    for (final key in _profileBox.keys) {
      if (key.toString().startsWith('profile_')) {
        final profile = _profileBox.get(key);
        if (profile != null) {
          profiles.add(profile);
        }
      }
    }

    return profiles;
  }

  /// Clear all local profiles (for logout/account deletion)
  Future<void> clearAll() async {
    await _profileBox.clear();
  }
}