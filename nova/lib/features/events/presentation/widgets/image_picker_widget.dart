// Widget: ImagePickerWidget
// Feature: 004-event-creation-moderation (US1 - Event Creation)
// Purpose: Image picker with camera/gallery options and preview
//
// Features:
// - Show placeholder if no image selected
// - Show selected image preview (16:9 aspect ratio)
// - Buttons: "Camera" and "Gallery"
// - Tap image to change/remove
// - Loading indicator during compression

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart';

/// Image picker widget for event creation
class ImagePickerWidget extends StatefulWidget {
  final File? imageFile;
  final String? imagePath;
  final Function(File) onImagePicked;
  final VoidCallback? onImageRemoved;

  const ImagePickerWidget({
    super.key,
    this.imageFile,
    this.imagePath,
    required this.onImagePicked,
    this.onImageRemoved,
  });

  @override
  State<ImagePickerWidget> createState() => _ImagePickerWidgetState();
}

class _ImagePickerWidgetState extends State<ImagePickerWidget> {
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.imageFile != null || widget.imagePath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'Immagine Evento (Opzionale)',
          style: NovaTextStyles.body,
        ),
        SizedBox(height: NovaSpacing.s),

        // Image preview or placeholder
        GestureDetector(
          onTap: hasImage ? _showImageOptions : null,
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: NovaColors.surface(context),
                borderRadius: NovaRadius.circularL,
                border: Border.all(
                  color: NovaColors.border(context),
                  width: 1,
                ),
              ),
              child: _isLoading
                  ? _buildLoadingIndicator()
                  : hasImage
                      ? _buildImagePreview()
                      : _buildPlaceholder(),
            ),
          ),
        ),
        SizedBox(height: NovaSpacing.s),

        // Action buttons (only show if no image)
        if (!hasImage) _buildActionButtons(),

        // Remove button (only show if image exists)
        if (hasImage && !_isLoading) _buildRemoveButton(),
      ],
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

  /// Image preview
  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: NovaRadius.circularL,
      child: widget.imageFile != null
          ? Image.file(
              widget.imageFile!,
              fit: BoxFit.cover,
            )
          : widget.imagePath != null
              ? Image.file(
                  File(widget.imagePath!),
                  fit: BoxFit.cover,
                )
              : const SizedBox(),
    );
  }

  /// Placeholder (no image selected)
  Widget _buildPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_photo_alternate_outlined,
            size: 48,
            color: NovaColors.textSecondary(context),
          ),
          SizedBox(height: NovaSpacing.s),
          Text(
            'Aggiungi un\'immagine',
            style: NovaTextStyles.body.copyWith(
              color: NovaColors.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Action buttons: Camera and Gallery
  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined, size: 20),
            label: const Text('Camera'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: NovaSpacing.m),
              side: BorderSide(color: NovaColors.border(context)),
              shape: RoundedRectangleBorder(
                borderRadius: NovaRadius.circularM,
              ),
            ),
          ),
        ),
        SizedBox(width: NovaSpacing.s),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _pickImage(ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined, size: 20),
            label: const Text('Galleria'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: NovaSpacing.m),
              side: BorderSide(color: NovaColors.border(context)),
              shape: RoundedRectangleBorder(
                borderRadius: NovaRadius.circularM,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Remove button (when image is selected)
  Widget _buildRemoveButton() {
    return Center(
      child: TextButton.icon(
        onPressed: () {
          widget.onImageRemoved?.call();
        },
        icon: const Icon(Icons.delete_outline, size: 20),
        label: const Text('Rimuovi Immagine'),
        style: TextButton.styleFrom(
          foregroundColor: NovaColors.error(context),
        ),
      ),
    );
  }

  /// Show options: Change or Remove
  void _showImageOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: NovaRadius.l,
        ),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Scatta Foto'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Scegli dalla Galleria'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: NovaColors.error(context)),
              title: Text(
                'Rimuovi Immagine',
                style: TextStyle(color: NovaColors.error(context)),
              ),
              onTap: () {
                Navigator.pop(context);
                widget.onImageRemoved?.call();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isLoading = true);

      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920, // Limit resolution before compression
        maxHeight: 1080,
        imageQuality: 85, // Pre-compression quality
      );

      if (pickedFile != null) {
        final imageFile = File(pickedFile.path);
        widget.onImagePicked(imageFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante la selezione: ${e.toString()}'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
