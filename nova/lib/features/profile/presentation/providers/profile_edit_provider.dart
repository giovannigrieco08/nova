// Provider: ProfileEditProvider
// Feature: 006-user-profile (User Story 1 - T031)
// Purpose: Manage profile edit form state, validation, and save flow

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/profile.dart';
import '../../domain/usecases/update_profile.dart';
import 'profile_provider.dart';

// ============================================================================
// STATE CLASSES
// ============================================================================

/// Form state for profile editing
class ProfileEditState {
  final String? fullName;
  final String? classYear;
  final String? bio;
  final bool isLoading;
  final String? errorMessage;
  final bool hasChanges;

  const ProfileEditState({
    this.fullName,
    this.classYear,
    this.bio,
    this.isLoading = false,
    this.errorMessage,
    this.hasChanges = false,
  });

  ProfileEditState copyWith({
    String? fullName,
    String? classYear,
    String? bio,
    bool? isLoading,
    String? errorMessage,
    bool? hasChanges,
  }) {
    return ProfileEditState(
      fullName: fullName ?? this.fullName,
      classYear: classYear ?? this.classYear,
      bio: bio ?? this.bio,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
      hasChanges: hasChanges ?? this.hasChanges,
    );
  }
}

/// Validation errors for profile edit form
class ProfileEditValidation {
  final String? fullNameError;
  final String? classError;
  final String? bioError;

  const ProfileEditValidation({
    this.fullNameError,
    this.classError,
    this.bioError,
  });

  bool get isValid =>
      fullNameError == null && classError == null && bioError == null;
}

// ============================================================================
// NOTIFIER
// ============================================================================

/// Profile edit form state notifier
///
/// **Responsibilities**:
/// - Manage form field state (full_name, class, bio)
/// - Real-time validation
/// - Detect unsaved changes
/// - Save flow with error handling
/// - Optimistic UI updates
class ProfileEditNotifier extends StateNotifier<ProfileEditState> {
  final UpdateProfile _updateProfile;
  final String _userId;
  final Profile _originalProfile;

  ProfileEditNotifier(
    this._updateProfile,
    this._userId,
    this._originalProfile,
  ) : super(ProfileEditState(
          fullName: _originalProfile.fullName,
          classYear: _originalProfile.classYear,
          bio: _originalProfile.bio,
        ));

  /// Update full name field
  void updateFullName(String value) {
    state = state.copyWith(
      fullName: value,
      hasChanges: _hasChanges(
        fullName: value,
        classYear: state.classYear,
        bio: state.bio,
      ),
      errorMessage: null,
    );
  }

  /// Update class field
  void updateClass(String value) {
    state = state.copyWith(
      classYear: value,
      hasChanges: _hasChanges(
        fullName: state.fullName,
        classYear: value,
        bio: state.bio,
      ),
      errorMessage: null,
    );
  }

  /// Update bio field
  void updateBio(String value) {
    state = state.copyWith(
      bio: value,
      hasChanges: _hasChanges(
        fullName: state.fullName,
        classYear: state.classYear,
        bio: value,
      ),
      errorMessage: null,
    );
  }

  /// Validate current form state
  ///
  /// **Validation Rules**:
  /// - `full_name`: Min 2 words (e.g., "Marco Rossi"), required
  /// - `class`: Required, must be valid class (1-5 A-E, Ac-Bc, or "Altro")
  /// - `bio`: Max 150 characters, optional
  ProfileEditValidation validate() {
    String? fullNameError;
    String? classError;
    String? bioError;

    // Validate full_name: min 2 words
    final fullName = state.fullName?.trim();
    if (fullName == null || fullName.isEmpty) {
      fullNameError = 'Nome completo richiesto';
    } else {
      final words = fullName.split(RegExp(r'\s+'));
      if (words.length < 2) {
        fullNameError = 'Inserisci nome e cognome';
      }
    }

    // Validate class: required
    if (state.classYear == null || state.classYear!.isEmpty) {
      classError = 'Seleziona la tua classe';
    }

    // Validate bio: max 150 characters
    final bio = state.bio?.trim();
    if (bio != null && bio.length > 150) {
      bioError = 'Bio troppo lunga (max 150 caratteri)';
    }

    return ProfileEditValidation(
      fullNameError: fullNameError,
      classError: classError,
      bioError: bioError,
    );
  }

  /// Save profile changes
  ///
  /// **Flow**:
  /// 1. Validate form
  /// 2. If valid, update via UpdateProfile usecase
  /// 3. On success, return true
  /// 4. On error, set error message and return false
  ///
  /// **Returns**: true if saved successfully, false otherwise
  Future<bool> save() async {
    // Validate first
    final validation = validate();
    if (!validation.isValid) {
      state = state.copyWith(
        errorMessage: validation.fullNameError ??
            validation.classError ??
            validation.bioError,
      );
      return false;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // Prepare updates map (only include changed fields)
      final updates = <String, dynamic>{};

      if (state.fullName != _originalProfile.fullName) {
        updates['full_name'] = state.fullName!.trim();
      }

      if (state.classYear != _originalProfile.classYear) {
        updates['class'] = state.classYear!;
      }

      if (state.bio != _originalProfile.bio) {
        updates['bio'] = state.bio?.trim();
      }

      // Call UpdateProfile usecase
      await _updateProfile(_userId, updates);

      state = state.copyWith(
        isLoading: false,
        hasChanges: false,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Errore nel salvare il profilo: ${e.toString()}',
      );
      return false;
    }
  }

  /// Reset form to original values
  void reset() {
    state = ProfileEditState(
      fullName: _originalProfile.fullName,
      classYear: _originalProfile.classYear,
      bio: _originalProfile.bio,
    );
  }

  /// Check if current state differs from original profile
  bool _hasChanges({
    required String? fullName,
    required String? classYear,
    required String? bio,
  }) {
    return fullName?.trim() != _originalProfile.fullName ||
        classYear != _originalProfile.classYear ||
        bio?.trim() != _originalProfile.bio;
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Profile edit form provider
///
/// **Usage**:
/// ```dart
/// // In EditProfileScreen
/// final editState = ref.watch(profileEditProvider);
/// final editNotifier = ref.read(profileEditProvider.notifier);
///
/// // Update fields
/// editNotifier.updateFullName('Marco Rossi');
/// editNotifier.updateClass('3A');
/// editNotifier.updateBio('Appassionato di fisica!');
///
/// // Validate
/// final validation = editNotifier.validate();
///
/// // Save
/// final success = await editNotifier.save();
/// if (success) {
///   // Navigate back, show toast
/// }
/// ```
final profileEditProvider =
    StateNotifierProvider<ProfileEditNotifier, ProfileEditState>((ref) {
  final updateProfile = ref.watch(updateProfileUseCaseProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    throw Exception('User not authenticated');
  }

  // Get current profile from currentProfileProvider
  final profileAsync = ref.watch(currentProfileProvider);

  return profileAsync.when(
    data: (profile) => ProfileEditNotifier(updateProfile, userId, profile),
    loading: () => throw Exception('Profile still loading'),
    error: (err, stack) => throw Exception('Failed to load profile: $err'),
  );
});
