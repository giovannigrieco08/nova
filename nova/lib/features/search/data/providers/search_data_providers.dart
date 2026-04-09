/// Data layer providers for the search feature
///
/// Provides datasource and repository instances via Riverpod.
/// Re-exports data layer classes for convenient importing.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../datasources/search_remote_datasource.dart';
import '../datasources/search_local_datasource.dart';
import '../repositories/search_repository.dart';

export '../datasources/search_remote_datasource.dart'
    show SearchRemoteDataSource;
export '../datasources/search_local_datasource.dart'
    show SearchLocalDataSource;
export '../repositories/search_repository.dart' show SearchRepository;

// ============================================================================
// DATA SOURCE PROVIDERS
// ============================================================================

/// Provider for SearchRemoteDataSource
final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>((ref) {
  return SearchRemoteDataSource(Supabase.instance.client);
});

/// Provider for SearchLocalDataSource
final searchLocalDataSourceProvider = Provider<SearchLocalDataSource>((ref) {
  return SearchLocalDataSource();
});

// ============================================================================
// REPOSITORY PROVIDER
// ============================================================================

/// Provider for SearchRepository
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(
    remoteDataSource: ref.read(searchRemoteDataSourceProvider),
    localDataSource: ref.read(searchLocalDataSourceProvider),
    connectivity: Connectivity(),
  );
});
