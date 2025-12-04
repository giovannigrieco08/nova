// Data Model: EventDraft
// Feature: 004-event-creation-moderation (US1 - Event Creation)
// Purpose: Hive model for offline-first event draft persistence
//
// Draft auto-save strategy:
// - Debounced save every 500ms during form input
// - Prevents data loss if app crashes or user navigates away
// - Deleted on successful event creation

import 'package:hive/hive.dart';

part 'event_draft.g.dart';

/// Event draft model for Hive local storage
///
/// Stores work-in-progress event data to prevent data loss.
/// Used by EventCreationScreen for offline-first UX.
@HiveType(typeId: 8) // TypeId 8 (TypeId 3 is used by OfflineAction)
class EventDraft extends HiveObject {
  /// Event title (5-100 characters)
  @HiveField(0)
  String title;

  /// Event description (20-500 characters)
  @HiveField(1)
  String description;

  /// Event date and time
  @HiveField(2)
  DateTime? eventDate;

  /// Event location (optional)
  @HiveField(3)
  String? location;

  /// Local image file path (before upload)
  ///
  /// Stored as absolute path on device.
  /// Will be uploaded to Supabase Storage on event creation.
  @HiveField(4)
  String? imagePath;

  /// When draft was last saved
  @HiveField(5)
  DateTime lastSaved;

  /// Pending collaboration invites (user IDs who will be invited, max 3)
  /// These users must accept before becoming co-organizers
  @HiveField(6)
  List<String> pendingInvites;

  EventDraft({
    required this.title,
    required this.description,
    this.eventDate,
    this.location,
    this.imagePath,
    required this.lastSaved,
    this.pendingInvites = const [],
  });

  /// Check if draft is valid for submission
  bool get isValid {
    return title.trim().length >= 5 &&
        title.trim().length <= 100 &&
        description.trim().length >= 20 &&
        description.trim().length <= 500 &&
        eventDate != null &&
        eventDate!.isAfter(DateTime.now()) &&
        pendingInvites.length <= 3;
  }

  /// Check if draft is empty (no user input yet)
  bool get isEmpty {
    return title.isEmpty &&
        description.isEmpty &&
        eventDate == null &&
        location == null &&
        imagePath == null &&
        pendingInvites.isEmpty;
  }

  /// Create a copy with updated fields
  EventDraft copyWith({
    String? title,
    String? description,
    DateTime? eventDate,
    String? location,
    String? imagePath,
    DateTime? lastSaved,
    List<String>? pendingInvites,
  }) {
    return EventDraft(
      title: title ?? this.title,
      description: description ?? this.description,
      eventDate: eventDate ?? this.eventDate,
      location: location ?? this.location,
      imagePath: imagePath ?? this.imagePath,
      lastSaved: lastSaved ?? this.lastSaved,
      pendingInvites: pendingInvites ?? this.pendingInvites,
    );
  }

  @override
  String toString() {
    return 'EventDraft(title: $title, lastSaved: $lastSaved, isValid: $isValid)';
  }
}
