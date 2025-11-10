// Data Model: CommentModel
// Feature: 003-events-feed
// Purpose: Data layer model with JSON serialization and Hive persistence

import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/comment.dart';

part 'comment_model.g.dart';

@HiveType(typeId: 4) // Hive type adapter ID
@JsonSerializable()
class CommentModel {
  @HiveField(0)
  @JsonKey(name: 'id')
  final String id;

  @HiveField(1)
  @JsonKey(name: 'event_id')
  final String eventId;

  @HiveField(2)
  @JsonKey(name: 'author_id')
  final String authorId;

  @HiveField(3)
  @JsonKey(name: 'content') // Changed from 'text' to 'content' to match DB schema
  final String content; // Max 500 characters

  @HiveField(4)
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  // Optional nested author profile (from Supabase joins)
  // Not stored in Hive - only used for display
  @JsonKey(name: 'author', includeToJson: false, includeFromJson: true)
  final Map<String, dynamic>? authorData;

  CommentModel({
    required this.id,
    required this.eventId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.authorData,
  });

  /// JSON deserialization (from Supabase REST API)
  factory CommentModel.fromJson(Map<String, dynamic> json) =>
      _$CommentModelFromJson(json);

  /// JSON serialization (to Supabase REST API)
  Map<String, dynamic> toJson() => _$CommentModelToJson(this);

  /// Convert from domain entity to data model
  factory CommentModel.fromEntity(Comment entity) {
    return CommentModel(
      id: entity.id,
      eventId: entity.eventId,
      authorId: entity.authorId,
      content: entity.content,
      createdAt: entity.createdAt,
    );
  }

  /// Convert data model to domain entity
  Comment toEntity() {
    // Extract author data if present
    String? authorName;
    String? authorAvatarUrl;
    String? authorClass;

    if (authorData != null) {
      authorName = authorData!['full_name'] as String?; // Changed from 'name' to 'full_name' to match profiles table
      authorAvatarUrl = authorData!['avatar_url'] as String?;
      authorClass = authorData!['class'] as String?;
    }

    return Comment(
      id: id,
      eventId: eventId,
      authorId: authorId,
      content: content,
      createdAt: createdAt,
      authorName: authorName,
      authorAvatarUrl: authorAvatarUrl,
      authorClass: authorClass,
    );
  }

  /// CopyWith for partial updates (useful for optimistic UI)
  CommentModel copyWith({
    String? id,
    String? eventId,
    String? authorId,
    String? content,
    DateTime? createdAt,
    Map<String, dynamic>? authorData,
  }) {
    return CommentModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      authorData: authorData ?? this.authorData,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommentModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CommentModel(id: $id, eventId: $eventId, authorId: $authorId, createdAt: $createdAt)';
  }
}
