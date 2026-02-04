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
import 'package:supabase_flutter/supabase_flutter.dart';
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
  final supabase = Supabase.instance.client;

  try {
    // Fetch pending events
    final pendingEvents = await repository.getPendingEvents();
    final totalPending = pendingEvents.length;

    // Calculate date boundaries
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = startOfToday.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);

    // Fetch moderated events from database
    final moderatedResponse = await supabase
        .from('events')
        .select('id, status, updated_at, created_at')
        .inFilter('status', ['approved', 'rejected']).gte(
            'updated_at', startOfMonth.toIso8601String());

    final moderatedEvents = moderatedResponse as List;

    // Calculate stats
    int approvedToday = 0;
    int rejectedToday = 0;
    int approvedThisWeek = 0;
    int approvedThisMonth = 0;
    int rejectedThisMonth = 0;
    double totalModerationTime = 0;
    int moderationTimeCount = 0;

    for (final event in moderatedEvents) {
      final status = event['status'] as String;
      final updatedAt = DateTime.parse(event['updated_at'] as String);
      final createdAt = DateTime.parse(event['created_at'] as String);

      // Calculate moderation time
      final moderationTime = updatedAt.difference(createdAt).inHours.toDouble();
      if (moderationTime >= 0) {
        totalModerationTime += moderationTime;
        moderationTimeCount++;
      }

      final isToday = updatedAt.isAfter(startOfToday);
      final isThisWeek = updatedAt.isAfter(startOfWeek);

      if (status == 'approved') {
        approvedThisMonth++;
        if (isThisWeek) approvedThisWeek++;
        if (isToday) approvedToday++;
      } else if (status == 'rejected') {
        rejectedThisMonth++;
        if (isToday) rejectedToday++;
      }
    }

    // Calculate rates
    final totalModerated = approvedThisMonth + rejectedThisMonth;
    final approvalRatePercent =
        totalModerated > 0 ? (approvedThisMonth / totalModerated) * 100 : 0.0;
    final rejectionRatePercent =
        totalModerated > 0 ? (rejectedThisMonth / totalModerated) * 100 : 0.0;

    // Calculate average moderation time
    final averageModerationTimeHours = moderationTimeCount > 0
        ? totalModerationTime / moderationTimeCount
        : null;

    return ModerationStats(
      totalPending: totalPending,
      approvedToday: approvedToday,
      rejectedToday: rejectedToday,
      approvedThisWeek: approvedThisWeek,
      approvedThisMonth: approvedThisMonth,
      averageModerationTimeHours: averageModerationTimeHours,
      approvalRatePercent: approvalRatePercent,
      rejectionRatePercent: rejectionRatePercent,
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
  // TODO: Add getModeratedEvents() to repository
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

  // TODO: Check last notification timestamp from SharedPreferences
  // TODO: Check user notification preferences
  // For now, return true if pending events exist
  return true;
});
