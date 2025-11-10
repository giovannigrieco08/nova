// =====================================================================
// Event Entity (Freezed) - Features 003 (Feed) + 004 (Creation/Moderation)
// =====================================================================
// Purpose: Immutable event entity representing school events
// Architecture: Freezed for immutability, JSON serialization support
// =====================================================================

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:nova/features/events/domain/entities/event_status.dart';

part 'event.freezed.dart';
part 'event.g.dart';

/// School event entity
///
/// Represents an event created by students for school activities
/// (sports, study groups, class events, etc.)
@freezed
class Event with _$Event {
  const Event._(); // Private constructor for custom methods

  const factory Event({
    /// Unique event ID (UUID from Supabase)
    required String id,

    /// Event title (5-100 characters)
    required String title,

    /// Event description (20-500 characters)
    required String description,

    /// When the event takes place (must be in future)
    required DateTime eventDate,

    /// Where the event takes place (optional)
    String? location,

    /// Event image URL from Supabase Storage (optional, max 200KB)
    String? imageUrl,

    /// Creator user ID (UUID)
    required String creatorId,

    /// Co-organizers user IDs (max 3, empty by default)
    @Default([]) List<String> coOrganizers,

    /// Moderation status (pending, approved, rejected)
    required EventStatus status,

    /// Reason for rejection (populated if status=rejected)
    String? rejectionReason,

    /// Moderator who approved/rejected (UUID)
    String? moderatedBy,

    /// When moderation decision was made
    DateTime? moderatedAt,

    /// When event was created
    required DateTime createdAt,

    /// When event was last updated
    required DateTime updatedAt,
  }) = _Event;

  /// JSON deserialization factory
  factory Event.fromJson(Map<String, dynamic> json) => _$EventFromJson(json);

  /// Check if event is approved
  bool get isApproved => status == EventStatus.approved;

  /// Check if event is upcoming (event date is today or future)
  bool get isUpcoming {
    final today = DateTime.now();
    return eventDate.isAfter(today) ||
        (eventDate.year == today.year &&
            eventDate.month == today.month &&
            eventDate.day == today.day);
  }

  /// Format event date and time for display
  String get formattedDateTime {
    // Format: "15 Feb 2025 at 14:30"
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
    final day = eventDate.day;
    final month = months[eventDate.month - 1];
    final year = eventDate.year;
    final hour = eventDate.hour.toString().padLeft(2, '0');
    final minute = eventDate.minute.toString().padLeft(2, '0');
    return '$day $month $year alle $hour:$minute';
  }
}
