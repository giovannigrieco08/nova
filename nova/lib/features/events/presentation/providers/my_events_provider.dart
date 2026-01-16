// Riverpod Provider: MyEventsProvider
// Feature: 004-event-creation-moderation (US2 - Status Tracking)
// Purpose: Real-time stream of events created by current user (all statuses)
//
// Query: creator_id = auth.uid() ORDER BY created_at DESC
// RLS Policy: creators_view_own_events

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/core/providers/core_providers.dart';
import '../../domain/entities/event.dart';
import '../../data/models/event_model.dart';
import './repository_providers.dart';

/// Provider for events created by current user with real-time updates
///
/// Returns all events (pending, approved, rejected) sorted by created_at DESC.
/// Shows newest events first. Updates automatically when event status changes
/// (e.g., when moderator approves/rejects an event).
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
final myEventsProvider = StreamProvider.autoDispose<List<Event>>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null || userId.isEmpty) {
    return Stream.value([]);
  }

  // Real-time subscription to user's events
  return supabase
      .from('events')
      .stream(primaryKey: ['id'])
      .eq('creator_id', userId)
      .order('created_at', ascending: false)
      .map((data) {
        return data.map((json) => EventModel.fromJson(json).toEntity()).toList();
      });
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
