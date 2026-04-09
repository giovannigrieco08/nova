/// Data layer providers for Profile feature
///
/// Provides datasource and repository instances via Riverpod DI.
/// Presentation layer should import this file instead of datasources directly.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:nova/core/providers/core_providers.dart';

import '../datasources/profile_remote_datasource.dart';
import '../datasources/profile_local_datasource.dart';
import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';
import '../services/avatar_upload_service.dart';

// Re-export types used by presentation layer
export '../repositories/profile_repository.dart' show ProfileRepository;
export '../services/avatar_upload_service.dart' show AvatarUploadService;
export '../../domain/entities/profile_stats.dart' show ProfileStats;

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
