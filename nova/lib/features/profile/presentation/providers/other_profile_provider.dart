// Provider: OtherProfileProvider
// Feature: 006-user-profile (US2 - View Other Profiles)
// Purpose: Provides access to other users' public profiles

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/profile.dart';
import '../../data/repositories/profile_repository.dart';
import './profile_provider.dart'
    show profileRepositoryProvider, avatarUploadServiceProvider;
import '../../../events/presentation/providers/events_feed_provider.dart'
    show eventsRepositoryProvider;
import '../../../events/domain/entities/event.dart';

/// Provider for fetching another user's profile by userId
final otherProfileProvider =
    FutureProvider.family<Profile?, String>((ref, userId) async {
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
final otherProfileStatsProvider =
    FutureProvider.family<ProfileStats?, String>((ref, userId) async {
  final repository = ref.read(profileRepositoryProvider);
  return repository.getProfileStats(userId);
});

/// Events created by another user
/// Used for other profile "Eventi" tab
final otherUserCreatedEventsProvider =
    FutureProvider.family<List<Event>, String>((ref, userId) async {
  final repository = ref.watch(eventsRepositoryProvider);
  return await repository.getEventsByCreator(userId);
});

/// Events another user is participating in
/// Used for other profile "Partecipazioni" tab
final otherUserParticipatingEventsProvider =
    FutureProvider.family<List<Event>, String>((ref, userId) async {
  final repository = ref.watch(eventsRepositoryProvider);
  return await repository.getEventsParticipating(userId);
});
