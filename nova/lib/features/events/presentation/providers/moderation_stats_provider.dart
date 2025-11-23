// Riverpod Provider: ModerationStatsProvider
// Feature: 004-event-creation-moderation (US3 - Moderation Queue)
// Purpose: Provide moderation statistics for moderator dashboard
//
// Stats:
// - Total pending events
// - Average moderation time (created_at → moderated_at)
// - Events moderated today/this week/this month
// - Approval vs rejection rate
//
// RLS: moderators_view_all_events policy

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/event.dart';
import './repository_providers.dart';
import './moderation_queue_provider.dart';

/// Moderation statistics data class
class ModerationStats {
  /// Total pending events awaiting review
  final int totalPending;

  /// Events approved today
  final int approvedToday;

  /// Events rejected today
  final int rejectedToday;

  /// Events approved this week
  final int approvedThisWeek;

  /// Events approved this month
  final int approvedThisMonth;

  /// Average moderation time in hours (null if no data)
  final double? averageModerationTimeHours;

  /// Approval rate percentage (0-100)
  final double approvalRatePercent;

  /// Rejection rate percentage (0-100)
  final double rejectionRatePercent;

  const ModerationStats({
    required this.totalPending,
    required this.approvedToday,
    required this.rejectedToday,
    required this.approvedThisWeek,
    required this.approvedThisMonth,
    this.averageModerationTimeHours,
    required this.approvalRatePercent,
    required this.rejectionRatePercent,
  });

  /// Empty stats (for loading/error states)
  const ModerationStats.empty()
      : totalPending = 0,
        approvedToday = 0,
        rejectedToday = 0,
        approvedThisWeek = 0,
        approvedThisMonth = 0,
        averageModerationTimeHours = null,
        approvalRatePercent = 0,
        rejectionRatePercent = 0;
}

/// Provider for moderation statistics
///
/// Fetches all events and computes statistics client-side.
/// Future optimization: Move to Supabase Edge Function with aggregation.
///
/// Usage:
/// ```dart
/// final statsAsync = ref.watch(moderationStatsProvider);
/// statsAsync.when(
///   data: (stats) => StatsCard(stats),
///   loading: () => CircularProgressIndicator(),
///   error: (err, stack) => ErrorWidget(err),
/// );
/// ```
final moderationStatsProvider = FutureProvider<ModerationStats>((ref) async {
  final repository = ref.watch(eventRepositoryProvider);

  try {
    // Fetch all events (RLS restricts to moderator-accessible events)
    final pendingEvents = await repository.getPendingEvents();

    // Get approved/rejected events from last 30 days for stats
    // Note: This is client-side filtering. Move to server in Phase 8.
    // TODO(Phase-8): Add getModeratedEvents(startDate, endDate) to EventsRepository for server-side aggregation
    // Placeholder variables for future date filtering:
    // - startOfToday, startOfWeek, startOfMonth, thirtyDaysAgo
    final totalPending = pendingEvents.length;

    // Placeholder stats (requires additional repository methods)
    // These will be implemented in Phase 8 with proper analytics
    return ModerationStats(
      totalPending: totalPending,
      approvedToday: 0, // Requires new repository method
      rejectedToday: 0, // Requires new repository method
      approvedThisWeek: 0, // Requires new repository method
      approvedThisMonth: 0, // Requires new repository method
      averageModerationTimeHours: null, // Requires moderated_at timestamps
      approvalRatePercent: 0, // Requires historical data
      rejectionRatePercent: 0, // Requires historical data
    );
  } catch (e) {
    // If user is not a moderator, return empty stats
    return const ModerationStats.empty();
  }
});

/// Provider for moderation history (for detailed stats screen)
///
/// Fetches last 100 moderated events (approved + rejected) for analysis.
/// Used by ModeratorStatsScreen to show trends and patterns.
final moderationHistoryProvider = FutureProvider<List<Event>>((ref) async {
  // TODO(Phase-8): Add getModeratedEvents() to EventsRepository with query:
  // For now, return empty list as placeholder
  // Will be implemented in Phase 8 with proper query:
  // SELECT * FROM events
  // WHERE status IN ('approved', 'rejected')
  // AND moderated_at IS NOT NULL
  // ORDER BY moderated_at DESC
  // LIMIT 100

  try {
    return [];
  } catch (e) {
    return [];
  }
});

/// Provider for daily batch notification eligibility
///
/// Returns true if moderator should receive daily batch notification.
/// Checks:
/// 1. Pending events exist (> 0)
/// 2. Last notification was sent >24 hours ago
/// 3. Moderator has enabled moderation notifications
final dailyBatchNotificationEligibleProvider =
    FutureProvider<bool>((ref) async {
  final pendingCount = await ref.watch(pendingEventsCountProvider.future);

  // If no pending events, no notification needed
  if (pendingCount == 0) return false;

  // TODO(Phase-4): Check last notification timestamp from SharedPreferences (daily batch limit)
  // TODO(Phase-4): Check user notification preferences (allow moderators to opt out)
  // For now, return true if pending events exist
  return true;
});
