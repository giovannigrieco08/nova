// Provider: OtherProfileProvider
// Feature: 006-user-profile (US2 - View Other Profiles)
// Purpose: Provides access to other users' public profiles

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/profile.dart';
import '../../data/repositories/profile_repository.dart';
import './profile_provider.dart' show profileRepositoryProvider;

/// Provider for fetching another user's profile by userId
final otherProfileProvider = FutureProvider.family<Profile?, String>((ref, userId) async {
  final repository = ref.read(profileRepositoryProvider);
  return repository.getPublicProfile(userId);
});

/// Provider for fetching another user's stats by userId
final otherProfileStatsProvider = FutureProvider.family<ProfileStats?, String>((ref, userId) async {
  final repository = ref.read(profileRepositoryProvider);
  return repository.getProfileStats(userId);
});
