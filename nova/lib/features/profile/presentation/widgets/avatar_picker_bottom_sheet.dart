// Widget: AvatarPickerBottomSheet
// Feature: 002-profile-setup
// Purpose: Camera/gallery picker with permission handling

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart'; // NovaTextStyles
import '../../../../shared/widgets/nova_bottom_sheet.dart';
import '../../../../shared/widgets/nova_toast.dart';

/// Avatar picker bottom sheet with camera and gallery options
///
/// Features:
/// - Camera capture option
/// - Gallery selection option
/// - Permission handling with user-friendly errors
/// - Remove avatar option (if avatar exists)
class AvatarPickerBottomSheet extends StatelessWidget {
  final bool hasExistingAvatar;
  final Function(File imageFile) onImageSelected;
  final VoidCallback? onRemoveAvatar;

  const AvatarPickerBottomSheet({
    super.key,
    required this.onImageSelected,
    this.hasExistingAvatar = false,
    this.onRemoveAvatar,
  });

  /// Show avatar picker bottom sheet
  static Future<File?> show(
    BuildContext context, {
    bool hasExistingAvatar = false,
    VoidCallback? onRemoveAvatar,
  }) async {
    return NovaBottomSheet.show<File>(
      context: context,
      initialChildSize: hasExistingAvatar ? 0.4 : 0.35,
      minChildSize: 0.3,
      maxChildSize: 0.5,
      builder: (context, scrollController) {
        return AvatarPickerBottomSheet(
          hasExistingAvatar: hasExistingAvatar,
          onRemoveAvatar: onRemoveAvatar,
          onImageSelected: (file) {
            Navigator.of(context).pop(file);
          },
        );
      },
    );
  }

  /// Pick image from camera
  Future<void> _pickFromCamera(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 95,
      );

      if (image != null) {
        onImageSelected(File(image.path));
      }
    } catch (e) {
      if (context.mounted) {
        _showPermissionError(context, 'fotocamera');
      }
    }
  }

  /// Pick image from gallery
  Future<void> _pickFromGallery(BuildContext context) async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 95,
      );

      if (image != null) {
        onImageSelected(File(image.path));
      }
    } catch (e) {
      if (context.mounted) {
        _showPermissionError(context, 'galleria foto');
      }
    }
  }

  /// Show permission error with instructions
  void _showPermissionError(BuildContext context, String source) {
    NovaToast.showError(
      context,
      'Permesso negato per $source. Abilita nelle Impostazioni.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Title
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.xl,
            vertical: NovaSpacing.l,
          ),
          child: Text(
            'Scegli foto profilo',
            style: NovaTextStyles.h2.copyWith(
              color: NovaColors.textPrimary(context),
            ),
          ),
        ),

        SizedBox(height: NovaSpacing.s),

        // Camera option
        ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: NovaColors.primary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(NovaRadius.m),
            ),
            child: Icon(
              Icons.camera_alt,
              color: NovaColors.primary(context),
            ),
          ),
          title: Text(
            'Scatta foto',
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Usa la fotocamera',
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
          onTap: () => _pickFromCamera(context),
        ),

        // Gallery option
        ListTile(
          leading: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: NovaColors.primary(context).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(NovaRadius.m),
            ),
            child: Icon(
              Icons.photo_library,
              color: NovaColors.primary(context),
            ),
          ),
          title: Text(
            'Scegli dalla galleria',
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            'Seleziona una foto esistente',
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
          onTap: () => _pickFromGallery(context),
        ),

        // Remove avatar option (only if avatar exists)
        if (hasExistingAvatar && onRemoveAvatar != null) ...[
          Divider(
            height: 1,
            color: NovaColors.border(context),
          ),
          ListTile(
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: NovaColors.error(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(NovaRadius.m),
              ),
              child: Icon(
                Icons.delete,
                color: NovaColors.error(context),
              ),
            ),
            title: Text(
              'Rimuovi foto',
              style: NovaTextStyles.body.copyWith(
                color: NovaColors.error(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Torna alle iniziali colorate',
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),
            onTap: () {
              Navigator.of(context).pop();
              onRemoveAvatar?.call();
            },
          ),
        ],

        SizedBox(height: NovaSpacing.l),
      ],
    );
  }
}
