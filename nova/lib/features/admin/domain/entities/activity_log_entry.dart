// =====================================================================
// ActivityLogEntry Entity - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Unified entity combining moderation_log and admin_log tables
// Architecture: Freezed immutable entity with JSON serialization
// =====================================================================

import 'package:freezed_annotation/freezed_annotation.dart';

part 'activity_log_entry.freezed.dart';
part 'activity_log_entry.g.dart';

/// Activity log entry combining moderation and admin actions
///
/// Represents either:
/// - Moderation action (approved/rejected event)
/// - Admin action (promoted/removed user role)
@freezed
class ActivityLogEntry with _$ActivityLogEntry {
  const factory ActivityLogEntry({
    /// Unique entry ID (from moderation_log.id or admin_log.id)
    required String id,

    /// Entry type: 'moderation' or 'admin'
    required String type,

    /// Actor user ID (moderator_id or admin_id)
    required String actorId,

    /// Actor full name (from profiles table join)
    required String actorName,

    /// Action type: 'approved', 'rejected', 'promoted', 'removed'
    required String action,

    /// Timestamp when action occurred
    required DateTime timestamp,

    // Moderation-specific fields (null for admin actions)

    /// Event ID (moderation actions only)
    String? eventId,

    /// Event title (moderation actions only)
    String? eventTitle,

    /// Rejection reason (rejected events only)
    String? rejectionReason,

    // Admin-specific fields (null for moderation actions)

    /// Target user ID (admin actions only)
    String? targetUserId,

    /// Target user full name (admin actions only)
    String? targetUserName,

    /// Old role before change (admin actions only)
    String? oldRole,

    /// New role after change (admin actions only)
    String? newRole,
  }) = _ActivityLogEntry;

  factory ActivityLogEntry.fromJson(Map<String, dynamic> json) =>
      _$ActivityLogEntryFromJson(json);
}

/// Extension methods for ActivityLogEntry convenience
extension ActivityLogEntryX on ActivityLogEntry {
  /// Whether this is a moderation action
  bool get isModerationAction => type == 'moderation';

  /// Whether this is an admin action
  bool get isAdminAction => type == 'admin';

  /// Human-readable action description
  String get actionDescription {
    switch (action) {
      case 'approved':
        return 'Approvato evento';
      case 'rejected':
        return 'Rifiutato evento';
      case 'promoted':
        return 'Promosso a moderatore';
      case 'removed':
        return 'Rimosso ruolo moderatore';
      default:
        return action;
    }
  }

  /// Action badge color (based on action type)
  String get actionColor {
    switch (action) {
      case 'approved':
        return 'success';
      case 'rejected':
        return 'error';
      case 'promoted':
        return 'primary';
      case 'removed':
        return 'warning';
      default:
        return 'secondary';
    }
  }

  /// Target description (event title or user name)
  String get targetDescription {
    if (isModerationAction) {
      return eventTitle ?? 'Evento sconosciuto';
    } else {
      return targetUserName ?? 'Utente sconosciuto';
    }
  }
}
