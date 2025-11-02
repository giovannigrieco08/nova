// Widget: AvatarCropper
// Feature: 002-profile-setup
// Purpose: Square crop interface for avatar images with gesture controls

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_typography.dart'; // NovaTextStyles
import '../../../../shared/widgets/nova_toast.dart';

/// Avatar cropper widget with gesture controls
///
/// Features:
/// - Square crop overlay with rounded corners
/// - Pinch-to-zoom gesture support
/// - Drag-to-pan gesture support
/// - Crop confirmation with preview
/// - Cancel option
class AvatarCropper extends StatefulWidget {
  final File imageFile;
  final Function(File croppedFile) onCropComplete;

  const AvatarCropper({
    super.key,
    required this.imageFile,
    required this.onCropComplete,
  });

  /// Show avatar cropper as full-screen dialog
  static Future<File?> show(BuildContext context, File imageFile) async {
    return showDialog<File>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AvatarCropper(
          imageFile: imageFile,
          onCropComplete: (croppedFile) {
            Navigator.of(context).pop(croppedFile);
          },
        );
      },
    );
  }

  @override
  State<AvatarCropper> createState() => _AvatarCropperState();
}

class _AvatarCropperState extends State<AvatarCropper> {
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _previousOffset = Offset.zero;
  bool _isCropping = false;

  img.Image? _image;
  Size _imageSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final bytes = await widget.imageFile.readAsBytes();
    final image = img.decodeImage(bytes);

    if (image != null && mounted) {
      setState(() {
        _image = image;
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });
    }
  }

  /// Crop image to square based on current scale/offset
  Future<void> _cropImage() async {
    if (_image == null) return;

    setState(() {
      _isCropping = true;
    });

    try {
      // Calculate crop area based on scale and offset
      final cropSize = (_imageSize.width / _scale).toInt();
      final offsetX = ((-_offset.dx / _scale) + (_imageSize.width - cropSize) / 2).toInt().clamp(0, _image!.width);
      final offsetY = ((-_offset.dy / _scale) + (_imageSize.height - cropSize) / 2).toInt().clamp(0, _image!.height);

      // Crop to square
      final cropped = img.copyCrop(
        _image!,
        x: offsetX,
        y: offsetY,
        width: cropSize.clamp(1, _image!.width - offsetX),
        height: cropSize.clamp(1, _image!.height - offsetY),
      );

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/cropped_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(cropped, quality: 95));

      if (mounted) {
        widget.onCropComplete(tempFile);
      }
    } catch (e) {
      if (mounted) {
        NovaToast.showError(context, 'Errore nel ritaglio: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCropping = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _isCropping ? null : () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Ritaglia foto',
          style: NovaTextStyles.h3.copyWith(color: Colors.white),
        ),
        actions: [
          if (_isCropping)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            TextButton(
              onPressed: _cropImage,
              child: Text(
                'Fatto',
                style: NovaTextStyles.body.copyWith(
                  color: NovaColors.primary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      body: _image == null
          ? const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          : Stack(
              children: [
                // Image with gesture controls
                Center(
                  child: GestureDetector(
                    onScaleStart: (details) {
                      _previousScale = _scale;
                      _previousOffset = _offset;
                    },
                    onScaleUpdate: (details) {
                      setState(() {
                        // Update scale (pinch-to-zoom)
                        _scale = (_previousScale * details.scale).clamp(1.0, 4.0);

                        // Update offset (drag-to-pan)
                        _offset = _previousOffset + details.focalPointDelta;
                      });
                    },
                    child: Transform(
                      transform: Matrix4.identity()
                        ..translate(_offset.dx, _offset.dy)
                        ..scale(_scale),
                      alignment: Alignment.center,
                      child: Image.file(
                        widget.imageFile,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),

                // Square crop overlay
                Center(
                  child: IgnorePointer(
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(NovaRadius.xl),
                      ),
                    ),
                  ),
                ),

                // Dark overlay outside crop area
                IgnorePointer(
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(
                      child: Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(NovaRadius.xl),
                        ),
                      ),
                    ),
                  ),
                ),

                // Instructions
                Positioned(
                  bottom: NovaSpacing.xxl,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: NovaSpacing.l,
                        vertical: NovaSpacing.m,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(NovaRadius.m),
                      ),
                      child: Text(
                        'Pizzica per zoom • Trascina per spostare',
                        style: NovaTextStyles.caption.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
