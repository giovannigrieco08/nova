import 'package:flutter/foundation.dart';

/// Types of user sanctions
enum SanctionType {
  warning('warning', 'Avvertimento'),
  suspension('suspension', 'Sospensione'),
  ban('ban', 'Ban permanente');

  const SanctionType(this.value, this.displayName);
  final String value;
  final String displayName;

  static SanctionType fromString(String value) {
    return SanctionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SanctionType.warning,
    );
  }
}

/// Model representing a user sanction/penalty
@immutable
class UserSanction {
  const UserSanction({
    required this.id,
    required this.userId,
    required this.type,
    required this.reason,
    this.relatedReportId,
    this.relatedContentType,
    this.relatedContentId,
    required this.issuedBy,
    required this.issuedAt,
    this.expiresAt,
    this.liftedAt,
    this.liftedBy,
    this.issuedByUser,
  });

  final String id;
  final String userId;
  final SanctionType type;
  final String reason;
  final String? relatedReportId;
  final String? relatedContentType;
  final String? relatedContentId;
  final String issuedBy;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final DateTime? liftedAt;
  final String? liftedBy;

  /// Optional: User info for who issued the sanction
  final SanctionIssuerInfo? issuedByUser;

  /// Whether this sanction is currently active
  bool get isActive {
    if (liftedAt != null) return false;
    if (expiresAt != null && DateTime.now().isAfter(expiresAt!)) return false;
    return true;
  }

  /// Whether this sanction has expired naturally
  bool get isExpired {
    if (liftedAt != null) return false;
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Whether this sanction was manually lifted
  bool get wasLifted => liftedAt != null;

  /// Create from Supabase JSON response
  factory UserSanction.fromJson(Map<String, dynamic> json) {
    return UserSanction(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: SanctionType.fromString(json['type'] as String),
      reason: json['reason'] as String,
      relatedReportId: json['related_report_id'] as String?,
      relatedContentType: json['related_content_type'] as String?,
      relatedContentId: json['related_content_id'] as String?,
      issuedBy: json['issued_by'] as String,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      liftedAt: json['lifted_at'] != null
          ? DateTime.parse(json['lifted_at'] as String)
          : null,
      liftedBy: json['lifted_by'] as String?,
      issuedByUser: json['issued_by_user'] != null
          ? SanctionIssuerInfo.fromJson(
              json['issued_by_user'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserSanction && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Information about who issued a sanction
@immutable
class SanctionIssuerInfo {
  const SanctionIssuerInfo({
    required this.fullName,
    this.username,
  });

  final String fullName;
  final String? username;

  factory SanctionIssuerInfo.fromJson(Map<String, dynamic> json) {
    return SanctionIssuerInfo(
      fullName: json['full_name'] as String,
      username: json['username'] as String?,
    );
  }
}
