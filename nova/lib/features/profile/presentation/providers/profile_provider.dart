// Provider: ProfileProvider
// Feature: 006-user-profile (evolved from 002-profile-setup)
// Purpose: Riverpod StateNotifier for complete profile state management with auto-save

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../domain/entities/profile.dart';
import '../../domain/entities/profile_stats.dart';
import '../../domain/usecases/create_profile.dart';
import '../../domain/usecases/check_profile_complete.dart';
import '../../domain/usecases/get_profile.dart';
import '../../domain/usecases/update_profile.dart';
import '../../domain/usecases/upload_avatar.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/datasources/profile_local_datasource.dart';
import '../../data/models/profile_model.dart';
import '../../data/services/avatar_upload_service.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

/// Supabase client provider
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Hive box provider for profiles
final profileBoxProvider = Provider<Box<ProfileModel>>((ref) {
  return Hive.box<ProfileModel>('profiles');
});

/// Profile remote datasource provider
final profileRemoteDataSourceProvider =
    Provider<ProfileRemoteDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return ProfileRemoteDataSource(supabase);
});

/// Profile local datasource provider
final profileLocalDataSourceProvider = Provider<ProfileLocalDataSource>((ref) {
  final box = ref.watch(profileBoxProvider);
  return ProfileLocalDataSource(box);
});

/// Profile repository provider
final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final remoteDataSource = ref.watch(profileRemoteDataSourceProvider);
  final localDataSource = ref.watch(profileLocalDataSourceProvider);
  return ProfileRepository(
    remoteDataSource,
    localDataSource,
    Connectivity(),
  );
});

/// Avatar upload service provider
final avatarUploadServiceProvider = Provider<AvatarUploadService>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return AvatarUploadService(supabase);
});

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

/// GetProfile use case provider (T027)
final getProfileUseCaseProvider = Provider<GetProfile>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return GetProfile(repository);
});

/// UpdateProfile use case provider (T028)
final updateProfileUseCaseProvider = Provider<UpdateProfile>((ref) {
  final repository = ref.watch(profileRepositoryProvider);
  return UpdateProfile(repository);
});

/// UploadAvatar use case provider (T029)
final uploadAvatarUseCaseProvider = Provider<UploadAvatar>((ref) {
  final avatarService = ref.watch(avatarUploadServiceProvider);
  final repository = ref.watch(profileRepositoryProvider);
  return UploadAvatar(avatarService, repository);
});

/// Current user's profile provider
///
/// Loads and caches the authenticated user's profile
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
  final supabase = ref.watch(supabaseClientProvider);

  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('User not authenticated');
  }

  return await repository.getProfile(userId);
});

/// Current user's profile statistics provider
///
/// Loads profile stats (events created, participations count)
/// Usage:
/// ```dart
/// final statsAsync = ref.watch(currentProfileStatsProvider);
/// statsAsync.when(
///   data: (stats) => Text('${stats.eventsCreatedCount} events'),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => Text('Error loading stats'),
/// );
/// ```
final currentProfileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final supabase = ref.watch(supabaseClientProvider);

  final userId = supabase.auth.currentUser?.id;
  if (userId == null) {
    throw Exception('User not authenticated');
  }

  return await repository.getProfileStats(userId);
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

  /// Update profile class (instant save)
  Future<void> updateClass(String className) async {
    await _updateField('class', className);
  }

  /// Update profile visibility toggle (instant save)
  Future<void> updateProfileVisibility(bool visible) async {
    await _updateField('profile_visible', visible);
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
            throw Exception('Unknown field: $fieldName');
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
    throw Exception('User not authenticated');
  }

  return ProfileNotifier(repository, userId);
});
