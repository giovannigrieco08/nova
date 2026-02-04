// Data Model: EventModel
// Feature: 004-event-creation-moderation (Updated from 003-events-feed)
// Purpose: Data layer model with JSON serialization and Hive persistence
// Schema: Unified schema from migration 005

import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_status.dart';

part 'event_model.g.dart';

@HiveType(typeId: 2) // Hive type adapter ID
@JsonSerializable()
class EventModel {
  @HiveField(0)
  @JsonKey(name: 'id')
  final String id;

  @HiveField(1)
  @JsonKey(name: 'title')
  final String title;

  @HiveField(2)
  @JsonKey(name: 'description')
  final String description;

  @HiveField(3)
  @JsonKey(name: 'event_date')
  final DateTime eventDate; // TIMESTAMPTZ (merged date+time)

  @HiveField(4)
  @JsonKey(name: 'location')
  final String? location; // Optional

  @HiveField(5)
  @JsonKey(name: 'image_url')
  final String? imageUrl; // Single image URL (optional)

  @HiveField(6)
  @JsonKey(name: 'creator_id')
  final String creatorId;

  @HiveField(7)
  @JsonKey(name: 'co_organizers')
  final List<String> coOrganizers; // Array of user IDs

  @HiveField(8)
  @JsonKey(name: 'status')
  final String status; // pending, approved, rejected

  @HiveField(9)
  @JsonKey(name: 'rejection_reason')
  final String? rejectionReason;

  @HiveField(10)
  @JsonKey(name: 'moderated_by')
  final String? moderatedBy;

  @HiveField(11)
  @JsonKey(name: 'moderated_at')
  final DateTime? moderatedAt;

  @HiveField(12)
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @HiveField(13)
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  // =========================================================================
  // MAP LOCATION (GPS coordinates for Maps integration)
  // =========================================================================

  @HiveField(14)
  @JsonKey(name: 'latitude')
  final double? latitude;

  @HiveField(15)
  @JsonKey(name: 'longitude')
  final double? longitude;

  @HiveField(16)
  @JsonKey(name: 'place_id')
  final String? placeId;

  // Optional nested creator profile (from Supabase joins)
  // Not stored in Hive - only used for display
  @JsonKey(name: 'creator', includeToJson: false, includeFromJson: true)
  final Map<String, dynamic>? creatorData;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.eventDate,
    this.location,
    this.imageUrl,
    required this.creatorId,
    required this.coOrganizers,
    required this.status,
    this.rejectionReason,
    this.moderatedBy,
    this.moderatedAt,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.placeId,
    this.creatorData,
  });

  /// JSON deserialization (from Supabase REST API)
  factory EventModel.fromJson(Map<String, dynamic> json) =>
      _$EventModelFromJson(json);

  /// JSON serialization (to Supabase REST API)
  Map<String, dynamic> toJson() => _$EventModelToJson(this);

  /// Convert from domain entity to data model
  factory EventModel.fromEntity(Event entity) {
    return EventModel(
      id: entity.id,
      title: entity.title,
      description: entity.description,
      eventDate: entity.eventDate,
      location: entity.location,
      imageUrl: entity.imageUrl,
      creatorId: entity.creatorId,
      coOrganizers: entity.coOrganizers,
      status: entity.status.name, // Convert EventStatus enum to String
      rejectionReason: entity.rejectionReason,
      moderatedBy: entity.moderatedBy,
      moderatedAt: entity.moderatedAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      latitude: entity.latitude,
      longitude: entity.longitude,
      placeId: entity.placeId,
    );
  }

  /// Convert data model to domain entity
  Event toEntity() {
    // Extract creator info from joined profile data
    final creatorName = creatorData?['full_name'] as String?;
    final creatorClass = creatorData?['class'] as String?;
    final creatorAvatarUrl = creatorData?['avatar_url'] as String?;

    return Event(
      id: id,
      title: title,
      description: description,
      eventDate: eventDate,
      location: location,
      imageUrl: imageUrl,
      creatorId: creatorId,
      coOrganizers: coOrganizers,
      status: EventStatus.values
          .byName(status), // Convert String to EventStatus enum
      rejectionReason: rejectionReason,
      moderatedBy: moderatedBy,
      moderatedAt: moderatedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      creatorName: creatorName,
      creatorClass: creatorClass,
      creatorAvatarUrl: creatorAvatarUrl,
      latitude: latitude,
      longitude: longitude,
      placeId: placeId,
    );
  }

  /// CopyWith for partial updates (useful for optimistic UI)
  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? eventDate,
    String? location,
    String? imageUrl,
    String? creatorId,
    List<String>? coOrganizers,
    String? status,
    String? rejectionReason,
    String? moderatedBy,
    DateTime? moderatedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? latitude,
    double? longitude,
    String? placeId,
    Map<String, dynamic>? creatorData,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      eventDate: eventDate ?? this.eventDate,
      location: location ?? this.location,
      imageUrl: imageUrl ?? this.imageUrl,
      creatorId: creatorId ?? this.creatorId,
      coOrganizers: coOrganizers ?? this.coOrganizers,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      moderatedBy: moderatedBy ?? this.moderatedBy,
      moderatedAt: moderatedAt ?? this.moderatedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      placeId: placeId ?? this.placeId,
      creatorData: creatorData ?? this.creatorData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'EventModel(id: $id, title: $title, eventDate: $eventDate, status: $status)';
  }
}
