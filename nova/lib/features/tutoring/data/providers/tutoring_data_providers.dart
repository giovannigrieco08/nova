// Provider: Tutoring Data Providers
// Feature: 012-tutoring-system (Sistema Ripetizioni)
// Purpose: Data layer dependency injection providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../datasources/tutor_remote_datasource.dart';
import '../repositories/tutor_repository.dart';

export '../datasources/tutor_remote_datasource.dart';
export '../repositories/tutor_repository.dart';
export '../models/tutor_profile_model.dart' show TutorProfileWithAuthorData;

// ============================================================================
// DEPENDENCY INJECTION PROVIDERS
// ============================================================================

/// Supabase client provider (re-export for feature isolation)
final tutorSupabaseProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Current user ID provider (from auth state)
final tutorCurrentUserIdProvider = Provider<String?>((ref) {
  final supabase = ref.watch(tutorSupabaseProvider);
  return supabase.auth.currentUser?.id;
});

/// Tutor remote datasource provider
final tutorDatasourceProvider = Provider<TutorRemoteDataSource>((ref) {
  final supabase = ref.watch(tutorSupabaseProvider);
  return TutorRemoteDataSource(supabase);
});

/// Tutor repository provider
final tutorRepositoryProvider = Provider<TutorRepository>((ref) {
  final dataSource = ref.watch(tutorDatasourceProvider);
  return TutorRepository(dataSource);
});
