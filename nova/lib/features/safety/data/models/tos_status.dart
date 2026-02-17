import 'package:flutter/foundation.dart';

/// Model representing the Terms of Service acceptance status
@immutable
class TosStatus {
  const TosStatus({
    required this.hasAccepted,
    this.acceptedVersion,
    required this.currentVersion,
    required this.needsReaccept,
    this.acceptedAt,
  });

  /// Whether the user has ever accepted the ToS
  final bool hasAccepted;

  /// Version the user accepted (null if never accepted)
  final String? acceptedVersion;

  /// Current ToS version required
  final String currentVersion;

  /// True if user needs to re-accept due to version change
  final bool needsReaccept;

  /// When the user accepted (null if never accepted)
  final DateTime? acceptedAt;

  /// Whether the user can create content (has accepted and doesn't need re-accept)
  bool get canCreateContent => hasAccepted && !needsReaccept;

  /// Create from Supabase RPC response
  factory TosStatus.fromJson(Map<String, dynamic> json) {
    return TosStatus(
      hasAccepted: json['has_accepted'] as bool? ?? false,
      acceptedVersion: json['accepted_version'] as String?,
      currentVersion: json['current_version'] as String? ?? '1.0.0',
      needsReaccept: json['needs_reaccept'] as bool? ?? true,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.parse(json['accepted_at'] as String)
          : null,
    );
  }

  /// Create an initial status for new users (not accepted)
  factory TosStatus.initial() {
    return const TosStatus(
      hasAccepted: false,
      acceptedVersion: null,
      currentVersion: '1.0.0',
      needsReaccept: true,
      acceptedAt: null,
    );
  }

  /// Create a copy with modified fields
  TosStatus copyWith({
    bool? hasAccepted,
    String? acceptedVersion,
    String? currentVersion,
    bool? needsReaccept,
    DateTime? acceptedAt,
  }) {
    return TosStatus(
      hasAccepted: hasAccepted ?? this.hasAccepted,
      acceptedVersion: acceptedVersion ?? this.acceptedVersion,
      currentVersion: currentVersion ?? this.currentVersion,
      needsReaccept: needsReaccept ?? this.needsReaccept,
      acceptedAt: acceptedAt ?? this.acceptedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TosStatus &&
        other.hasAccepted == hasAccepted &&
        other.acceptedVersion == acceptedVersion &&
        other.currentVersion == currentVersion &&
        other.needsReaccept == needsReaccept;
  }

  @override
  int get hashCode => Object.hash(
        hasAccepted,
        acceptedVersion,
        currentVersion,
        needsReaccept,
      );
}

/// Response from accept_tos RPC
@immutable
class TosAcceptResponse {
  const TosAcceptResponse({
    required this.success,
    required this.acceptedVersion,
    required this.acceptedAt,
  });

  final bool success;
  final String acceptedVersion;
  final DateTime acceptedAt;

  factory TosAcceptResponse.fromJson(Map<String, dynamic> json) {
    return TosAcceptResponse(
      success: json['success'] as bool,
      acceptedVersion: json['accepted_version'] as String,
      acceptedAt: DateTime.parse(json['accepted_at'] as String),
    );
  }
}
