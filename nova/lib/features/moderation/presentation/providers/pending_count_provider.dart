// =====================================================================
// Pending Count Provider - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Derived provider that returns count of pending events
// Architecture: Computed from pendingEventsProvider
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'pending_events_provider.dart';

/// Provider for pending events count (badge indicator).
///
/// Derived from pendingEventsProvider - returns list.length.
/// Used in NovaBottomNavBar to show moderation queue badge.
final pendingCountProvider = Provider.autoDispose<AsyncValue<int>>((ref) {
  return ref.watch(pendingEventsProvider).whenData((events) => events.length);
});
