// =====================================================================
// Rejected Events Provider - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Fetch rejected events for current user to enable re-submission
// Architecture: FutureProvider filtering myEvents by rejected status
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/features/events/domain/entities/event.dart';
import 'package:nova/features/events/domain/entities/event_status.dart';
import 'package:nova/features/events/presentation/providers/my_events_provider.dart';

/// Provider for rejected events created by current user
///
/// Filters myEventsProvider to return only events with status=rejected.
/// Shows events that can be edited and re-submitted for moderation.
///
/// Usage:
/// ```dart
/// final rejectedEventsAsync = ref.watch(rejectedEventsProvider);
/// rejectedEventsAsync.when(
///   data: (events) => RejectedEventsList(events),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => ErrorWidget(err),
/// );
/// ```
final rejectedEventsProvider = FutureProvider<List<Event>>((ref) async {
  // Watch myEventsProvider to get all user events
  final allEvents = await ref.watch(myEventsProvider.future);

  // Filter to only rejected events
  return allEvents
      .where((event) => event.status == EventStatus.rejected)
      .toList();
});
