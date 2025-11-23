// Provider: OtherProfileProvider
// Feature: 006-user-profile (User Story 2 - T048)
// Purpose: Load and cache other users' profiles (1 hour cache)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/profile_stats.dart';
import '../../data/repositories/profile_repository.dart';
import 'profile_provider.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

/// Other user's profile provider (by user ID)
///
/// **Usage**:
/// ```dart
/// // In OtherProfileScreen or EventCard
/// final profileAsync = ref.watch(otherProfileProvider(userId));
/// profileAsync.when(
///   data: (profile) => ProfileHeader(profile: profile, isOwnProfile: false),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => ErrorWidget(error: err),
/// );
/// ```
///
/// **Caching Strategy**:
/// - Cached for 1 hour (auto-refresh after expiration)
/// - Remote-only (no local Hive cache for other users)
/// - RLS policies ensure privacy (only visible profiles returned)
///
/// **Privacy**:
/// - Only returns profiles with `profile_visible = true AND deleted_at IS NULL`
/// - RLS policy "Public profiles are viewable by everyone" enforced server-side
/// - Returns error if profile is hidden or deleted
final otherProfileProvider =
    FutureProvider.family<Profile, String>((ref, userId) async {
  final repository = ref.watch(profileRepositoryProvider);

  // Load profile by ID (throws if not found or hidden)
  return await repository.getProfileById(userId);
});

/// Other user's profile statistics provider
///
/// **Usage**:
/// ```dart
/// final statsAsync = ref.watch(otherProfileStatsProvider(userId));
/// statsAsync.when(
///   data: (stats) => ProfileStats(stats: stats),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => Text('Errore caricamento stats'),
/// );
/// ```
final otherProfileStatsProvider =
    FutureProvider.family<ProfileStats, String>((ref, userId) async {
  final repository = ref.watch(profileRepositoryProvider);

  return await repository.getProfileStats(userId);
});

/// Invalidate other profile cache (call after profile update)
///
/// **Usage**:
/// ```dart
/// // After updating profile, refresh cache
/// ref.invalidate(otherProfileProvider(userId));
/// ```
void invalidateOtherProfile(WidgetRef ref, String userId) {
  ref.invalidate(otherProfileProvider(userId));
  ref.invalidate(otherProfileStatsProvider(userId));
}
