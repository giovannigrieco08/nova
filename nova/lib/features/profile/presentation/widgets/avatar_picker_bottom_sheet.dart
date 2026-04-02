// Widget: AvatarPickerBottomSheet
// Feature: 002-profile-setup
// Purpose: Camera/gallery picker with permission handling (platform-adaptive)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/utils/image_orientation_fixer.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../shared/widgets/nova_toast.dart';

/// Avatar picker bottom sheet with camera and gallery options
///
/// Features:
/// - Camera capture option
/// - Gallery selection option
/// - Permission handling with user-friendly errors
/// - Remove avatar option (if avatar exists)
/// - Platform-adaptive: CupertinoActionSheet on iOS, ModalBottomSheet on Android
class AvatarPickerBottomSheet {
  /// Show avatar picker action sheet (platform-adaptive)
  static Future<File?> show(
    BuildContext context, {
    bool hasExistingAvatar = false,
    VoidCallback? onRemoveAvatar,
  }) async {
    // Get selected source from bottom sheet
    final ImageSource? source;
    bool removeRequested = false;

    if (Platform.isIOS) {
      final result = await _showIOSActionSheet(
        context,
        hasExistingAvatar: hasExistingAvatar,
      );
      source = result?['source'] as ImageSource?;
      removeRequested = result?['remove'] == true;
    } else {
      final result = await _showAndroidBottomSheet(
        context,
        hasExistingAvatar: hasExistingAvatar,
      );
      source = result?['source'] as ImageSource?;
      removeRequested = result?['remove'] == true;
    }

    // Handle remove avatar request
    if (removeRequested && onRemoveAvatar != null) {
      onRemoveAvatar();
      return null;
    }

    // User cancelled or no source selected
    if (source == null) return null;

    // Pick image from selected source
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 95,
      );

      if (image != null) {
        // Fix orientation issues on iOS (especially for selfies)
        final fixedPath = await ImageOrientationFixer.fixOrientation(
          image.path,
          isFrontCamera: source == ImageSource.camera,
        );
        return File(fixedPath);
      }
    } catch (e) {
      if (context.mounted) {
        final message = source == ImageSource.camera
            ? 'Permesso negato per fotocamera. Abilita nelle Impostazioni.'
            : 'Permesso negato per galleria foto. Abilita nelle Impostazioni.';
        NovaToast.showError(context, message);
      }
    }

    return null;
  }

  /// iOS: CupertinoActionSheet
  /// Returns a Map with 'source' (ImageSource) or 'remove' (bool)
  static Future<Map<String, dynamic>?> _showIOSActionSheet(
    BuildContext context, {
    required bool hasExistingAvatar,
  }) async {
    return showCupertinoModalPopup<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext ctx) {
        return CupertinoActionSheet(
          title: Text(
            'Scegli foto profilo',
            style: NovaTypography.headingSmall.copyWith(
              color: NovaColors.textPrimary(ctx),
            ),
          ),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx, {'source': ImageSource.camera});
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, size: 20),
                  SizedBox(width: NovaSpacing.small),
                  Text('Scatta foto', style: NovaTypography.bodyMedium),
                ],
              ),
            ),
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.pop(ctx, {'source': ImageSource.gallery});
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.photo_library, size: 20),
                  SizedBox(width: NovaSpacing.small),
                  Text('Scegli dalla galleria',
                      style: NovaTypography.bodyMedium),
                ],
              ),
            ),
            if (hasExistingAvatar)
              CupertinoActionSheetAction(
                onPressed: () {
                  Navigator.pop(ctx, {'remove': true});
                },
                isDestructiveAction: true,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.delete_outline, size: 20),
                    SizedBox(width: NovaSpacing.small),
                    Text('Rimuovi foto', style: NovaTypography.bodyMedium),
                  ],
                ),
              ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Annulla',
              style: NovaTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }

  /// Android: ModalBottomSheet
  /// Returns a Map with 'source' (ImageSource) or 'remove' (bool)
  static Future<Map<String, dynamic>?> _showAndroidBottomSheet(
    BuildContext context, {
    required bool hasExistingAvatar,
  }) async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle indicator
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.symmetric(vertical: NovaSpacing.s),
                decoration: BoxDecoration(
                  color: NovaColors.dividerLight,
                  borderRadius: NovaRadius.circularXxs,
                ),
              ),

              // Header title
              Padding(
                padding: EdgeInsets.only(bottom: NovaSpacing.s),
                child: Text(
                  'Scegli foto profilo',
                  style: NovaTypography.headingSmall.copyWith(
                    color: NovaColors.textPrimary(ctx),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              // Camera option
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: Text('Scatta foto', style: NovaTypography.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx, {'source': ImageSource.camera});
                },
              ),

              // Gallery option
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text('Scegli dalla galleria',
                    style: NovaTypography.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx, {'source': ImageSource.gallery});
                },
              ),

              // Remove photo option (if avatar exists)
              if (hasExistingAvatar)
                ListTile(
                  leading:
                      Icon(Icons.delete_rounded, color: NovaColors.error(ctx)),
                  title: Text(
                    'Rimuovi foto',
                    style: NovaTypography.bodyMedium.copyWith(
                      color: NovaColors.error(ctx),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx, {'remove': true});
                  },
                ),

              SizedBox(height: NovaSpacing.m),
            ],
          ),
        );
      },
    );
  }
}
