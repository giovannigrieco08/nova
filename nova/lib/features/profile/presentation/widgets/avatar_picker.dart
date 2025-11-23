// Widget: AvatarPicker
// Feature: 006-user-profile (User Story 1 - T038)
// Purpose: Image picker + circular crop with platform-adaptive action sheet

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/theme/nova_radius.dart';

/// Avatar picker widget with image selection and circular cropping
///
/// **Flow**:
/// 1. User taps avatar or "Change Photo" button
/// 2. Show platform-adaptive action sheet (iOS: CupertinoActionSheet, Android: ModalBottomSheet)
/// 3. Options: "Camera" 📷, "Gallery" 🖼️, "Remove Photo" 🗑️ (if avatar exists), "Cancel"
/// 4. User selects source (camera or gallery)
/// 5. Open image_picker
/// 6. After selection, open image_cropper with circular crop
/// 7. Return cropped File to callback
///
/// **Validation**:
/// - Max file size: 2MB
/// - Min dimensions: 200×200px
/// - Supported formats: PNG, JPG, HEIC (auto-converted by cropper)
///
/// **Usage**:
/// ```dart
/// AvatarPicker(
///   currentAvatarUrl: profile.avatarUrl,
///   onImageSelected: (File croppedFile) {
///     // Upload avatar via AvatarUploadProvider
///     uploadNotifier.setSelectedImage(croppedFile);
///     await uploadNotifier.upload();
///   },
///   onRemoveAvatar: () {
///     // Remove avatar (set avatar_url to null)
///     updateProfile(userId, {'avatar_url': null});
///   },
/// )
/// ```
class AvatarPicker extends StatelessWidget {
  final String? currentAvatarUrl;
  final Function(File) onImageSelected;
  final VoidCallback? onRemoveAvatar;
  final double size;

  const AvatarPicker({
    this.currentAvatarUrl,
    required this.onImageSelected,
    this.onRemoveAvatar,
    this.size = 96.0,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showImageSourceActionSheet(context),
      child: Stack(
        children: [
          // Avatar display
          _buildAvatar(),

          // Edit icon overlay (bottom-right)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: NovaColors.brandViolet,
                shape: BoxShape.circle,
                border: Border.all(
                  color: NovaColors.backgroundPrimary,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build avatar display
  Widget _buildAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: NovaColors.backgroundSecondary,
      ),
      child: currentAvatarUrl != null && currentAvatarUrl!.isNotEmpty
          ? ClipOval(
              child: Image.network(
                currentAvatarUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder();
                },
              ),
            )
          : _buildPlaceholder(),
    );
  }

  /// Build placeholder avatar
  Widget _buildPlaceholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [NovaColors.brandViolet, NovaColors.brandPink],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Icon(
        Icons.person_rounded,
        color: Colors.white,
        size: 48,
      ),
    );
  }

  /// Show platform-adaptive action sheet for image source selection
  void _showImageSourceActionSheet(BuildContext context) {
    if (Platform.isIOS) {
      _showIOSActionSheet(context);
    } else {
      _showAndroidBottomSheet(context);
    }
  }

  /// Show iOS CupertinoActionSheet
  void _showIOSActionSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return CupertinoActionSheet(
          title: Text(
            'Cambia foto profilo',
            style: NovaTypography.headingSmall.copyWith(
              color: NovaColors.textPrimary,
            ),
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.camera);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.camera, size: 20),
                  SizedBox(width: NovaSpacing.small),
                  Text('Scatta foto', style: NovaTypography.bodyMedium),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(context);
                _pickImage(context, ImageSource.gallery);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.photo, size: 20),
                  SizedBox(width: NovaSpacing.small),
                  Text('Scegli dalla galleria', style: NovaTypography.bodyMedium),
                ],
              ),
            ),
            if (currentAvatarUrl != null && onRemoveAvatar != null)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(context);
                  onRemoveAvatar!();
                },
                isDestructiveAction: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(CupertinoIcons.delete, size: 20),
                    SizedBox(width: NovaSpacing.small),
                    Text('Rimuovi foto', style: NovaTypography.bodyMedium),
                  ],
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: Text('Annulla', style: NovaTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            )),
          ),
        );
      },
    );
  }

  /// Show Android ModalBottomSheet
  void _showAndroidBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: NovaColors.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NovaRadius.large),
        ),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.all(NovaSpacing.medium),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Text(
                  'Cambia foto profilo',
                  style: NovaTypography.headingSmall.copyWith(
                    color: NovaColors.textPrimary,
                  ),
                ),
                SizedBox(height: NovaSpacing.medium),

                // Camera option
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: Text('Scatta foto', style: NovaTypography.bodyMedium),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(context, ImageSource.camera);
                  },
                ),

                // Gallery option
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: Text('Scegli dalla galleria', style: NovaTypography.bodyMedium),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(context, ImageSource.gallery);
                  },
                ),

                // Remove photo option (if avatar exists)
                if (currentAvatarUrl != null && onRemoveAvatar != null)
                  ListTile(
                    leading: Icon(Icons.delete_rounded, color: NovaColors.error),
                    title: Text(
                      'Rimuovi foto',
                      style: NovaTypography.bodyMedium.copyWith(
                        color: NovaColors.error,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onRemoveAvatar!();
                    },
                  ),

                // Cancel button
                SizedBox(height: NovaSpacing.small),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Annulla',
                    style: NovaTypography.bodyMedium.copyWith(
                      color: NovaColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Pick image from camera or gallery
  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 90,
      );

      if (image == null) return; // User cancelled

      // Validate file size (max 2MB)
      final file = File(image.path);
      final fileSize = await file.length();
      if (fileSize > 2 * 1024 * 1024) {
        if (context.mounted) {
          _showError(context, 'Immagine troppo grande. Massimo 2MB.');
        }
        return;
      }

      // Crop image to circular aspect
      final croppedFile = await _cropImage(image.path);

      if (croppedFile != null) {
        onImageSelected(File(croppedFile.path));
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Errore nel selezionare l\'immagine: ${e.toString()}');
      }
    }
  }

  /// Crop image to circular aspect using image_cropper
  Future<CroppedFile?> _cropImage(String sourcePath) async {
    return await ImageCropper().cropImage(
      sourcePath: sourcePath,
      cropStyle: CropStyle.circle,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        // Android settings
        AndroidUiSettings(
          toolbarTitle: 'Ritaglia foto',
          toolbarColor: NovaColors.brandViolet,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          hideBottomControls: false,
        ),
        // iOS settings
        IOSUiSettings(
          title: 'Ritaglia foto',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
  }

  /// Show error message
  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: NovaColors.error,
      ),
    );
  }
}
