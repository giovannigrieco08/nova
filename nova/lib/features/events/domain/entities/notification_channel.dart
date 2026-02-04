// =====================================================================
// NotificationChannel Enum - Event Creation and Moderation Feature
// =====================================================================
// Purpose: Type-safe notification channel enumeration
// Architecture: Enum with JSON serialization support
// =====================================================================

import 'package:freezed_annotation/freezed_annotation.dart';

/// Notification channel/type
///
/// Defines different categories of notifications users can receive:
/// - event_approved: Student's event was approved by moderator
/// - event_rejected: Student's event was rejected by moderator
/// - new_pending_event: Moderator receives notification about new pending event
/// - added_as_coorganizer: User was added as co-organizer to an event
/// - event_modified: Co-organizer or creator modified event details
enum NotificationChannel {
  /// Student receives when their event is approved
  @JsonValue('event_approved')
  eventApproved,

  /// Student receives when their event is rejected
  @JsonValue('event_rejected')
  eventRejected,

  /// Moderator receives when new event submitted (batched daily)
  @JsonValue('new_pending_event')
  newPendingEvent,

  /// User receives when added as co-organizer
  @JsonValue('added_as_coorganizer')
  addedAsCoorganizer,

  /// Co-organizers + creator receive when event is modified
  @JsonValue('event_modified')
  eventModified,
}

/// Extension methods for NotificationChannel
extension NotificationChannelExtension on NotificationChannel {
  /// Get display-friendly Italian label for notification channel
  String get label {
    return switch (this) {
      NotificationChannel.eventApproved => 'Evento Approvato',
      NotificationChannel.eventRejected => 'Evento Rifiutato',
      NotificationChannel.newPendingEvent => 'Nuovo Evento Pendente',
      NotificationChannel.addedAsCoorganizer =>
        'Aggiunto come Co-Organizzatore',
      NotificationChannel.eventModified => 'Evento Modificato',
    };
  }

  /// Get notification importance level (for Android channels)
  NotificationImportance get importance {
    return switch (this) {
      NotificationChannel.eventApproved => NotificationImportance.high,
      NotificationChannel.eventRejected => NotificationImportance.high,
      NotificationChannel.newPendingEvent => NotificationImportance.low,
      NotificationChannel.addedAsCoorganizer => NotificationImportance.high,
      NotificationChannel.eventModified => NotificationImportance.default_,
    };
  }

  /// Check if user can opt-out of this notification channel
  bool get canOptOut {
    return switch (this) {
      // Core moderation notifications (cannot opt-out)
      NotificationChannel.eventApproved => false,
      NotificationChannel.eventRejected => false,

      // Optional notifications (can opt-out)
      NotificationChannel.newPendingEvent => true,
      NotificationChannel.addedAsCoorganizer => true,
      NotificationChannel.eventModified => true,
    };
  }
}

/// Notification importance levels (maps to Android notification importance)
enum NotificationImportance {
  low, // Minimal interruption
  default_, // Standard notifications
  high, // Make sound and show banner
}
