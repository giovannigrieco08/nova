// =====================================================================
// EventStatus Enum - Event Creation and Moderation Feature
// =====================================================================
// Purpose: Type-safe event moderation status enumeration
// Architecture: Enum with JSON serialization support
// =====================================================================

import 'package:freezed_annotation/freezed_annotation.dart';

/// Event moderation status
///
/// Represents the current state of an event in the moderation workflow:
/// - pending: Awaiting moderator review (default for new events)
/// - approved: Approved by moderator, visible in public feed
/// - rejected: Rejected by moderator with reason provided
enum EventStatus {
  /// Event is pending moderator review (not visible in public feed)
  @JsonValue('pending')
  pending,

  /// Event approved by moderator (visible in public feed)
  @JsonValue('approved')
  approved,

  /// Event rejected by moderator (not visible, reason provided)
  @JsonValue('rejected')
  rejected,
}

/// Extension methods for EventStatus
extension EventStatusExtension on EventStatus {
  /// Get display-friendly Italian label for status
  String get label {
    return switch (this) {
      EventStatus.pending => 'In Revisione',
      EventStatus.approved => 'Approvato',
      EventStatus.rejected => 'Rifiutato',
    };
  }

  /// Get status color for UI (NovaColors integration later)
  String get colorKey {
    return switch (this) {
      EventStatus.pending => 'warning', // Yellow
      EventStatus.approved => 'success', // Green
      EventStatus.rejected => 'error', // Red
    };
  }

  /// Get status icon name
  String get iconName {
    return switch (this) {
      EventStatus.pending => 'clock', // Pending clock icon
      EventStatus.approved => 'check_circle', // Check mark icon
      EventStatus.rejected => 'cancel', // X mark icon
    };
  }
}
