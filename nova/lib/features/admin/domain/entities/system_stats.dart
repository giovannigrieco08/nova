// =====================================================================
// SystemStats Entity - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: System-wide statistics for Admin Panel dashboard
// Architecture: Freezed entity mapping to get_system_statistics() RPC
// =====================================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'system_stats.freezed.dart';
part 'system_stats.g.dart';

/// System-wide statistics
///
/// Maps to output of get_system_statistics() database function.
/// Used in Admin Panel to display overall system health and moderation metrics.
@freezed
class SystemStats with _$SystemStats {
  const factory SystemStats({
    @Default(0) int totalEvents,
    @Default(0) int pendingEvents,
    @Default(0) int approvedEvents,
    @Default(0) int rejectedEvents,
    @Default(0) int totalModerators,
    @Default(0) int activeModerators, // Reviewed in last 7 days
    @Default(0.0) double avgReviewTimeHours,
    @Default(0) int eventsOlderThan24h, // Backlog - highlighted in red if >0
  }) = _SystemStats;

  factory SystemStats.fromJson(Map<String, dynamic> json) =>
      _$SystemStatsFromJson(json);
}

/// Extension methods for SystemStats convenience
extension SystemStatsX on SystemStats {
  /// Calculate approval rate as percentage
  double get approvalRatePercent {
    final reviewed = approvedEvents + rejectedEvents;
    if (reviewed == 0) return 0.0;
    return (approvedEvents / reviewed) * 100;
  }

  /// Whether there's a critical backlog (>10 events older than 24h)
  bool get hasBacklogCrisis => eventsOlderThan24h > 10;
}
