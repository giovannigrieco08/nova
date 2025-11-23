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
@HiveType(typeId: 2) // TypeId 2 (EventModel is TypeId 1)
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

  /// Co-organizers user IDs (max 3)
  @HiveField(6)
  List<String> coOrganizers;

  EventDraft({
    required this.title,
    required this.description,
    this.eventDate,
    this.location,
    this.imagePath,
    required this.lastSaved,
    this.coOrganizers = const [],
  });

  /// Check if draft is valid for submission
  bool get isValid {
    return title.trim().length >= 5 &&
        title.trim().length <= 100 &&
        description.trim().length >= 20 &&
        description.trim().length <= 500 &&
        eventDate != null &&
        eventDate!.isAfter(DateTime.now()) &&
        coOrganizers.length <= 3;
  }

  /// Check if draft is empty (no user input yet)
  bool get isEmpty {
    return title.isEmpty &&
        description.isEmpty &&
        eventDate == null &&
        location == null &&
        imagePath == null &&
        coOrganizers.isEmpty;
  }

  /// Create a copy with updated fields
  EventDraft copyWith({
    String? title,
    String? description,
    DateTime? eventDate,
    String? location,
    String? imagePath,
    DateTime? lastSaved,
    List<String>? coOrganizers,
  }) {
    return EventDraft(
      title: title ?? this.title,
      description: description ?? this.description,
      eventDate: eventDate ?? this.eventDate,
      location: location ?? this.location,
      imagePath: imagePath ?? this.imagePath,
      lastSaved: lastSaved ?? this.lastSaved,
      coOrganizers: coOrganizers ?? this.coOrganizers,
    );
  }

  @override
  String toString() {
    return 'EventDraft(title: $title, lastSaved: $lastSaved, isValid: $isValid)';
  }
}
