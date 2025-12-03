// =====================================================================
// ModerationEvent Model - Feature 005 (Admin Panel & Moderation Queue)
// =====================================================================
// Purpose: Model representing events in moderation queue
// Architecture: Freezed for immutability, maps to events table
// =====================================================================

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nova/features/events/domain/entities/event_status.dart';

part 'moderation_event.freezed.dart';
part 'moderation_event.g.dart';

/// Event in moderation queue
///
/// Extends base Event entity with additional moderation context.
/// Used exclusively in moderation flow for reviewing pending events.
@freezed
class ModerationEvent with _$ModerationEvent {
  const ModerationEvent._(); // Private constructor for custom methods

  const factory ModerationEvent({
    /// Unique event ID (UUID from Supabase)
    required String id,

    /// Event title (5-100 characters)
    required String title,

    /// Event description (20-500 characters)
    required String description,

    /// Emoji icon representing event category (optional, null if cover image used)
    String? emojiIcon,

    /// Single cover image URL (from Supabase Storage, null if emoji used)
    String? coverImageUrl,

    /// Event category (e.g., "sport", "studio", "sociale")
    required String category,

    /// Event start date and time
    required DateTime startDate,

    /// Event end date and time (optional, null for single-time events)
    DateTime? endDate,

    /// Where the event takes place (optional)
    String? location,

    /// Organizer full name (denormalized for display in queue)
    required String organizerName,

    /// When event was created (for sorting oldest-first)
    required DateTime createdAt,

    /// Creator user ID (UUID)
    required String createdBy,

    /// Moderation status (always 'pending' in queue, but included for completeness)
    @Default(EventStatus.pending) EventStatus status,

    /// Moderator who reviewed (null if pending)
    String? moderatedBy,

    /// When moderation decision was made (null if pending)
    DateTime? moderatedAt,

    /// Reason for rejection (null if pending or approved)
    String? rejectionReason,

    /// Number of times submitted (1 for first submission, increments on re-submission)
    @Default(1) int submissionCount,
  }) = _ModerationEvent;

  /// JSON deserialization factory
  factory ModerationEvent.fromJson(Map<String, dynamic> json) =>
      _$ModerationEventFromJson(json);

  /// Check if event is a re-submission (submitted more than once)
  bool get isResubmission => submissionCount > 1;

  /// Get formatted date range for display
  String get formattedDateRange {
    final months = [
      'Gen',
      'Feb',
      'Mar',
      'Apr',
      'Mag',
      'Giu',
      'Lug',
      'Ago',
      'Set',
      'Ott',
      'Nov',
      'Dic'
    ];

    final startDay = startDate.day;
    final startMonth = months[startDate.month - 1];
    final startYear = startDate.year;
    final startHour = startDate.hour.toString().padLeft(2, '0');
    final startMinute = startDate.minute.toString().padLeft(2, '0');

    if (endDate == null) {
      // Single time event
      return '$startDay $startMonth $startYear alle $startHour:$startMinute';
    }

    // Multi-day or time range event
    final endDay = endDate!.day;
    final endMonth = months[endDate!.month - 1];
    final endYear = endDate!.year;
    final endHour = endDate!.hour.toString().padLeft(2, '0');
    final endMinute = endDate!.minute.toString().padLeft(2, '0');

    if (startDate.year == endDate!.year &&
        startDate.month == endDate!.month &&
        startDate.day == endDate!.day) {
      // Same day, different times
      return '$startDay $startMonth $startYear dalle $startHour:$startMinute alle $endHour:$endMinute';
    }

    // Different days
    return '$startDay $startMonth - $endDay $endMonth $endYear';
  }

  /// Get time since submission for display (e.g., "2 ore fa", "3 giorni fa")
  String get timeSinceSubmission {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minuto' : 'minuti'} fa';
    } else if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'ora' : 'ore'} fa';
    } else if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${days == 1 ? 'giorno' : 'giorni'} fa';
    } else {
      final weeks = (difference.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'settimana' : 'settimane'} fa';
    }
  }

  /// Truncate description for preview in card (max 150 characters)
  String get descriptionPreview {
    if (description.length <= 150) return description;
    return '${description.substring(0, 147)}...';
  }
}
