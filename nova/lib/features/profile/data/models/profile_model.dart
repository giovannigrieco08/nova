// Data Model: ProfileModel
// Feature: 006-user-profile (evolved from 002-profile-setup)
// Purpose: Data layer model with JSON serialization and Hive persistence

import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import '../../domain/entities/profile.dart';

part 'profile_model.g.dart';

/// Profile data model matching database schema
///
/// Schema: supabase/migrations/006_user_profile_system.sql (profiles table)
/// JSON keys match PostgreSQL column names (snake_case)
@HiveType(typeId: 0) // Hive type adapter ID
@JsonSerializable()
class ProfileModel {
  @HiveField(0)
  @JsonKey(name: 'id')
  final String id;

  @HiveField(1)
  @JsonKey(name: 'email')
  final String email;

  @HiveField(2)
  @JsonKey(name: 'full_name')
  final String? fullName;

  @HiveField(3)
  @JsonKey(name: 'username')
  final String username;

  @HiveField(4)
  @JsonKey(name: 'class')
  final String? classYear;

  @HiveField(5)
  @JsonKey(name: 'bio')
  final String? bio;

  @HiveField(6)
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  @HiveField(7)
  @JsonKey(name: 'role')
  final String role;

  @HiveField(8)
  @JsonKey(name: 'profile_visible')
  final bool profileVisible;

  @HiveField(9)
  @JsonKey(name: 'created_at')
  final DateTime createdAt;

  @HiveField(10)
  @JsonKey(name: 'deleted_at')
  final DateTime? deletedAt;

  ProfileModel({
    required this.id,
    required this.email,
    this.fullName,
    required this.username,
    this.classYear,
    this.bio,
    this.avatarUrl,
    required this.role,
    required this.profileVisible,
    required this.createdAt,
    this.deletedAt,
  });

  /// JSON deserialization (from Supabase REST API)
  factory ProfileModel.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelFromJson(json);

  /// JSON serialization (to Supabase REST API)
  Map<String, dynamic> toJson() => _$ProfileModelToJson(this);

  /// Convert from domain entity to data model
  factory ProfileModel.fromEntity(Profile entity) {
    return ProfileModel(
      id: entity.id,
      email: entity.email,
      fullName: entity.fullName,
      username: entity.username,
      classYear: entity.classYear,
      bio: entity.bio,
      avatarUrl: entity.avatarUrl,
      role: entity.role,
      profileVisible: entity.profileVisible,
      createdAt: entity.createdAt,
      deletedAt: entity.deletedAt,
    );
  }

  /// Convert data model to domain entity
  Profile toEntity() {
    return Profile(
      id: id,
      email: email,
      fullName: fullName,
      username: username,
      classYear: classYear,
      bio: bio,
      avatarUrl: avatarUrl,
      role: role,
      profileVisible: profileVisible,
      createdAt: createdAt,
      deletedAt: deletedAt,
    );
  }

  /// CopyWith for partial updates (useful for optimistic UI)
  ProfileModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? username,
    String? classYear,
    String? bio,
    String? avatarUrl,
    String? role,
    bool? profileVisible,
    DateTime? createdAt,
    DateTime? deletedAt,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      classYear: classYear ?? this.classYear,
      bio: bio ?? this.bio,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role ?? this.role,
      profileVisible: profileVisible ?? this.profileVisible,
      createdAt: createdAt ?? this.createdAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'ProfileModel(id: $id, username: $username, fullName: $fullName, class: $classYear)';
  }
}
