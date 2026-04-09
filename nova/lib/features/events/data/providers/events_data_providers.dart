// Data Layer Providers: Events Feature
// Purpose: Datasource and repository dependency injection for events
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
import 'package:nova/core/providers/core_providers.dart';

// 004-event-creation-moderation datasources & repositories
import '../datasources/event_remote_datasource.dart';
import '../datasources/event_local_datasource.dart';
import '../datasources/notification_remote_datasource.dart';
import '../models/event_draft.dart';
import '../repositories/event_repository.dart';
import '../repositories/notification_repository.dart';
import '../../domain/repositories/event_repository_interface.dart';
import '../../domain/repositories/notification_repository_interface.dart';

// 003-events-feed datasources & repositories
import '../data_sources/events_local_data_source.dart';
import '../data_sources/events_remote_data_source.dart';
import '../models/event_model.dart';
import '../repositories/events_repository.dart';
import '../../domain/entities/offline_action.dart';

// Re-export types so consumers can import from this single file
export '../datasources/event_remote_datasource.dart';
export '../datasources/event_local_datasource.dart';
export '../datasources/notification_remote_datasource.dart';
export '../models/event_draft.dart';
export '../repositories/event_repository.dart';
export '../repositories/notification_repository.dart';
export '../../domain/repositories/event_repository_interface.dart';
export '../../domain/repositories/notification_repository_interface.dart';
export '../data_sources/events_local_data_source.dart';
export '../data_sources/events_remote_data_source.dart';
export '../repositories/events_repository.dart';

// =============================================================================
// 004 - EVENT CREATION/MODERATION DATA SOURCE PROVIDERS
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
// 004 - EVENT CREATION/MODERATION REPOSITORY PROVIDERS
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
// 003 - EVENTS FEED DATA SOURCE PROVIDERS
// =============================================================================

/// Events cache Hive box provider
final eventsCacheBoxProvider = Provider<Box<EventModel>>((ref) {
  return Hive.box<EventModel>('events_cache');
});

/// Offline actions queue Hive box provider
final offlineActionsBoxProvider = Provider<Box<OfflineAction>>((ref) {
  return Hive.box<OfflineAction>('offline_actions_queue');
});

/// Events local data source provider
final eventsLocalDataSourceProvider = Provider<EventsLocalDataSource>((ref) {
  final eventsBox = ref.watch(eventsCacheBoxProvider);
  final offlineActionsBox = ref.watch(offlineActionsBoxProvider);
  return EventsLocalDataSource(
    eventsBox: eventsBox,
    offlineActionsBox: offlineActionsBox,
  );
});

/// Events remote data source provider
final eventsRemoteDataSourceProvider = Provider<EventsRemoteDataSource>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  return EventsRemoteDataSource(supabase: supabase);
});

// =============================================================================
// 003 - EVENTS FEED REPOSITORY PROVIDER
// =============================================================================

/// Events repository provider
final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  final localDataSource = ref.watch(eventsLocalDataSourceProvider);
  final remoteDataSource = ref.watch(eventsRemoteDataSourceProvider);
  return EventsRepository(
    localDataSource: localDataSource,
    remoteDataSource: remoteDataSource,
  );
});
