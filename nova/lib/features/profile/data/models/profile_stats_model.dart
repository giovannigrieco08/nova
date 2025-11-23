// Data Model: ProfileStatsModel
// Feature: 006-user-profile
// Purpose: Profile statistics data model with JSON serialization

import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/profile_stats.dart';

part 'profile_stats_model.g.dart';

/// Profile statistics data model
///
/// Returned by database function: get_profile_stats(user_id UUID)
/// See: supabase/migrations/006_user_profile_system.sql
@JsonSerializable()
class ProfileStatsModel {
  @JsonKey(name: 'events_created_count')
  final int eventsCreatedCount;

  @JsonKey(name: 'participations_count')
  final int participationsCount;

  ProfileStatsModel({
    required this.eventsCreatedCount,
    required this.participationsCount,
  });

  /// JSON deserialization (from Supabase RPC response)
  factory ProfileStatsModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileStatsModelFromJson(json);

  /// JSON serialization
  Map<String, dynamic> toJson() => _$ProfileStatsModelToJson(this);

  /// Convert from domain entity to data model
  factory ProfileStatsModel.fromEntity(ProfileStats entity) {
    return ProfileStatsModel(
      eventsCreatedCount: entity.eventsCreatedCount,
      participationsCount: entity.participationsCount,
    );
  }

  /// Convert data model to domain entity
  ProfileStats toEntity() {
    return ProfileStats(
      eventsCreatedCount: eventsCreatedCount,
      participationsCount: participationsCount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileStatsModel &&
          runtimeType == other.runtimeType &&
          eventsCreatedCount == other.eventsCreatedCount &&
          participationsCount == other.participationsCount;

  @override
  int get hashCode =>
      eventsCreatedCount.hashCode ^ participationsCount.hashCode;

  @override
  String toString() {
    return 'ProfileStatsModel(eventsCreated: $eventsCreatedCount, participations: $participationsCount)';
  }
}
