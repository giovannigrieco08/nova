// Widget: EventImageCropper
// Feature: 004-event-creation-moderation (US1 - Event Creation)
// Purpose: Instagram-style 3:4 aspect ratio crop interface for event images
// - Smooth gesture handling with InteractiveViewer
// - Rectangular 3:4 mask with dark overlay
// - iOS dark immersive look (matches AvatarCropper style)

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

/// Instagram-style event image cropper with 3:4 rectangular mask
///
/// Features:
/// - Smooth pinch-to-zoom and drag gestures via InteractiveViewer
/// - 3:4 aspect ratio crop overlay (BeReal-style portrait)
/// - iOS-style dark immersive UI
/// - Automatic image bounds constraining
class EventImageCropper extends StatefulWidget {
  final File imageFile;
  final Function(File croppedFile) onCropComplete;

  const EventImageCropper({
    super.key,
    required this.imageFile,
    required this.onCropComplete,
  });

  /// Show event image cropper as full-screen modal
  static Future<File?> show(BuildContext context, File imageFile) async {
    return Navigator.of(context).push<File>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return EventImageCropper(
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
  State<EventImageCropper> createState() => _EventImageCropperState();
}

class _EventImageCropperState extends State<EventImageCropper> {
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _imageKey = GlobalKey();

  bool _isLoading = true;
  bool _isCropping = false;
  ui.Image? _uiImage;
  Size _imageSize = Size.zero;
  Size _displayedImageSize = Size.zero;

  // Crop area dimensions (3:4 aspect ratio)
  late double _cropWidth;
  late double _cropHeight;

  // Aspect ratio for event images (3:4 portrait, BeReal-style)
  static const double _aspectRatio = 3 / 4;

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
    // Calculate crop size to maximize usable space
    final screenWidth = MediaQuery.of(context).size.width;

    // Use nearly full screen width for the crop area
    _cropWidth = screenWidth - 32; // 16px margin on each side
    _cropHeight = _cropWidth / _aspectRatio;
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

    // Calculate scale to cover the crop rectangle
    final scaleToFillWidth = _cropWidth / displayWidth;
    final scaleToFillHeight = _cropHeight / displayHeight;
    final initialScale = math.max(scaleToFillWidth, scaleToFillHeight);

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

      // Screen center (where crop rectangle is)
      final cropCenterX = screenSize.width / 2;
      final cropCenterY = screenSize.height / 2;

      // The Center widget positions the image at this offset (before any transform)
      final baseOffsetX = (screenSize.width - _displayedImageSize.width) / 2;
      final baseOffsetY = (screenSize.height - _displayedImageSize.height) / 2;

      // After transform, the image's top-left position in screen coordinates
      final imageLeft = scale * baseOffsetX + translationX;
      final imageTop = scale * baseOffsetY + translationY;

      // Calculate displayed image size after scaling
      final scaledWidth = _displayedImageSize.width * scale;
      final scaledHeight = _displayedImageSize.height * scale;

      // Crop area in displayed (scaled) image coordinates
      final cropLeftInImage = (cropCenterX - _cropWidth / 2 - imageLeft);
      final cropTopInImage = (cropCenterY - _cropHeight / 2 - imageTop);

      // Convert to normalized coordinates (0-1)
      final normalizedLeft = cropLeftInImage / scaledWidth;
      final normalizedTop = cropTopInImage / scaledHeight;
      final normalizedWidth = _cropWidth / scaledWidth;
      final normalizedHeight = _cropHeight / scaledHeight;

      // Convert to original image coordinates
      final srcX = (normalizedLeft * _imageSize.width).round();
      final srcY = (normalizedTop * _imageSize.height).round();
      final srcWidth = (normalizedWidth * _imageSize.width).round();
      final srcHeight = (normalizedHeight * _imageSize.height).round();

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
      final clampedWidth = srcWidth.clamp(1, maxWidth);
      final clampedHeight = srcHeight.clamp(1, maxHeight);

      // Crop to 3:4 rectangle
      final cropped = img.copyCrop(
        originalImage,
        x: clampedX,
        y: clampedY,
        width: clampedWidth.toInt(),
        height: clampedHeight.toInt(),
      );

      // Resize to standard event image size (1200x1600 for 3:4 ratio)
      // This matches the maxWidth/maxHeight in ImagePickerWidget
      final resized = img.copyResize(cropped, width: 1200, height: 1600);

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/cropped_event_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(resized, quality: 92));

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
                constrained: false,
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

            // Rectangular 3:4 crop overlay with dark surrounding
            if (!_isLoading)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _RectangleCropOverlayPainter(
                      cropWidth: _cropWidth,
                      cropHeight: _cropHeight,
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
                        'Ritaglia immagine',
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
                                'Fatto',
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

            // Bottom instruction with aspect ratio indicator
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.all(NovaSpacing.l),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Aspect ratio badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '3:4',
                          style: NovaTypography.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pizzica per ingrandire • Trascina per spostare',
                        style: NovaTypography.bodySmall.copyWith(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
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

/// Custom painter for rectangular 3:4 crop overlay with dark surround
class _RectangleCropOverlayPainter extends CustomPainter {
  final double cropWidth;
  final double cropHeight;
  final Color overlayColor;

  _RectangleCropOverlayPainter({
    required this.cropWidth,
    required this.cropHeight,
    required this.overlayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;

    // Create path for the entire screen
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Create rectangular hole in the center with rounded corners
    final center = Offset(size.width / 2, size.height / 2);
    final cropRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: cropWidth, height: cropHeight),
      const Radius.circular(8), // Subtle rounded corners
    );

    // Combine paths: full screen minus rectangle (creates hole effect)
    final overlayPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(fullRect),
      Path()..addRRect(cropRect),
    );

    canvas.drawPath(overlayPath, paint);

    // Draw subtle rectangle border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(cropRect, borderPaint);

    // Draw corner indicators for visual guidance
    _drawCornerIndicators(canvas, cropRect, size);
  }

  void _drawCornerIndicators(Canvas canvas, RRect cropRect, Size size) {
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    const cornerLength = 20.0;
    final rect = cropRect.outerRect;

    // Top-left corner
    canvas.drawLine(
      Offset(rect.left, rect.top + cornerLength),
      Offset(rect.left, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      cornerPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.top),
      Offset(rect.right, rect.top),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      cornerPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom - cornerLength),
      Offset(rect.left, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      cornerPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(rect.right - cornerLength, rect.bottom),
      Offset(rect.right, rect.bottom),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RectangleCropOverlayPainter oldDelegate) {
    return oldDelegate.cropWidth != cropWidth ||
        oldDelegate.cropHeight != cropHeight ||
        oldDelegate.overlayColor != overlayColor;
  }
}
