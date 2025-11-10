// Riverpod Provider: MyEventsProvider
// Feature: 004-event-creation-moderation (US2 - Status Tracking)
// Purpose: Fetch events created by current user (all statuses)
//
// Query: creator_id = auth.uid() ORDER BY created_at DESC
// RLS Policy: creators_view_own_events

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/event.dart';
import './repository_providers.dart';

/// Provider for events created by current user
///
/// Returns all events (pending, approved, rejected) sorted by created_at DESC.
/// Shows newest events first.
///
/// Usage:
/// ```dart
/// final myEventsAsync = ref.watch(myEventsProvider);
/// myEventsAsync.when(
///   data: (events) => EventsList(events),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => ErrorWidget(err),
/// );
/// ```
final myEventsProvider = FutureProvider<List<Event>>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    throw Exception('User not authenticated');
  }

  return await repository.getMyEvents(userId);
});

/// Provider for co-organized events (where user is co-organizer)
///
/// Query: auth.uid() = ANY(co_organizers) ORDER BY created_at DESC
/// RLS Policy: coorganizers_view_events
final coOrganizedEventsProvider = FutureProvider<List<Event>>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    throw Exception('User not authenticated');
  }

  return await repository.getCoOrganizedEvents(userId);
});
