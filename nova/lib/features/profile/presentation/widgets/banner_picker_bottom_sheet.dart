// Widget: BannerPickerBottomSheet
// Feature: 014-profile-banner
// Purpose: Camera/gallery picker for banner images (platform-adaptive)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../shared/widgets/nova_toast.dart';

/// Banner picker bottom sheet with camera and gallery options
///
/// Features:
/// - Camera capture option
/// - Gallery selection option
/// - Permission handling with user-friendly errors
/// - Remove banner option (if banner exists)
/// - Platform-adaptive: CupertinoActionSheet on iOS, ModalBottomSheet on Android
class BannerPickerBottomSheet {
  /// Show banner picker action sheet (platform-adaptive)
  static Future<File?> show(
    BuildContext context, {
    bool hasExistingBanner = false,
    VoidCallback? onRemoveBanner,
  }) async {
    // Get selected source from bottom sheet
    final ImageSource? source;
    bool removeRequested = false;

    if (Platform.isIOS) {
      final result = await _showIOSActionSheet(
        context,
        hasExistingBanner: hasExistingBanner,
      );
      source = result?['source'] as ImageSource?;
      removeRequested = result?['remove'] == true;
    } else {
      final result = await _showAndroidBottomSheet(
        context,
        hasExistingBanner: hasExistingBanner,
      );
      source = result?['source'] as ImageSource?;
      removeRequested = result?['remove'] == true;
    }

    // Handle remove banner request
    if (removeRequested && onRemoveBanner != null) {
      onRemoveBanner();
      return null;
    }

    // User cancelled or no source selected
    if (source == null) return null;

    // Pick image from selected source
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 2400, // Larger for banner (will be cropped to 1200x400)
        maxHeight: 1600,
        imageQuality: 95,
      );

      if (image != null) {
        return File(image.path);
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
  static Future<Map<String, dynamic>?> _showIOSActionSheet(
    BuildContext context, {
    required bool hasExistingBanner,
  }) async {
    return showCupertinoModalPopup<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext ctx) {
        return CupertinoActionSheet(
          title: Text(
            'Scegli banner profilo',
            style: NovaTypography.headingSmall.copyWith(
              color: NovaColors.textPrimary(ctx),
            ),
          ),
          message: Text(
            'Il banner apparirà dietro la tua foto profilo',
            style: NovaTypography.bodySmall.copyWith(
              color: NovaColors.textSecondary(ctx),
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
                  Text('Scegli dalla galleria', style: NovaTypography.bodyMedium),
                ],
              ),
            ),
            if (hasExistingBanner)
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
                    Text('Rimuovi banner', style: NovaTypography.bodyMedium),
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
  static Future<Map<String, dynamic>?> _showAndroidBottomSheet(
    BuildContext context, {
    required bool hasExistingBanner,
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
                padding: EdgeInsets.only(bottom: NovaSpacing.xxs),
                child: Text(
                  'Scegli banner profilo',
                  style: NovaTypography.headingSmall.copyWith(
                    color: NovaColors.textPrimary(ctx),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              // Subtitle
              Padding(
                padding: EdgeInsets.only(bottom: NovaSpacing.s),
                child: Text(
                  'Il banner apparirà dietro la tua foto profilo',
                  style: NovaTypography.bodySmall.copyWith(
                    color: NovaColors.textSecondary(ctx),
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
                title: Text('Scegli dalla galleria', style: NovaTypography.bodyMedium),
                onTap: () {
                  Navigator.pop(ctx, {'source': ImageSource.gallery});
                },
              ),

              // Remove banner option (if banner exists)
              if (hasExistingBanner)
                ListTile(
                  leading: Icon(Icons.delete_rounded, color: NovaColors.error(ctx)),
                  title: Text(
                    'Rimuovi banner',
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
