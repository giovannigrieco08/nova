// Data Model: ParticipationModel
// Feature: 003-events-feed
// Purpose: Junction table model for event participations/RSVPs (no separate domain entity needed)

import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'participation_model.g.dart';

@HiveType(typeId: 6) // Hive type adapter ID
@JsonSerializable()
class ParticipationModel {
  @HiveField(0)
  @JsonKey(name: 'user_id')
  final String userId;

  @HiveField(1)
  @JsonKey(name: 'event_id')
  final String eventId;

  @HiveField(2)
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  ParticipationModel({
    required this.userId,
    required this.eventId,
    required this.createdAt,
  });

  /// JSON deserialization (from Supabase REST API)
  factory ParticipationModel.fromJson(Map<String, dynamic> json) =>
      _$ParticipationModelFromJson(json);

  /// JSON serialization (to Supabase REST API)
  Map<String, dynamic> toJson() => _$ParticipationModelToJson(this);

  /// Create new participation (for optimistic UI)
  factory ParticipationModel.create({
    required String userId,
    required String eventId,
  }) {
    return ParticipationModel(
      userId: userId,
      eventId: eventId,
      createdAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParticipationModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          eventId == other.eventId;

  @override
  int get hashCode => Object.hash(userId, eventId);

  @override
  String toString() {
    return 'ParticipationModel(userId: $userId, eventId: $eventId, createdAt: $createdAt)';
  }
}
