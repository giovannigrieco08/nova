// Provider: OtherProfileProvider
// Feature: 006-user-profile (US2 - View Other Profiles)
// Purpose: Provides access to other users' public profiles

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/profile.dart';
import '../../data/repositories/profile_repository.dart';
import './profile_provider.dart' show profileRepositoryProvider, avatarUploadServiceProvider;

/// Provider for fetching another user's profile by userId
final otherProfileProvider = FutureProvider.family<Profile?, String>((ref, userId) async {
  final repository = ref.read(profileRepositoryProvider);
  final avatarService = ref.read(avatarUploadServiceProvider);

  var profile = await repository.getPublicProfile(userId);

  // Convert signed URL to public URL if needed (local conversion only)
  if (profile != null &&
      profile.avatarUrl != null &&
      profile.avatarUrl!.contains('token=')) {
    final publicUrl = avatarService.normalizeAvatarUrl(profile.avatarUrl);
    if (publicUrl.isNotEmpty) {
      profile = profile.copyWith(avatarUrl: publicUrl);
    }
  }

  return profile;
});

/// Provider for fetching another user's stats by userId
final otherProfileStatsProvider = FutureProvider.family<ProfileStats?, String>((ref, userId) async {
  final repository = ref.read(profileRepositoryProvider);
  return repository.getProfileStats(userId);
});
