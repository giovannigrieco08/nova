// Data Model: EventModel
// Feature: 003-events-feed
// Purpose: Data layer model with JSON serialization and Hive persistence

import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/event.dart';

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
  final DateTime eventDate;

  @HiveField(4)
  @JsonKey(name: 'event_time')
  final String eventTime; // Stored as HH:mm format

  @HiveField(5)
  @JsonKey(name: 'location')
  final String location;

  @HiveField(6)
  @JsonKey(name: 'cover_images')
  final List<String> coverImages; // Array of image URLs

  @HiveField(7)
  @JsonKey(name: 'creator_id')
  final String creatorId;

  @HiveField(8)
  @JsonKey(name: 'status')
  final String status; // pending, approved, rejected

  @HiveField(9)
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @HiveField(10)
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  // Optional nested creator profile (from Supabase joins)
  // Not stored in Hive - only used for display
  @JsonKey(name: 'creator', includeToJson: false, includeFromJson: true)
  final Map<String, dynamic>? creatorData;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.eventDate,
    required this.eventTime,
    required this.location,
    required this.coverImages,
    required this.creatorId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
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
      eventTime: entity.eventTime,
      location: entity.location,
      coverImages: entity.coverImages,
      creatorId: entity.creatorId,
      status: entity.status,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Convert data model to domain entity
  Event toEntity() {
    return Event(
      id: id,
      title: title,
      description: description,
      eventDate: eventDate,
      eventTime: eventTime,
      location: location,
      coverImages: coverImages,
      creatorId: creatorId,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// CopyWith for partial updates (useful for optimistic UI)
  EventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? eventDate,
    String? eventTime,
    String? location,
    List<String>? coverImages,
    String? creatorId,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? creatorData,
  }) {
    return EventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      eventDate: eventDate ?? this.eventDate,
      eventTime: eventTime ?? this.eventTime,
      location: location ?? this.location,
      coverImages: coverImages ?? this.coverImages,
      creatorId: creatorId ?? this.creatorId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      creatorData: creatorData ?? this.creatorData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'EventModel(id: $id, title: $title, eventDate: $eventDate, status: $status)';
  }
}
