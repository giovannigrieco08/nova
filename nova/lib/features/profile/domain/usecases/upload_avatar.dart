// Usecase: UploadAvatar
// Feature: 006-user-profile (User Story 1)
// Purpose: Orchestrates avatar crop → compress → upload → profile update flow

import 'dart:io';
import '../../data/services/avatar_upload_service.dart';
import '../../data/repositories/profile_repository.dart';
import '../entities/profile.dart';

/// Upload avatar with crop, compress (WebP <500KB), and profile update
///
/// **Usage**:
/// ```dart
/// final uploadAvatar = ref.read(uploadAvatarUseCaseProvider);
/// final updatedProfile = await uploadAvatar(userId, selectedImageFile);
/// ```
///
/// **Flow**:
/// 1. User selects image from gallery/camera (via image_picker)
/// 2. User crops to circular aspect (via image_cropper with UCrop)
/// 3. **This usecase**:
///    - Compresses to WebP format targeting <500KB
///    - Uploads to Supabase Storage avatars/{user_id}/avatar.webp
///    - Updates profiles.avatar_url
///    - Deletes old avatar if exists
/// 4. Returns updated Profile entity
///
/// **Performance Targets**:
/// - Compression: <500ms on mid-range Android (per research.md)
/// - Upload: <3s total (tap Save → toast "Profilo aggiornato!")
///
/// **Validation**:
/// - Max file size: 2MB (enforced before calling this usecase)
/// - Min dimensions: 200×200px (enforced before calling this usecase)
/// - Supported formats: PNG, JPG, HEIC (converted to WebP)
///
/// **Throws**:
/// - `AvatarUploadException` if upload fails
/// - `AvatarCompressionException` if compression fails
/// - `OfflineModeException` if offline (cannot upload without network)
class UploadAvatar {
  final AvatarUploadService _avatarUploadService;
  final ProfileRepository _profileRepository;

  UploadAvatar(this._avatarUploadService, this._profileRepository);

  /// Execute the usecase to upload avatar
  ///
  /// **Parameters**:
  /// - `userId`: UUID of the user uploading avatar
  /// - `imageFile`: Cropped image file from image_picker/image_cropper
  ///
  /// **Returns**: Updated Profile entity with new avatar_url
  ///
  /// **Preconditions**:
  /// - `imageFile` must be already cropped to circular aspect via image_cropper
  /// - `imageFile.lengthSync()` must be ≤2MB
  /// - Image dimensions must be ≥200×200px
  ///
  /// **Example**:
  /// ```dart
  /// final croppedFile = await ImageCropper().cropImage(
  ///   sourcePath: pickedFile.path,
  ///   cropStyle: CropStyle.circle,
  /// );
  /// if (croppedFile != null) {
  ///   final updatedProfile = await uploadAvatar(userId, File(croppedFile.path));
  /// }
  /// ```
  Future<Profile> call(String userId, File imageFile) async {
    // Upload avatar to Storage and get public URL
    final avatarUrl = await _avatarUploadService.uploadAvatar(
      userId: userId,
      imageFile: imageFile,
    );

    // Update profile with new avatar URL
    final updatedProfile = await _profileRepository.updateProfile(
      userId,
      {'avatar_url': avatarUrl},
    );

    return updatedProfile;
  }
}
