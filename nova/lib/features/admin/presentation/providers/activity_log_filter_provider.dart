// =====================================================================
// Activity Log Filter Provider - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: State management for activity log filtering
// Architecture: StateProvider for filter state
// =====================================================================

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'activity_log_filter_provider.freezed.dart';

/// Activity log filter state
@freezed
class ActivityLogFilter with _$ActivityLogFilter {
  const factory ActivityLogFilter({
    /// Selected action type filter (null = all)
    /// Options: 'approved', 'rejected', 'promoted', 'removed'
    String? actionType,

    /// Start date for filtering (null = no start filter)
    DateTime? startDate,

    /// End date for filtering (null = no end filter)
    DateTime? endDate,
  }) = _ActivityLogFilter;
}

/// Provider for activity log filter state
///
/// Manages filtering options for activity log:
/// - Action type (approved, rejected, promoted, removed, or all)
/// - Date range (start and end dates)
final activityLogFilterProvider =
    StateProvider<ActivityLogFilter>((ref) => const ActivityLogFilter());
