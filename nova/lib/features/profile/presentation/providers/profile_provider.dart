// Provider: ProfileProvider
// Feature: 002-profile-setup
// Purpose: Riverpod StateNotifier for profile state management with auto-save

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/exceptions/nova_exceptions.dart';
import 'package:nova/core/providers/core_providers.dart';
import 'package:nova/features/auth/presentation/providers/auth_notifier.dart';
import 'package:nova/core/models/auth_state.dart';
import '../../domain/entities/profile.dart';
import '../../domain/usecases/create_profile.dart';
import '../../domain/usecases/check_profile_complete.dart';
import '../../data/providers/profile_data_providers.dart';
export '../../data/providers/profile_data_providers.dart';
// Events imports for user events providers
import '../../../events/data/providers/events_data_providers.dart'
    show eventsRepositoryProvider;
import '../../../events/domain/entities/event.dart';

// ============================================================================
// PROVIDERS
// ============================================================================
// Data layer providers imported from profile_data_providers.dart

/// CreateProfile use case provider
final createProfileUseCaseProvider = Provider<CreateProfile>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return CreateProfile(repository);
});

/// CheckProfileComplete use case provider
final checkProfileCompleteUseCaseProvider =
    Provider<CheckProfileComplete>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return CheckProfileComplete(repository);
});

/// Current user's profile provider
///
/// Loads and caches the authenticated user's profile
/// Automatically converts expired signed URLs to public URLs
/// CRITICAL: Watches authNotifierProvider to refresh when user changes
/// Usage:
/// ```dart
/// final profileAsync = ref.watch(currentProfileProvider);
/// profileAsync.when(
///   data: (profile) => Text(profile.fullName),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => Text('Error loading profile'),
/// );
/// ```
final currentProfileProvider = FutureProvider<Profile>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);

  // CRITICAL: Watch auth state to refresh profile when user changes
  // This ensures profile is reloaded after account switch via magic link
  final authState = ref.watch(authNotifierProvider);

  // Extract userId from auth state, not from supabase directly
  // This ensures we use the correct user ID after account switch
  final state = authState.valueOrNull;
  if (state == null || state is! AuthStateAuthenticated) {
    throw const UnauthorizedException('User not authenticated');
  }

  final userId = state.user.id;

  debugPrint('📝 [PROFILE_PROVIDER] Loading profile for user: $userId');

  var profile = await repository.getProfile(userId);

  // CRITICAL: Verify the loaded profile matches the requested user
  // This catches cache inconsistencies
  if (profile.userId != userId) {
    debugPrint('📝 [PROFILE_PROVIDER] WARNING: Profile mismatch! Requested: $userId, Got: ${profile.userId}');
    debugPrint('📝 [PROFILE_PROVIDER] Fetching fresh profile from remote...');
    // Force fetch from remote by calling getProfileById which doesn't use cache
    profile = await repository.getProfileById(userId);
  }

  debugPrint('📝 [PROFILE_PROVIDER] Loaded profile: ${profile.userId}, email: ${profile.email}');

  // Convert signed URL to public URL if needed
  // Signed URLs contain "token=" and expire, causing avatar display issues
  if (profile.avatarUrl != null && profile.avatarUrl!.contains('token=')) {
    final avatarService = ref.read(avatarUploadServiceProvider);
    final publicUrl = avatarService.normalizeAvatarUrl(profile.avatarUrl);
    if (publicUrl.isNotEmpty && publicUrl != profile.avatarUrl) {
      // Update profile with new public URL (fire and forget, don't block)
      repository.updateProfile(userId, {'avatar_url': publicUrl});
      profile = profile.copyWith(avatarUrl: publicUrl);
    }
  }

  return profile;
});

/// Profile state notifier
///
/// Manages profile state with auto-save functionality
/// - Bio: 500ms debounce before save
/// - Class/Pronouns: instant save
/// - Optimistic UI updates
class ProfileNotifier extends StateNotifier<AsyncValue<Profile>> {
  final ProfileRepository _repository;
  final String _userId;
  Timer? _debounceTimer;

  ProfileNotifier(this._repository, this._userId)
      : super(const AsyncValue.loading()) {
    _loadProfile();
  }

  /// Load profile from repository
  Future<void> _loadProfile() async {
    state = const AsyncValue.loading();

    try {
      final profile = await _repository.getProfile(_userId);
      state = AsyncValue.data(profile);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Refresh profile from server
  Future<void> refresh() async {
    await _loadProfile();
  }

  /// Update profile name (instant save)
  Future<void> updateName(String name) async {
    await _updateField('full_name', name.trim());
  }

  /// Update username (instant save)
  Future<void> updateUsername(String username) async {
    await _updateField('username', username.trim().toLowerCase());
  }

  /// Update profile class (instant save)
  Future<void> updateClass(String className) async {
    await _updateField('class', className);
  }

  /// Update profile pronouns (instant save)
  Future<void> updatePronouns(String? pronouns) async {
    await _updateField('pronouns', pronouns);
  }

  /// Update profile bio (500ms debounce)
  void updateBioDebounced(String bio) {
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Update UI optimistically
    state.whenData((profile) {
      state = AsyncValue.data(
        profile.copyWith(bio: bio.trim()),
      );
    });

    // Debounce save (500ms)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      await _updateField('bio', bio.trim());
    });
  }

  /// Update avatar URL (instant save)
  Future<void> updateAvatarUrl(String? avatarUrl) async {
    await _updateField('avatar_url', avatarUrl);
  }

  /// Generic field update with optimistic UI
  Future<void> _updateField(String fieldName, dynamic value) async {
    final previousState = state;

    try {
      // Optimistic UI update
      state.whenData((profile) {
        Profile updatedProfile;
        switch (fieldName) {
          case 'full_name':
            updatedProfile = profile.copyWith(fullName: value as String);
            break;
          case 'username':
            updatedProfile = profile.copyWith(username: value as String);
            break;
          case 'class':
            updatedProfile = profile.copyWith(classYear: value as String);
            break;
          case 'avatar_url':
            updatedProfile = profile.copyWith(avatarUrl: value as String?);
            break;
          case 'bio':
            updatedProfile = profile.copyWith(bio: value as String?);
            break;
          case 'profile_visible':
            updatedProfile = profile.copyWith(profileVisible: value as bool);
            break;
          default:
            throw StateError('Unknown field: $fieldName');
        }

        state = AsyncValue.data(updatedProfile);
      });

      // Save to repository
      await _repository.updateProfile(_userId, {fieldName: value});
    } catch (e, stack) {
      // Rollback on error
      state = previousState;
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Profile notifier provider
///
/// Provides ProfileNotifier for current authenticated user
/// Usage:
/// ```dart
/// final notifier = ref.read(profileNotifierProvider.notifier);
/// await notifier.updateClass('3A Scientifico');
/// ```
final profileNotifierProvider =
    StateNotifierProvider<ProfileNotifier, AsyncValue<Profile>>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw const UnauthorizedException('User not authenticated');
  }

  return ProfileNotifier(repository, userId);
});

/// Current user's profile stats provider (real-time)
///
/// Loads profile statistics (events created, participations count)
/// Automatically updates when events are created or user participates
/// Usage:
/// ```dart
/// final statsAsync = ref.watch(currentProfileStatsProvider);
/// statsAsync.when(
///   data: (stats) => Text('${stats.eventsCreatedCount} eventi'),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => Text('Error'),
/// );
/// ```
final currentProfileStatsProvider = StreamProvider<ProfileStats>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw const UnauthorizedException('User not authenticated');
  }

  return repository.watchProfileStats(userId);
});

/// Update profile use case provider
///
/// Wraps ProfileRepository.updateProfile for use in screens
final updateProfileUseCaseProvider =
    Provider<Future<void> Function(String, Map<String, dynamic>)>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return (userId, updates) => repository.updateProfile(userId, updates);
});

// ProfileStats is exported from profile_repository.dart

// ============================================================================
// USER EVENTS PROVIDERS
// ============================================================================

/// Events created by current user
/// Used for profile "Eventi" tab
final userCreatedEventsProvider = FutureProvider<List<Event>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final repository = ref.watch(eventsRepositoryProvider);

  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw const UnauthorizedException('User not authenticated');
  }

  return await repository.getEventsByCreator(userId);
});

/// Events user is participating in
/// Used for profile "Partecipazioni" tab
final userParticipatingEventsProvider =
    FutureProvider<List<Event>>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final repository = ref.watch(eventsRepositoryProvider);

  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw const UnauthorizedException('User not authenticated');
  }

  return await repository.getEventsParticipating(userId);
});
