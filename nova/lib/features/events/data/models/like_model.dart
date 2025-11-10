// Data Model: LikeModel
// Feature: 003-events-feed
// Purpose: Junction table model for event likes (no separate domain entity needed)

import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';

part 'like_model.g.dart';

@HiveType(typeId: 5) // Hive type adapter ID
@JsonSerializable()
class LikeModel {
  @HiveField(0)
  @JsonKey(name: 'user_id')
  final String userId;

  @HiveField(1)
  @JsonKey(name: 'event_id')
  final String eventId;

  @HiveField(2)
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  LikeModel({
    required this.userId,
    required this.eventId,
    required this.createdAt,
  });

  /// JSON deserialization (from Supabase REST API)
  factory LikeModel.fromJson(Map<String, dynamic> json) =>
      _$LikeModelFromJson(json);

  /// JSON serialization (to Supabase REST API)
  Map<String, dynamic> toJson() => _$LikeModelToJson(this);

  /// Create new like (for optimistic UI)
  factory LikeModel.create({
    required String userId,
    required String eventId,
  }) {
    return LikeModel(
      userId: userId,
      eventId: eventId,
      createdAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LikeModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId &&
          eventId == other.eventId;

  @override
  int get hashCode => Object.hash(userId, eventId);

  @override
  String toString() {
    return 'LikeModel(userId: $userId, eventId: $eventId, createdAt: $createdAt)';
  }
}
