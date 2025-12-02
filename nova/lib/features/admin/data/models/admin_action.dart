// =====================================================================
// AdminAction Model - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Map to admin_log table for audit trail
// Architecture: Freezed model with JSON serialization
// =====================================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_action.freezed.dart';
part 'admin_action.g.dart';

/// Admin action log entry
///
/// Maps to admin_log table tracking role changes:
/// - promote_to_moderator
/// - remove_moderator_role
@freezed
class AdminAction with _$AdminAction {
  const factory AdminAction({
    required String id,
    required String adminId,
    required String targetUserId,
    required String action,
    required DateTime timestamp,
    String? notes,
  }) = _AdminAction;

  factory AdminAction.fromJson(Map<String, dynamic> json) =>
      _$AdminActionFromJson(json);
}
