// Riverpod Provider: EventCreationNotifier + EventFormState
// Feature: 004-event-creation-moderation (US1 - Event Creation)
// Purpose: State management for event creation form with real-time validation
//
// Features:
// - Real-time validation (title, description, date, location)
// - Character counters (e.g., "45/100" for title)
// - Auto-save draft to Hive every 500ms (debounced)
// - Image compression before upload
// - Form submission with loading state

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_status.dart';
import '../../domain/repositories/event_repository_interface.dart';
import '../../data/models/event_draft.dart';
import '../../data/datasources/event_local_datasource.dart';
import './repository_providers.dart';

// =============================================================================
// EVENT FORM STATE
// =============================================================================

/// Immutable state for event creation form
class EventFormState {
  // Form fields
  final String title;
  final String description;
  final DateTime? eventDate;
  final String? location;
  final File? imageFile;
  final String? imagePath; // Path for display (before upload)

  /// Pending collaboration invites (user IDs who haven't accepted yet)
  /// These users will receive an invite when the event is created.
  /// They must accept before appearing as co-organizers.
  final List<String> pendingInvites;

  // Validation errors (null if valid)
  final String? titleError;
  final String? descriptionError;
  final String? eventDateError;
  final String? imageError;

  // UI state
  final bool isSubmitting;
  final String? submitError;

  const EventFormState({
    this.title = '',
    this.description = '',
    this.eventDate,
    this.location,
    this.imageFile,
    this.imagePath,
    this.pendingInvites = const [],
    this.titleError,
    this.descriptionError,
    this.eventDateError,
    this.imageError,
    this.isSubmitting = false,
    this.submitError,
  });

  /// Check if form is valid for submission
  bool get isValid {
    return title.trim().length >= 5 &&
        title.trim().length <= 100 &&
        description.trim().length >= 20 &&
        description.trim().length <= 500 &&
        eventDate != null &&
        eventDate!.isAfter(DateTime.now()) &&
        (imageFile != null || imagePath != null) && // Image is required
        pendingInvites.length <= 3 &&
        titleError == null &&
        descriptionError == null &&
        eventDateError == null &&
        imageError == null;
  }

  /// Check if image is selected
  bool get hasImage => imageFile != null || imagePath != null;

  /// Character count for title (with limit)
  String get titleCharCount => '${title.length}/100';

  /// Character count for description (with limit)
  String get descriptionCharCount => '${description.length}/500';

  /// Copy with updated fields
  EventFormState copyWith({
    String? title,
    String? description,
    DateTime? eventDate,
    String? location,
    File? imageFile,
    String? imagePath,
    List<String>? pendingInvites,
    String? titleError,
    String? descriptionError,
    String? eventDateError,
    String? imageError,
    bool? isSubmitting,
    String? submitError,
    bool clearEventDate = false,
    bool clearLocation = false,
    bool clearImageFile = false,
    bool clearImagePath = false,
    bool clearImageError = false,
    bool clearSubmitError = false,
  }) {
    return EventFormState(
      title: title ?? this.title,
      description: description ?? this.description,
      eventDate: clearEventDate ? null : (eventDate ?? this.eventDate),
      location: clearLocation ? null : (location ?? this.location),
      imageFile: clearImageFile ? null : (imageFile ?? this.imageFile),
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      pendingInvites: pendingInvites ?? this.pendingInvites,
      titleError: titleError,
      descriptionError: descriptionError,
      eventDateError: eventDateError,
      imageError: clearImageError ? null : imageError,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }

  /// Convert to EventDraft for Hive storage
  EventDraft toDraft() {
    return EventDraft(
      title: title,
      description: description,
      eventDate: eventDate,
      location: location,
      imagePath: imagePath,
      lastSaved: DateTime.now(),
      pendingInvites: pendingInvites,
    );
  }

  /// Create from EventDraft (restore from Hive)
  factory EventFormState.fromDraft(EventDraft draft) {
    return EventFormState(
      title: draft.title,
      description: draft.description,
      eventDate: draft.eventDate,
      location: draft.location,
      imagePath: draft.imagePath,
      pendingInvites: draft.pendingInvites,
    );
  }
}

// =============================================================================
// EVENT CREATION NOTIFIER
// =============================================================================

/// State notifier for event creation form
class EventCreationNotifier extends StateNotifier<EventFormState> {
  final EventRepository _repository;
  final EventLocalDataSource _localDataSource;
  final String _currentUserId;

  EventCreationNotifier({
    required EventRepository repository,
    required EventLocalDataSource localDataSource,
    required String currentUserId,
  })  : _repository = repository,
        _localDataSource = localDataSource,
        _currentUserId = currentUserId,
        super(const EventFormState()) {
    // Restore draft on init (if exists)
    _restoreDraft();
  }

  /// Restore draft from Hive
  void _restoreDraft() {
    final draft = _localDataSource.getDraft();
    if (draft != null && !draft.isEmpty) {
      state = EventFormState.fromDraft(draft);
    }
  }

  /// Update title with validation
  void updateTitle(String title) {
    String? error;
    if (title.trim().length < 5) {
      error = 'Minimo 5 caratteri';
    } else if (title.trim().length > 100) {
      error = 'Massimo 100 caratteri';
    }

    state = state.copyWith(title: title, titleError: error);
    _saveDraftDebounced();
  }

  /// Update description with validation
  void updateDescription(String description) {
    String? error;
    if (description.trim().length < 20) {
      error = 'Minimo 20 caratteri';
    } else if (description.trim().length > 500) {
      error = 'Massimo 500 caratteri';
    }

    state = state.copyWith(description: description, descriptionError: error);
    _saveDraftDebounced();
  }

  /// Update event date with validation
  void updateEventDate(DateTime? date) {
    String? error;
    if (date != null && date.isBefore(DateTime.now())) {
      error = 'La data deve essere futura';
    }

    state = state.copyWith(
      eventDate: date,
      eventDateError: error,
      clearEventDate: date == null,
    );
    _saveDraftDebounced();
  }

  /// Update location (optional field)
  void updateLocation(String? location) {
    state = state.copyWith(
      location: location,
      clearLocation: location == null || location.isEmpty,
    );
    _saveDraftDebounced();
  }

  /// Pick and set image file
  Future<void> pickImage(File imageFile) async {
    state = state.copyWith(
      imageFile: imageFile,
      imagePath: imageFile.path,
      clearImageError: true,
    );
    _saveDraftDebounced();
  }

  /// Remove image
  void removeImage() {
    state = state.copyWith(
      clearImageFile: true,
      clearImagePath: true,
      imageError: 'L\'immagine è obbligatoria',
    );
    _saveDraftDebounced();
  }

  /// Add pending invite (max 3)
  /// The invited user must accept before becoming a co-organizer
  void addPendingInvite(String userId) {
    if (state.pendingInvites.length >= 3) return;
    if (state.pendingInvites.contains(userId)) return;

    state = state.copyWith(
      pendingInvites: [...state.pendingInvites, userId],
    );
    _saveDraftDebounced();
  }

  /// Remove pending invite
  void removePendingInvite(String userId) {
    state = state.copyWith(
      pendingInvites: state.pendingInvites.where((id) => id != userId).toList(),
    );
    _saveDraftDebounced();
  }

  /// Save draft to Hive (debounced)
  void _saveDraftDebounced() {
    _localDataSource.saveDraftDebounced(state.toDraft());
  }

  /// Validate all fields and show errors
  void validateForm() {
    String? titleError;
    String? descriptionError;
    String? eventDateError;
    String? imageError;

    if (state.title.trim().length < 5) {
      titleError = 'Minimo 5 caratteri';
    } else if (state.title.trim().length > 100) {
      titleError = 'Massimo 100 caratteri';
    }

    if (state.description.trim().length < 20) {
      descriptionError = 'Minimo 20 caratteri';
    } else if (state.description.trim().length > 500) {
      descriptionError = 'Massimo 500 caratteri';
    }

    if (state.eventDate == null) {
      eventDateError = 'Seleziona una data';
    } else if (state.eventDate!.isBefore(DateTime.now())) {
      eventDateError = 'La data deve essere futura';
    }

    if (!state.hasImage) {
      imageError = 'L\'immagine è obbligatoria';
    }

    state = state.copyWith(
      titleError: titleError,
      descriptionError: descriptionError,
      eventDateError: eventDateError,
      imageError: imageError,
    );
  }

  /// Create event (submit form)
  ///
  /// Creates the event with empty coOrganizers list.
  /// Pending invites are sent separately - invited users must accept
  /// before appearing as co-organizers on the event.
  Future<Event?> createEvent() async {
    // Validate form before submission
    validateForm();
    if (!state.isValid) return null;

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);

    try {
      // Generate event ID
      final eventId = const Uuid().v4();

      // Create event entity (coOrganizers starts empty - will be populated as invites are accepted)
      final event = Event(
        id: eventId,
        title: state.title.trim(),
        description: state.description.trim(),
        eventDate: state.eventDate!,
        location: state.location?.trim(),
        imageUrl: null, // Will be set by repository after upload
        creatorId: _currentUserId,
        coOrganizers: const [], // Empty until invites are accepted
        status: EventStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Call repository to create event (handles image upload + draft deletion)
      final createdEvent = await _repository.createEvent(
        event,
        imageFile: state.imageFile,
        pendingInvites: state.pendingInvites, // Send invites to these users
      );

      // Clear form on success
      state = const EventFormState();

      return createdEvent;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        submitError: 'Errore durante la creazione: ${e.toString()}',
      );
      return null;
    }
  }

  /// Clear form and draft
  void clearForm() {
    state = const EventFormState();
    _localDataSource.deleteDraft();
  }

  @override
  void dispose() {
    _localDataSource.dispose(); // Cancel debounce timer
    super.dispose();
  }
}

// =============================================================================
// PROVIDER
// =============================================================================

/// Provider for EventCreationNotifier
final eventCreationProvider =
    StateNotifierProvider<EventCreationNotifier, EventFormState>((ref) {
  final repository = ref.watch(eventRepositoryProvider);
  final localDataSource = ref.watch(eventLocalDataSourceProvider);
  final currentUserId = ref.watch(currentUserIdProvider) ?? '';

  return EventCreationNotifier(
    repository: repository,
    localDataSource: localDataSource,
    currentUserId: currentUserId,
  );
});
