// Widget: ImagePickerWidget
// Feature: 004-event-creation-moderation (US1 - Event Creation)
// Purpose: Image picker with camera/gallery options, cropping, and preview
//
// Features:
// - Show placeholder if no image selected
// - Show selected image preview (3:4 aspect ratio, BeReal-style)
// - Buttons: "Camera" and "Gallery"
// - Tap image to change/remove
// - Loading indicator during compression
// - 3:4 aspect ratio cropper for precise image framing

import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';
import '../../../../core/utils/image_orientation_fixer.dart';
import 'event_image_cropper.dart';

/// Image picker widget for event creation
class ImagePickerWidget extends StatefulWidget {
  final File? imageFile;
  final String? imagePath;
  final Function(File) onImagePicked;
  final VoidCallback? onImageRemoved;
  final String? errorText;

  const ImagePickerWidget({
    super.key,
    this.imageFile,
    this.imagePath,
    required this.onImagePicked,
    this.onImageRemoved,
    this.errorText,
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  /// Show error toast (Cupertino compatible)
  void _showErrorToast(String message) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom + 100,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: CupertinoColors.systemRed.darkColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.imageFile != null || widget.imagePath != null;

    // BeReal-style: image takes prominent space at top, 3:4 aspect ratio
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image preview or placeholder (BeReal-style: full width, 3:4 ratio)
        GestureDetector(
          onTap: _showPickerOptions, // Both with/without image use same picker
          child: AspectRatio(
            aspectRatio: 3 / 4, // BeReal-style portrait ratio
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: NovaColors.surface(context),
                border: widget.errorText != null
                    ? Border.all(color: NovaColors.error(context), width: 2)
                    : null,
              ),
              child: _isLoading
                  ? _buildLoadingIndicator()
                  : hasImage
                      ? _buildImagePreview()
                      : _buildPlaceholder(),
            ),
          ),
        ),

        // Error text (below image)
        if (widget.errorText != null)
          Padding(
            padding: EdgeInsets.all(NovaSpacing.m),
            child: Text(
              widget.errorText!,
              style: NovaTextStyles.caption.copyWith(
                color: NovaColors.error(context),
              ),
            ),
          ),

        // Change/Remove button (only when image exists)
        if (hasImage && !_isLoading) _buildChangeImageBar(),
      ],
    );
  }

  /// Show picker options (camera/gallery) when tapping placeholder
  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle indicator (matches comment actions menu style)
            Container(
              margin: EdgeInsets.symmetric(vertical: NovaSpacing.s),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: NovaColors.dividerLight,
                borderRadius: NovaRadius.circularXxs,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text('Scatta Foto', style: NovaTypography.bodyMedium),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text('Scegli dalla Galleria',
                  style: NovaTypography.bodyMedium),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            SizedBox(height: NovaSpacing.m),
          ],
        ),
      ),
    );
  }

  /// Bar at bottom of image for change/remove actions
  Widget _buildChangeImageBar() {
    return Container(
      color: NovaColors.surface(context),
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton(
            onPressed: _showPickerOptions,
            child: Text(
              'Cambia',
              style: TextStyle(color: NovaColors.primary(context)),
            ),
          ),
          SizedBox(width: NovaSpacing.l),
          TextButton(
            onPressed: widget.onImageRemoved,
            child: Text(
              'Rimuovi',
              style: TextStyle(color: NovaColors.error(context)),
            ),
          ),
        ],
      ),
    );
  }

  /// Loading indicator during compression
  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: NovaColors.primary(context),
          ),
          SizedBox(height: NovaSpacing.m),
          Text(
            'Compressione immagine...',
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Image preview - Instagram-style: full bleed, no rounded corners
  Widget _buildImagePreview() {
    return widget.imageFile != null
        ? Image.file(
            widget.imageFile!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          )
        : widget.imagePath != null
            ? Image.file(
                File(widget.imagePath!),
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            : const SizedBox();
  }

  /// Placeholder (no image selected) - Instagram-style: large and engaging
  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 72, // Larger icon for prominence
            color: NovaColors.textSecondary(context),
          ),
          SizedBox(height: NovaSpacing.m),
          Text(
            'Aggiungi un\'immagine',
            style: NovaTextStyles.bodyLarge.copyWith(
              color: NovaColors.textSecondary(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: NovaSpacing.xs),
          Text(
            'Tocca per scegliere',
            style: NovaTextStyles.caption.copyWith(
              color: NovaColors.textTertiary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Pick image from camera or gallery, then show cropper for 3:4 ratio
  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isLoading = true);

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        // Don't limit resolution here - let the cropper handle final size
        // This gives user full image to crop from
        imageQuality: 95, // High quality for cropping
      );

      if (pickedFile != null) {
        // Fix orientation issues on iOS first
        // For events, assume rear camera (not selfies) - don't flip horizontally
        final fixedPath = await ImageOrientationFixer.fixOrientation(
          pickedFile.path,
          isFrontCamera: false, // Events use rear camera, not selfies
        );
        final fixedFile = File(fixedPath);

        // Show loading is done before cropper opens
        if (mounted) {
          setState(() => _isLoading = false);
        }

        // Show the cropper for 3:4 aspect ratio
        if (mounted) {
          final croppedFile = await EventImageCropper.show(context, fixedFile);

          if (croppedFile != null && mounted) {
            widget.onImagePicked(croppedFile);
          }
        }
      } else {
        // User cancelled image selection
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorToast('Errore durante la selezione: ${e.toString()}');
        setState(() => _isLoading = false);
      }
    }
  }
}
