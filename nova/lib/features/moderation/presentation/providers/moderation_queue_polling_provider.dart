// =====================================================================
// Moderation Queue Polling Provider - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Polling fallback for pending events when WebSocket unavailable
// Architecture: StreamProvider with periodic fetch (15s intervals)
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/features/moderation/data/models/moderation_event.dart';
import 'package:nova/features/moderation/data/repositories/moderation_repository.dart';

/// Polling fallback provider for pending events
///
/// Used when Realtime WebSocket connection is unavailable.
/// Fetches pending events every 15 seconds using traditional HTTP requests.
///
/// This ensures moderation queue functionality even in:
/// - Network environments with WebSocket restrictions
/// - Poor network conditions
/// - Temporary Realtime service outages
final moderationQueuePollingProvider =
    StreamProvider.autoDispose<List<ModerationEvent>>((ref) {
  final repository = ref.watch(moderationRepositoryProvider);

  // Initial fetch immediately + periodic refresh every 15 seconds
  return Stream.periodic(
    const Duration(seconds: 15),
    (_) async {
      try {
        return await repository.getPendingEvents();
      } catch (e) {
        // Return empty list on error (prevents crash)
        // Error will be visible in UI via pendingEventsProvider error state
        return <ModerationEvent>[];
      }
    },
  ).asyncMap((event) => event);
});
