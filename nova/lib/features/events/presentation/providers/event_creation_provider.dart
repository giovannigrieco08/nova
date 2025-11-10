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
  final List<String> coOrganizers;

  // Validation errors (null if valid)
  final String? titleError;
  final String? descriptionError;
  final String? eventDateError;

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
    this.coOrganizers = const [],
    this.titleError,
    this.descriptionError,
    this.eventDateError,
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
        coOrganizers.length <= 3 &&
        titleError == null &&
        descriptionError == null &&
        eventDateError == null;
  }

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
    List<String>? coOrganizers,
    String? titleError,
    String? descriptionError,
    String? eventDateError,
    bool? isSubmitting,
    String? submitError,
    bool clearEventDate = false,
    bool clearLocation = false,
    bool clearImageFile = false,
    bool clearImagePath = false,
    bool clearSubmitError = false,
  }) {
    return EventFormState(
      title: title ?? this.title,
      description: description ?? this.description,
      eventDate: clearEventDate ? null : (eventDate ?? this.eventDate),
      location: clearLocation ? null : (location ?? this.location),
      imageFile: clearImageFile ? null : (imageFile ?? this.imageFile),
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      coOrganizers: coOrganizers ?? this.coOrganizers,
      titleError: titleError,
      descriptionError: descriptionError,
      eventDateError: eventDateError,
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
      coOrganizers: coOrganizers,
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
      coOrganizers: draft.coOrganizers,
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
    );
    _saveDraftDebounced();
  }

  /// Remove image
  void removeImage() {
    state = state.copyWith(
      clearImageFile: true,
      clearImagePath: true,
    );
    _saveDraftDebounced();
  }

  /// Add co-organizer (max 3)
  void addCoOrganizer(String userId) {
    if (state.coOrganizers.length >= 3) return;
    if (state.coOrganizers.contains(userId)) return;

    state = state.copyWith(
      coOrganizers: [...state.coOrganizers, userId],
    );
    _saveDraftDebounced();
  }

  /// Remove co-organizer
  void removeCoOrganizer(String userId) {
    state = state.copyWith(
      coOrganizers: state.coOrganizers.where((id) => id != userId).toList(),
    );
    _saveDraftDebounced();
  }

  /// Save draft to Hive (debounced)
  void _saveDraftDebounced() {
    _localDataSource.saveDraftDebounced(state.toDraft());
  }

  /// Create event (submit form)
  Future<Event?> createEvent() async {
    if (!state.isValid) return null;

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);

    try {
      // Generate event ID
      final eventId = const Uuid().v4();

      // Create event entity
      final event = Event(
        id: eventId,
        title: state.title.trim(),
        description: state.description.trim(),
        eventDate: state.eventDate!,
        location: state.location?.trim(),
        imageUrl: null, // Will be set by repository after upload
        creatorId: _currentUserId,
        coOrganizers: state.coOrganizers,
        status: EventStatus.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Call repository to create event (handles image upload + draft deletion)
      final createdEvent = await _repository.createEvent(
        event,
        imageFile: state.imageFile,
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
