// Domain Entity: ProfileStats
// Feature: 006-user-profile
// Purpose: Profile statistics computed from events and participations

import 'package:freezed_annotation/freezed_annotation.dart';

part 'profile_stats.freezed.dart';
part 'profile_stats.g.dart';

/// Profile statistics entity
///
/// Computed via database function: get_profile_stats(user_id UUID)
/// See: supabase/migrations/006_user_profile_system.sql
///
/// Fields:
/// - [eventsCreatedCount]: Number of approved events created by user
/// - [participationsCount]: Number of events user has joined
@freezed
class ProfileStats with _$ProfileStats {
  const factory ProfileStats({
    /// Number of approved events created by this user
    /// (only counts events with status = 'approved')
    @Default(0) int eventsCreatedCount,

    /// Number of events this user has participated in
    /// (total count from participations table)
    @Default(0) int participationsCount,
  }) = _ProfileStats;

  const ProfileStats._();

  factory ProfileStats.fromJson(Map<String, dynamic> json) =>
      _$ProfileStatsFromJson(json);

  /// Empty stats (0 events, 0 participations) for new users
  static const empty = ProfileStats(
    eventsCreatedCount: 0,
    participationsCount: 0,
  );

  /// Whether user has created any approved events
  bool get hasCreatedEvents => eventsCreatedCount > 0;

  /// Whether user has participated in any events
  bool get hasParticipations => participationsCount > 0;

  /// Whether user has any activity (events or participations)
  bool get hasActivity => hasCreatedEvents || hasParticipations;

  /// Total activity count (events + participations)
  int get totalActivityCount => eventsCreatedCount + participationsCount;
}
