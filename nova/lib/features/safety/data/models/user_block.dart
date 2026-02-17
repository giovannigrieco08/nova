import 'package:flutter/foundation.dart';

/// Model representing a user block relationship
@immutable
class UserBlock {
  const UserBlock({
    required this.id,
    required this.blockerId,
    required this.blockedId,
    required this.createdAt,
    this.moderatorNotified = false,
    this.notifiedAt,
    this.blockedUser,
  });

  final String id;
  final String blockerId;
  final String blockedId;
  final DateTime createdAt;
  final bool moderatorNotified;
  final DateTime? notifiedAt;

  /// Optional: Blocked user profile info (from join)
  final BlockedUserInfo? blockedUser;

  /// Create from Supabase JSON response
  factory UserBlock.fromJson(Map<String, dynamic> json) {
    return UserBlock(
      id: json['id'] as String,
      blockerId: json['blocker_id'] as String,
      blockedId: json['blocked_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      moderatorNotified: json['moderator_notified'] as bool? ?? false,
      notifiedAt: json['notified_at'] != null
          ? DateTime.parse(json['notified_at'] as String)
          : null,
      blockedUser: json['blocked'] != null
          ? BlockedUserInfo.fromJson(json['blocked'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Convert to JSON for Supabase insert
  Map<String, dynamic> toJson() {
    return {
      'blocker_id': blockerId,
      'blocked_id': blockedId,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserBlock && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Blocked user profile information
@immutable
class BlockedUserInfo {
  const BlockedUserInfo({
    required this.userId,
    required this.fullName,
    this.username,
    this.avatarUrl,
  });

  final String userId;
  final String fullName;
  final String? username;
  final String? avatarUrl;

  factory BlockedUserInfo.fromJson(Map<String, dynamic> json) {
    return BlockedUserInfo(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String,
      username: json['username'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
