// Provider: AvatarUploadProvider
// Feature: 006-user-profile (User Story 1 - T032)
// Purpose: Manage avatar upload progress, compression state, and error handling

import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/upload_avatar.dart';
import '../../domain/entities/profile.dart';
import 'profile_provider.dart';

// ============================================================================
// STATE CLASSES
// ============================================================================

/// Avatar upload state
class AvatarUploadState {
  final bool isUploading;
  final bool isCompressing;
  final double? progress; // 0.0 to 1.0
  final String? errorMessage;
  final File? selectedImage; // Cropped image before upload

  const AvatarUploadState({
    this.isUploading = false,
    this.isCompressing = false,
    this.progress,
    this.errorMessage,
    this.selectedImage,
  });

  AvatarUploadState copyWith({
    bool? isUploading,
    bool? isCompressing,
    double? progress,
    String? errorMessage,
    File? selectedImage,
  }) {
    return AvatarUploadState(
      isUploading: isUploading ?? this.isUploading,
      isCompressing: isCompressing ?? this.isCompressing,
      progress: progress ?? this.progress,
      errorMessage: errorMessage,
      selectedImage: selectedImage ?? this.selectedImage,
    );
  }

  /// Clear state (reset to initial)
  AvatarUploadState clear() {
    return const AvatarUploadState();
  }

  /// Check if any operation is in progress
  bool get isBusy => isUploading || isCompressing;
}

// ============================================================================
// NOTIFIER
// ============================================================================

/// Avatar upload state notifier
///
/// **Responsibilities**:
/// - Manage avatar selection and cropping flow
/// - Track compression progress
/// - Track upload progress
/// - Handle errors
/// - Update profile with new avatar URL on success
class AvatarUploadNotifier extends StateNotifier<AvatarUploadState> {
  final UploadAvatar _uploadAvatar;
  final String _userId;

  AvatarUploadNotifier(this._uploadAvatar, this._userId)
      : super(const AvatarUploadState());

  /// Set selected image after cropping
  ///
  /// **Preconditions**:
  /// - `imageFile` must be cropped to circular aspect via image_cropper
  /// - File size should be ≤2MB
  void setSelectedImage(File imageFile) {
    state = state.copyWith(
      selectedImage: imageFile,
      errorMessage: null,
    );
  }

  /// Upload selected avatar
  ///
  /// **Flow**:
  /// 1. Validate image (exists, size ≤2MB)
  /// 2. Set compressing state (compression happens in AvatarUploadService)
  /// 3. Set uploading state
  /// 4. Call UploadAvatar usecase
  /// 5. On success, clear state and return updated Profile
  /// 6. On error, set error message
  ///
  /// **Returns**: Updated Profile on success, null on failure
  Future<Profile?> upload() async {
    if (state.selectedImage == null) {
      state = state.copyWith(
        errorMessage: 'Nessuna immagine selezionata',
      );
      return null;
    }

    // Validate file size ≤2MB
    final fileSize = await state.selectedImage!.length();
    if (fileSize > 2 * 1024 * 1024) {
      state = state.copyWith(
        errorMessage: 'Immagine troppo grande (max 2MB)',
      );
      return null;
    }

    state = state.copyWith(
      isCompressing: true,
      progress: 0.3,
      errorMessage: null,
    );

    try {
      // Compression happens inside UploadAvatar usecase
      // (AvatarUploadService compresses to WebP <500KB)
      state = state.copyWith(
        isCompressing: false,
        isUploading: true,
        progress: 0.6,
      );

      // Upload to Supabase Storage and update profile
      final updatedProfile = await _uploadAvatar(_userId, state.selectedImage!);

      // Success - clear state
      state = state.clear();

      return updatedProfile;
    } catch (e) {
      state = state.copyWith(
        isCompressing: false,
        isUploading: false,
        progress: null,
        errorMessage: 'Errore nel caricare l\'avatar: ${e.toString()}',
      );
      return null;
    }
  }

  /// Cancel upload and clear state
  void cancel() {
    state = state.clear();
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Avatar upload provider
///
/// **Usage**:
/// ```dart
/// // In EditProfileScreen or AvatarPicker widget
/// final uploadState = ref.watch(avatarUploadProvider);
/// final uploadNotifier = ref.read(avatarUploadProvider.notifier);
///
/// // After image_cropper returns cropped file:
/// uploadNotifier.setSelectedImage(File(croppedFile.path));
///
/// // Trigger upload:
/// final updatedProfile = await uploadNotifier.upload();
/// if (updatedProfile != null) {
///   // Success - refresh profile provider
///   ref.invalidate(currentProfileProvider);
///   // Show toast "Profilo aggiornato!"
/// } else {
///   // Error - uploadState.errorMessage has details
/// }
/// ```
final avatarUploadProvider =
    StateNotifierProvider<AvatarUploadNotifier, AvatarUploadState>((ref) {
  final uploadAvatar = ref.watch(uploadAvatarUseCaseProvider);
  final supabase = ref.watch(supabaseClientProvider);
  final userId = supabase.auth.currentUser?.id;

  if (userId == null) {
    throw Exception('User not authenticated');
  }

  return AvatarUploadNotifier(uploadAvatar, userId);
});
