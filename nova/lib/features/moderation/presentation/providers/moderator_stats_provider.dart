// =====================================================================
// Moderator Stats Provider - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Stream personal moderator statistics
// Architecture: StreamProvider with periodic refresh
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nova/features/moderation/data/repositories/moderation_repository.dart';

/// Model for moderator statistics
class ModeratorStats {
  /// Reviews completed today
  final int reviewsToday;

  /// Reviews completed this week
  final int reviewsThisWeek;

  /// Total reviews all time
  final int totalReviews;

  /// Approval rate percentage (0-100)
  final double approvalRate;

  const ModeratorStats({
    required this.reviewsToday,
    required this.reviewsThisWeek,
    required this.totalReviews,
    required this.approvalRate,
  });

  factory ModeratorStats.fromJson(Map<String, dynamic> json) {
    return ModeratorStats(
      reviewsToday: json['reviews_today'] ?? 0,
      reviewsThisWeek: json['reviews_this_week'] ?? 0,
      totalReviews: json['total_reviews'] ?? 0,
      approvalRate: (json['approval_rate'] ?? 0.0).toDouble(),
    );
  }

  /// Empty stats (no reviews yet)
  static const ModeratorStats empty = ModeratorStats(
    reviewsToday: 0,
    reviewsThisWeek: 0,
    totalReviews: 0,
    approvalRate: 0.0,
  );
}

/// Provider for moderator statistics
///
/// Refreshes every 30 seconds to show updated stats after moderation actions.
/// Uses periodic stream to avoid excessive database calls.
final moderatorStatsProvider = StreamProvider.autoDispose<ModeratorStats>((ref) {
  final repository = ref.watch(moderationRepositoryProvider);

  // Initial fetch + periodic refresh every 30 seconds
  return Stream.periodic(
    const Duration(seconds: 30),
    (_) async {
      try {
        final statsJson = await repository.getModeratorStats();
        return ModeratorStats.fromJson(statsJson);
      } catch (e) {
        // Return empty stats on error (prevents crash)
        return ModeratorStats.empty;
      }
    },
  ).asyncMap((event) => event);
});
