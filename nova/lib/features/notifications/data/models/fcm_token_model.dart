// =====================================================================
// FCM Token Model - Push Notifications Feature (009)
// =====================================================================
// Purpose: Data model with JSON serialization for Supabase
// Maps to: fcm_tokens table
// =====================================================================

import '../../domain/entities/fcm_token.dart';

/// FCM Token data model with JSON serialization
///
/// Used for Supabase API communication.
class FcmTokenModel {
  final String id;
  final String userId;
  final String token;
  final String platform;
  final String? deviceName;
  final DateTime createdAt;
  final DateTime lastUsedAt;

  const FcmTokenModel({
    required this.id,
    required this.userId,
    required this.token,
    required this.platform,
    this.deviceName,
    required this.createdAt,
    required this.lastUsedAt,
  });

  /// Create from Supabase JSON response
  factory FcmTokenModel.fromJson(Map<String, dynamic> json) => FcmTokenModel(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        token: json['token'] as String,
        platform: json['platform'] as String,
        deviceName: json['device_name'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        lastUsedAt: DateTime.parse(json['last_used_at'] as String),
      );

  /// Convert to JSON for Supabase insert/update
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'token': token,
        'platform': platform,
        'device_name': deviceName,
        'created_at': createdAt.toIso8601String(),
        'last_used_at': lastUsedAt.toIso8601String(),
      };

  /// Convert to JSON for upsert (without id - let DB generate)
  Map<String, dynamic> toInsertJson() => {
        'user_id': userId,
        'token': token,
        'platform': platform,
        if (deviceName != null) 'device_name': deviceName,
      };

  /// Create from domain entity
  factory FcmTokenModel.fromEntity(FcmToken entity) => FcmTokenModel(
        id: entity.id,
        userId: entity.userId,
        token: entity.token,
        platform: entity.platform,
        deviceName: entity.deviceName,
        createdAt: entity.createdAt,
        lastUsedAt: entity.lastUsedAt,
      );

  /// Convert to domain entity
  FcmToken toEntity() => FcmToken(
        id: id,
        userId: userId,
        token: token,
        platform: platform,
        deviceName: deviceName,
        createdAt: createdAt,
        lastUsedAt: lastUsedAt,
      );
}
