// Data Model: ProfileModel
// Feature: 002-profile-setup
// Purpose: Data layer model with JSON serialization and Hive persistence

import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/profile.dart';

part 'profile_model.g.dart';

@HiveType(typeId: 1) // Hive type adapter ID
@JsonSerializable()
class ProfileModel {
  @HiveField(0)
  @JsonKey(name: 'user_id')
  final String userId;

  @HiveField(1)
  @JsonKey(name: 'full_name')
  final String fullName;

  @HiveField(2)
  @JsonKey(name: 'class')
  final String? classValue;

  @HiveField(3)
  @JsonKey(name: 'pronouns')
  final String? pronouns;

  @HiveField(4)
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  @HiveField(5)
  @JsonKey(name: 'bio')
  final String? bio;

  @HiveField(6)
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @HiveField(7)
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  ProfileModel({
    required this.userId,
    required this.fullName,
    this.classValue,
    this.pronouns,
    this.avatarUrl,
    this.bio,
    required this.createdAt,
    required this.updatedAt,
  });

  /// JSON deserialization (from Supabase REST API)
  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);

  /// JSON serialization (to Supabase REST API)
  Map<String, dynamic> toJson() => _$ProfileModelToJson(this);

  /// Convert from domain entity to data model
  factory ProfileModel.fromEntity(Profile entity) {
    return ProfileModel(
      userId: entity.userId,
      fullName: entity.fullName,
      classValue: entity.classValue,
      pronouns: entity.pronouns,
      avatarUrl: entity.avatarUrl,
      bio: entity.bio,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    );
  }

  /// Convert data model to domain entity
  Profile toEntity() {
    return Profile(
      userId: userId,
      fullName: fullName,
      classValue: classValue,
      pronouns: pronouns,
      avatarUrl: avatarUrl,
      bio: bio,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  /// CopyWith for partial updates (useful for optimistic UI)
  ProfileModel copyWith({
    String? userId,
    String? fullName,
    String? classValue,
    String? pronouns,
    String? avatarUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileModel(
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      classValue: classValue ?? this.classValue,
      pronouns: pronouns ?? this.pronouns,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileModel &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() {
    return 'ProfileModel(userId: $userId, fullName: $fullName, class: $classValue)';
  }
}
