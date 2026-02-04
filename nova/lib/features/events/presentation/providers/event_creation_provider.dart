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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:nova/core/providers/core_providers.dart';
import '../../domain/entities/event.dart';
import '../../domain/entities/event_status.dart';
import '../../domain/repositories/event_repository_interface.dart';
import '../../data/models/event_draft.dart';
import '../../data/datasources/event_local_datasource.dart';
import './repository_providers.dart';

// =============================================================================
// PENDING INVITE INFO (for display during event creation)
// =============================================================================

/// Simple class to store invited user info for display in the form
class PendingInviteInfo {
  /// User ID (UUID)
  final String id;

  /// User's full name for display
  final String fullName;

  /// User's class (e.g., "3A", "4B")
  final String className;

  /// Optional avatar URL
  final String? avatarUrl;

  const PendingInviteInfo({
    required this.id,
    required this.fullName,
    required this.className,
    this.avatarUrl,
  });

  /// Create from JSON (for Hive serialization)
  factory PendingInviteInfo.fromJson(Map<String, dynamic> json) {
    return PendingInviteInfo(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      className: json['className'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  /// Convert to JSON (for Hive serialization)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'className': className,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PendingInviteInfo && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

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

  /// Pending collaboration invites (user info for display)
  /// These users will receive an invite when the event is created.
  /// They must accept before appearing as co-organizers.
  final List<PendingInviteInfo> pendingInvites;

  // Map location coordinates (for Maps integration)
  final double? latitude;
  final double? longitude;
  final String? placeId;

  // Help requests (free-text, max 5)
  final bool needsHelp;
  final List<String> helpRequests;

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
    this.latitude,
    this.longitude,
    this.placeId,
    this.needsHelp = false,
    this.helpRequests = const [],
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

  /// Check if location has map coordinates
  bool get hasMapLocation => latitude != null && longitude != null;

  /// Copy with updated fields
  EventFormState copyWith({
    String? title,
    String? description,
    DateTime? eventDate,
    String? location,
    File? imageFile,
    String? imagePath,
    List<PendingInviteInfo>? pendingInvites,
    double? latitude,
    double? longitude,
    String? placeId,
    bool? needsHelp,
    List<String>? helpRequests,
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
    bool clearCoordinates = false,
  }) {
    return EventFormState(
      title: title ?? this.title,
      description: description ?? this.description,
      eventDate: clearEventDate ? null : (eventDate ?? this.eventDate),
      location: clearLocation ? null : (location ?? this.location),
      imageFile: clearImageFile ? null : (imageFile ?? this.imageFile),
      imagePath: clearImagePath ? null : (imagePath ?? this.imagePath),
      pendingInvites: pendingInvites ?? this.pendingInvites,
      latitude: clearCoordinates ? null : (latitude ?? this.latitude),
      longitude: clearCoordinates ? null : (longitude ?? this.longitude),
      placeId: clearCoordinates ? null : (placeId ?? this.placeId),
      needsHelp: needsHelp ?? this.needsHelp,
      helpRequests: helpRequests ?? this.helpRequests,
      titleError: titleError,
      descriptionError: descriptionError,
      eventDateError: eventDateError,
      imageError: clearImageError ? null : imageError,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submitError: clearSubmitError ? null : (submitError ?? this.submitError),
    );
  }

  /// Convert to EventDraft for Hive storage
  /// Encodes PendingInviteInfo as JSON strings for Hive compatibility
  EventDraft toDraft() {
    return EventDraft(
      title: title,
      description: description,
      eventDate: eventDate,
      location: location,
      imagePath: imagePath,
      lastSaved: DateTime.now(),
      // Store invite info as JSON strings
      pendingInvites: pendingInvites
          .map((i) =>
              '${i.id}|${i.fullName}|${i.className}|${i.avatarUrl ?? ''}')
          .toList(),
      latitude: latitude,
      longitude: longitude,
      placeId: placeId,
      needsHelp: needsHelp,
      helpRequests: helpRequests,
    );
  }

  /// Create from EventDraft (restore from Hive)
  /// Parses JSON strings back to PendingInviteInfo
  factory EventFormState.fromDraft(EventDraft draft) {
    // Parse invite info from pipe-separated strings
    final invites = draft.pendingInvites.map((str) {
      final parts = str.split('|');
      if (parts.length >= 3) {
        return PendingInviteInfo(
          id: parts[0],
          fullName: parts[1],
          className: parts[2],
          avatarUrl: parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null,
        );
      }
      // Fallback for old format (just ID) - use placeholder name
      return PendingInviteInfo(
        id: str,
        fullName: 'Utente',
        className: '',
      );
    }).toList();

    return EventFormState(
      title: draft.title,
      description: draft.description,
      eventDate: draft.eventDate,
      location: draft.location,
      imagePath: draft.imagePath,
      pendingInvites: invites,
      latitude: draft.latitude,
      longitude: draft.longitude,
      placeId: draft.placeId,
      needsHelp: draft.needsHelp,
      helpRequests: draft.helpRequests,
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

  /// Update location (optional field) - text only, no coordinates
  void updateLocation(String? location) {
    state = state.copyWith(
      location: location,
      clearLocation: location == null || location.isEmpty,
      clearCoordinates: true, // Clear coordinates when manually entering text
    );
    _saveDraftDebounced();
  }

  /// Update location with GPS coordinates (from map picker)
  void updateLocationWithCoordinates({
    required String locationName,
    required double latitude,
    required double longitude,
    String? placeId,
  }) {
    state = state.copyWith(
      location: locationName,
      latitude: latitude,
      longitude: longitude,
      placeId: placeId,
    );
    _saveDraftDebounced();
  }

  /// Clear location and coordinates
  void clearLocationAndCoordinates() {
    state = state.copyWith(
      clearLocation: true,
      clearCoordinates: true,
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
  void addPendingInvite(PendingInviteInfo inviteInfo) {
    if (state.pendingInvites.length >= 3) return;
    if (state.pendingInvites.any((i) => i.id == inviteInfo.id)) return;

    state = state.copyWith(
      pendingInvites: [...state.pendingInvites, inviteInfo],
    );
    _saveDraftDebounced();
  }

  /// Remove pending invite by user ID
  void removePendingInvite(String userId) {
    state = state.copyWith(
      pendingInvites:
          state.pendingInvites.where((i) => i.id != userId).toList(),
    );
    _saveDraftDebounced();
  }

  // ===========================================================================
  // HELP REQUESTS MANAGEMENT
  // ===========================================================================

  /// Toggle needs help switch
  void toggleNeedsHelp(bool value) {
    state = state.copyWith(
      needsHelp: value,
      // Clear help requests when disabling
      helpRequests: value ? state.helpRequests : const [],
    );
    _saveDraftDebounced();
  }

  /// Add help request (max 5)
  void addHelpRequest(String description) {
    final trimmed = description.trim();
    if (trimmed.isEmpty) return;
    if (state.helpRequests.length >= 5) return;
    if (state.helpRequests.contains(trimmed)) return;

    state = state.copyWith(
      helpRequests: [...state.helpRequests, trimmed],
    );
    _saveDraftDebounced();
  }

  /// Remove help request by index
  void removeHelpRequest(int index) {
    if (index < 0 || index >= state.helpRequests.length) return;

    final newList = List<String>.from(state.helpRequests)..removeAt(index);
    state = state.copyWith(helpRequests: newList);
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
    if (!state.isValid) {
      state = state.copyWith(
        submitError: 'Correggi gli errori nel form prima di continuare',
      );
      return null;
    }

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
        latitude: state.latitude,
        longitude: state.longitude,
        placeId: state.placeId,
      );

      // Call repository to create event (handles image upload + draft deletion)
      // Extract just the user IDs for the repository
      final inviteUserIds = state.pendingInvites.map((i) => i.id).toList();
      final createdEvent = await _repository.createEvent(
        event,
        imageFile: state.imageFile,
        pendingInvites: inviteUserIds, // Send invites to these users
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

  /// Load event data for editing
  void loadEventForEdit(Event event) {
    state = EventFormState(
      title: event.title,
      description: event.description,
      eventDate: event.eventDate,
      location: event.location,
      imagePath: event.imageUrl, // Use existing image URL
      latitude: event.latitude,
      longitude: event.longitude,
      placeId: event.placeId,
    );
  }

  /// Update existing event
  Future<Event?> updateEvent(String eventId) async {
    // Validate form before submission
    validateForm();

    // For edit mode, we allow updating without new image if one already exists (imagePath set)
    final titleValid =
        state.titleError == null && state.title.trim().length >= 5;
    final descValid =
        state.descriptionError == null && state.description.trim().length >= 20;
    final dateValid = state.eventDateError == null && state.eventDate != null;

    if (!titleValid || !descValid || !dateValid) {
      state = state.copyWith(
        submitError: 'Correggi gli errori nel form prima di continuare',
      );
      return null;
    }

    state = state.copyWith(isSubmitting: true, clearSubmitError: true);

    try {
      // Build updates map
      final Map<String, dynamic> updates = {
        'title': state.title.trim(),
        'description': state.description.trim(),
        'event_date': state.eventDate!.toIso8601String(),
        'location': state.location?.trim(),
        'latitude': state.latitude,
        'longitude': state.longitude,
        'place_id': state.placeId,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // If new image was selected, upload it first
      if (state.imageFile != null) {
        final imageUrl = await _repository.uploadEventImage(
          state.imageFile!,
          eventId,
          userId: _currentUserId,
        );
        updates['image_url'] = imageUrl;
      }

      // Call repository to update event
      final result = await _repository.updateEvent(eventId, updates);

      // Clear form on success
      state = const EventFormState();

      return result;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        submitError: 'Errore durante la modifica: ${e.toString()}',
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
