// Riverpod Providers: Repository Dependency Injection
// Feature: 004-event-creation-moderation
// Purpose: Provide repository instances with injected data sources
//
// Architecture:
// - Providers create singleton repository instances
// - Repositories are injected with data sources (remote + local)
// - Data sources are injected with Supabase client / Hive box
//
// Dependency Graph:
// Widget → Repository Provider → Repository → Data Source → Supabase/Hive

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/repositories/event_repository_interface.dart';
import '../../domain/repositories/notification_repository_interface.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/datasources/event_remote_datasource.dart';
import '../../data/datasources/event_local_datasource.dart';
import '../../data/datasources/notification_remote_datasource.dart';
import '../../data/models/event_draft.dart';
import './supabase_provider.dart';

// =============================================================================
// DATA SOURCE PROVIDERS
// =============================================================================

/// Provider for EventRemoteDataSource (Supabase REST API)
final eventRemoteDataSourceProvider = Provider<EventRemoteDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return EventRemoteDataSource(supabase);
});

/// Provider for EventLocalDataSource (Hive drafts)
final eventLocalDataSourceProvider = Provider<EventLocalDataSource>((ref) {
  final draftsBox = Hive.box<EventDraft>('event_drafts');
  return EventLocalDataSource(draftsBox);
});

/// Provider for NotificationRemoteDataSource (Supabase notifications table)
final notificationRemoteDataSourceProvider =
    Provider<NotificationRemoteDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return NotificationRemoteDataSource(supabase);
});

// =============================================================================
// REPOSITORY PROVIDERS (Main Dependency Injection)
// =============================================================================

/// Provider for EventRepository
///
/// Usage in widgets:
/// ```dart
/// class EventCreationScreen extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final repository = ref.watch(eventRepositoryProvider);
///     // Use repository to create event
///   }
/// }
/// ```
final eventRepositoryProvider = Provider<EventRepository>((ref) {
  final remoteDataSource = ref.watch(eventRemoteDataSourceProvider);
  final localDataSource = ref.watch(eventLocalDataSourceProvider);
  final supabase = ref.watch(supabaseClientProvider);

  return EventRepositoryImpl(
    remoteDataSource: remoteDataSource,
    localDataSource: localDataSource,
    supabase: supabase,
  );
});

/// Provider for NotificationRepository
///
/// Usage in widgets:
/// ```dart
/// final notificationsAsync = ref.watch(notificationsProvider);
/// notificationsAsync.when(
///   data: (notifications) => NotificationsList(notifications),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => ErrorWidget(err),
/// );
/// ```
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  final remoteDataSource = ref.watch(notificationRemoteDataSourceProvider);

  return NotificationRepositoryImpl(
    remoteDataSource: remoteDataSource,
  );
});

// =============================================================================
// UTILITY PROVIDERS (For common queries)
// =============================================================================

/// Provider for current user ID (from Supabase auth)
///
/// Returns null if user is not authenticated.
final currentUserIdProvider = Provider<String?>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return supabase.auth.currentUser?.id;
});

/// Provider for checking if current user is a moderator
///
/// This queries the user_roles table to check if user has 'moderator' or 'admin' role.
/// Returns false if user is not authenticated or not a moderator.
final isModeratorProvider = FutureProvider<bool>((ref) async {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) return false;

  try {
    final response = await supabase
        .from('user_roles')
        .select('role')
        .eq('user_id', userId)
        .in_('role', ['moderator', 'admin'])
        .maybeSingle();

    return response != null;
  } catch (e) {
    return false;
  }
});
