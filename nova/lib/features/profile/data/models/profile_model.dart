// Data Model: ProfileModel
// Feature: 006-user-profile
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
  @JsonKey(name: 'email')
  final String email;

  @HiveField(2)
  @JsonKey(name: 'full_name')
  final String fullName;

  @HiveField(3)
  @JsonKey(name: 'username')
  final String username;

  @HiveField(4)
  @JsonKey(name: 'class')
  final String? classYear;

  @HiveField(5)
  @JsonKey(name: 'avatar_url')
  final String? avatarUrl;

  @HiveField(12)
  @JsonKey(name: 'banner_url')
  final String? bannerUrl;

  @HiveField(6)
  @JsonKey(name: 'bio')
  final String? bio;

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
  @JsonKey(name: 'updated_at')
  final DateTime updatedAt;

  @HiveField(11)
  @JsonKey(name: 'deleted_at')
  final DateTime? deletedAt;

  ProfileModel({
    required this.userId,
    required this.email,
    required this.fullName,
    required this.username,
    this.classYear,
    this.avatarUrl,
    this.bannerUrl,
    this.bio,
    this.role = 'student',
    this.profileVisible = true,
    required this.createdAt,
    required this.updatedAt,
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
      userId: entity.userId,
      email: entity.email,
      fullName: entity.fullName,
      username: entity.username,
      classYear: entity.classYear,
      avatarUrl: entity.avatarUrl,
      bannerUrl: entity.bannerUrl,
      bio: entity.bio,
      role: entity.role,
      profileVisible: entity.profileVisible,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      deletedAt: entity.deletedAt,
    );
  }

  /// Convert data model to domain entity
  Profile toEntity() {
    return Profile(
      userId: userId,
      email: email,
      fullName: fullName,
      username: username,
      classYear: classYear,
      avatarUrl: avatarUrl,
      bannerUrl: bannerUrl,
      bio: bio,
      role: role,
      profileVisible: profileVisible,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  /// CopyWith for partial updates (useful for optimistic UI)
  ProfileModel copyWith({
    String? userId,
    String? email,
    String? fullName,
    String? username,
    String? classYear,
    String? avatarUrl,
    String? bannerUrl,
    String? bio,
    String? role,
    bool? profileVisible,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) {
    return ProfileModel(
      userId: userId ?? this.userId,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      classYear: classYear ?? this.classYear,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      profileVisible: profileVisible ?? this.profileVisible,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
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
    return 'ProfileModel(userId: $userId, fullName: $fullName, username: $username)';
  }
}
