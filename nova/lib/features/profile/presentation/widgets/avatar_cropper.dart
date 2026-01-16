// Widget: AvatarCropper
// Feature: 002-profile-setup
// Purpose: Instagram-style circular crop interface for avatar images
// - Smooth gesture handling with InteractiveViewer
// - Circular mask with dark overlay
// - iOS dark immersive look

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

/// Instagram-style avatar cropper with circular mask
///
/// Features:
/// - Smooth pinch-to-zoom and drag gestures via InteractiveViewer
/// - Circular crop overlay with dark surrounding
/// - iOS-style dark immersive UI
/// - Automatic image bounds constraining
class AvatarCropper extends StatefulWidget {
  final File imageFile;
  final Function(File croppedFile) onCropComplete;

  const AvatarCropper({
    super.key,
    required this.imageFile,
    required this.onCropComplete,
  });

  /// Show avatar cropper as full-screen modal
  static Future<File?> show(BuildContext context, File imageFile) async {
    return Navigator.of(context).push<File>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return AvatarCropper(
            imageFile: imageFile,
            onCropComplete: (croppedFile) {
              Navigator.of(context).pop(croppedFile);
            },
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  @override
  State<AvatarCropper> createState() => _AvatarCropperState();
}

class _AvatarCropperState extends State<AvatarCropper> {
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _imageKey = GlobalKey();

  bool _isLoading = true;
  bool _isCropping = false;
  ui.Image? _uiImage;
  Size _imageSize = Size.zero;
  Size _displayedImageSize = Size.zero;

  // Crop circle size (diameter)
  late double _cropSize;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Calculate crop size based on screen width (80% of screen width)
    final screenWidth = MediaQuery.of(context).size.width;
    _cropSize = screenWidth * 0.8;
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      if (mounted) {
        setState(() {
          _uiImage = frame.image;
          _imageSize = Size(
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          );
          _isLoading = false;
        });

        // Set initial scale after layout
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _setInitialTransform();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _setInitialTransform() {
    if (_uiImage == null) return;

    final screenSize = MediaQuery.of(context).size;

    // Calculate the displayed image dimensions (BoxFit.contain behavior)
    final imageAspect = _imageSize.width / _imageSize.height;
    final screenAspect = screenSize.width / screenSize.height;

    double displayWidth, displayHeight;
    if (imageAspect > screenAspect) {
      // Image is wider than screen
      displayWidth = screenSize.width;
      displayHeight = screenSize.width / imageAspect;
    } else {
      // Image is taller than screen
      displayHeight = screenSize.height;
      displayWidth = screenSize.height * imageAspect;
    }

    _displayedImageSize = Size(displayWidth, displayHeight);

    // Calculate minimum scale to cover the crop circle
    final minDimension = math.min(displayWidth, displayHeight);
    final minScale = _cropSize / minDimension;

    // Start with image scaled to fill crop area
    final initialScale = minScale * 1.1; // Slightly larger to allow some margin

    // Center the image
    final offsetX = (screenSize.width - displayWidth * initialScale) / 2;
    final offsetY = (screenSize.height - displayHeight * initialScale) / 2;

    final matrix = Matrix4.identity()
      ..setEntry(0, 3, offsetX)
      ..setEntry(1, 3, offsetY)
      ..setEntry(0, 0, initialScale)
      ..setEntry(1, 1, initialScale)
      ..setEntry(2, 2, initialScale);

    _transformationController.value = matrix;
  }

  Future<void> _cropImage() async {
    if (_uiImage == null) return;

    setState(() => _isCropping = true);

    try {
      final screenSize = MediaQuery.of(context).size;

      // Get current transformation
      final matrix = _transformationController.value;
      final scale = matrix.getMaxScaleOnAxis();
      final translationX = matrix[12];
      final translationY = matrix[13];

      // Screen center (where crop circle is)
      final cropCenterX = screenSize.width / 2;
      final cropCenterY = screenSize.height / 2;

      // The Center widget positions the image at this offset (before any transform)
      // This is crucial: the image is centered within the screen before transform is applied
      final baseOffsetX = (screenSize.width - _displayedImageSize.width) / 2;
      final baseOffsetY = (screenSize.height - _displayedImageSize.height) / 2;

      // After transform, the image's top-left position in screen coordinates
      // The transform scales the base offset and then applies translation
      final imageLeft = scale * baseOffsetX + translationX;
      final imageTop = scale * baseOffsetY + translationY;

      // Calculate displayed image size after scaling
      final scaledWidth = _displayedImageSize.width * scale;
      final scaledHeight = _displayedImageSize.height * scale;

      // Crop area in displayed (scaled) image coordinates
      final cropLeftInImage = (cropCenterX - _cropSize / 2 - imageLeft);
      final cropTopInImage = (cropCenterY - _cropSize / 2 - imageTop);

      // Convert to normalized coordinates (0-1)
      final normalizedLeft = cropLeftInImage / scaledWidth;
      final normalizedTop = cropTopInImage / scaledHeight;
      final normalizedSize = _cropSize / scaledWidth;

      // Convert to original image coordinates
      final srcX = (normalizedLeft * _imageSize.width).round();
      final srcY = (normalizedTop * _imageSize.height).round();
      final srcSize = (normalizedSize * _imageSize.width).round();

      // Load and crop image using the image package
      final bytes = await widget.imageFile.readAsBytes();
      final originalImage = img.decodeImage(bytes);

      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }

      // Clamp values to image bounds
      final clampedX = srcX.clamp(0, originalImage.width - 1);
      final clampedY = srcY.clamp(0, originalImage.height - 1);
      final maxWidth = originalImage.width - clampedX;
      final maxHeight = originalImage.height - clampedY;
      final clampedSize = srcSize.clamp(1, math.min(maxWidth, maxHeight));

      // Crop to square
      final cropped = img.copyCrop(
        originalImage,
        x: clampedX,
        y: clampedY,
        width: clampedSize.toInt(),
        height: clampedSize.toInt(),
      );

      // Resize to standard avatar size (512x512)
      final resized = img.copyResize(cropped, width: 512, height: 512);

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/cropped_avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(resized, quality: 90));

      if (mounted) {
        widget.onCropComplete(tempFile);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore nel ritaglio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCropping = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Image with InteractiveViewer for smooth gestures
            if (!_isLoading && _uiImage != null)
              InteractiveViewer(
                transformationController: _transformationController,
                minScale: 0.5,
                maxScale: 5.0,
                boundaryMargin: const EdgeInsets.all(double.infinity),
                panEnabled: true,
                scaleEnabled: true,
                child: Center(
                  child: Image.file(
                    widget.imageFile,
                    key: _imageKey,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

            // Loading indicator
            if (_isLoading)
              const Center(
                child: CupertinoActivityIndicator(
                  color: Colors.white,
                  radius: 16,
                ),
              ),

            // Circular crop overlay with dark surrounding
            if (!_isLoading)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _CircleCropOverlayPainter(
                      circleSize: _cropSize,
                      overlayColor: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ),

            // Top bar with buttons
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: NovaSpacing.s,
                    vertical: NovaSpacing.s,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Cancel button
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        onPressed:
                            _isCropping ? null : () => Navigator.pop(context),
                        child: Text(
                          'Annulla',
                          style: NovaTypography.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),

                      // Title
                      Text(
                        'Sposta e ridimensiona',
                        style: NovaTypography.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      // Confirm button
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        onPressed: _isCropping ? null : _cropImage,
                        child: _isCropping
                            ? const CupertinoActivityIndicator(
                                color: Colors.white,
                                radius: 10,
                              )
                            : Text(
                                'Scegli',
                                style: NovaTypography.bodyMedium.copyWith(
                                  color: CupertinoColors.activeBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Bottom instruction
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.all(NovaSpacing.l),
                  child: Text(
                    'Pizzica per ingrandire • Trascina per spostare',
                    style: NovaTypography.bodySmall.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom painter for circular crop overlay with dark surround
class _CircleCropOverlayPainter extends CustomPainter {
  final double circleSize;
  final Color overlayColor;

  _CircleCropOverlayPainter({
    required this.circleSize,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;

    // Create path for the entire screen
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Create circular hole in the center
    final center = Offset(size.width / 2, size.height / 2);
    final circlePath = Path()
      ..addOval(Rect.fromCircle(center: center, radius: circleSize / 2));

    // Combine paths: full screen minus circle (creates hole effect)
    final overlayPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(fullRect),
      circlePath,
    );

    canvas.drawPath(overlayPath, paint);

    // Draw subtle circle border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, circleSize / 2, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CircleCropOverlayPainter oldDelegate) {
    return oldDelegate.circleSize != circleSize ||
        oldDelegate.overlayColor != overlayColor;
  }
}
