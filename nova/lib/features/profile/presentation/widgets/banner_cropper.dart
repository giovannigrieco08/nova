// Widget: BannerCropper
// Feature: 014-profile-banner
// Purpose: 3:1 aspect ratio crop interface for banner images

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_typography.dart';

/// Banner cropper with 3:1 aspect ratio rectangular mask
///
/// Features:
/// - Smooth pinch-to-zoom and drag gestures via InteractiveViewer
/// - 3:1 rectangular crop overlay with dark surrounding
/// - iOS-style dark immersive UI
/// - Outputs 1200x400px image
class BannerCropper extends StatefulWidget {
  final File imageFile;
  final Function(File croppedFile) onCropComplete;

  const BannerCropper({
    super.key,
    required this.imageFile,
    required this.onCropComplete,
  });

  /// Show banner cropper as full-screen modal
  static Future<File?> show(BuildContext context, File imageFile) async {
    return Navigator.of(context).push<File>(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return BannerCropper(
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
  State<BannerCropper> createState() => _BannerCropperState();
}

class _BannerCropperState extends State<BannerCropper> {
  final TransformationController _transformationController =
      TransformationController();
  final GlobalKey _imageKey = GlobalKey();

  bool _isLoading = true;
  bool _isCropping = false;
  ui.Image? _uiImage;
  Size _imageSize = Size.zero;
  Size _displayedImageSize = Size.zero;

  // Crop rectangle dimensions (3:1 aspect ratio)
  late double _cropWidth;
  late double _cropHeight;

  // Banner output dimensions
  static const int outputWidth = 1200;
  static const int outputHeight = 400;

  // Minimum input dimensions
  static const int minWidth = 600;
  static const int minHeight = 200;

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
    // Calculate crop size based on screen width (90% of screen width, 3:1 ratio)
    final screenWidth = MediaQuery.of(context).size.width;
    _cropWidth = screenWidth * 0.9;
    _cropHeight = _cropWidth / 3; // 3:1 aspect ratio
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();

      if (mounted) {
        // Validate minimum dimensions
        if (frame.image.width < minWidth || frame.image.height < minHeight) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Immagine troppo piccola. Minimo: ${minWidth}x${minHeight}px'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

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
      displayWidth = screenSize.width;
      displayHeight = screenSize.width / imageAspect;
    } else {
      displayHeight = screenSize.height;
      displayWidth = screenSize.height * imageAspect;
    }

    _displayedImageSize = Size(displayWidth, displayHeight);

    // Calculate minimum scale to cover the crop rectangle
    final scaleToFillWidth = _cropWidth / displayWidth;
    final scaleToFillHeight = _cropHeight / displayHeight;
    final minScale = math.max(scaleToFillWidth, scaleToFillHeight);

    // Start with image scaled to fill crop area
    final initialScale = minScale * 1.1;

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

      // Base offset before transform
      final baseOffsetX = (screenSize.width - _displayedImageSize.width) / 2;
      final baseOffsetY = (screenSize.height - _displayedImageSize.height) / 2;

      // Image position after transform
      final imageLeft = scale * baseOffsetX + translationX;
      final imageTop = scale * baseOffsetY + translationY;

      // Scaled image dimensions
      final scaledWidth = _displayedImageSize.width * scale;
      final scaledHeight = _displayedImageSize.height * scale;

      // Crop area in displayed image coordinates
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

      // Load and crop image
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

      // Crop to rectangle
      final cropped = img.copyCrop(
        originalImage,
        x: clampedX,
        y: clampedY,
        width: clampedWidth.toInt(),
        height: clampedHeight.toInt(),
      );

      // Resize to standard banner size (1200x400)
      final resized = img.copyResize(
        cropped,
        width: outputWidth,
        height: outputHeight,
        interpolation: img.Interpolation.linear,
      );

      // Save to temporary file
      final tempDir = Directory.systemTemp;
      final tempFile = File(
          '${tempDir.path}/cropped_banner_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(resized, quality: 85));

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
            // Image with InteractiveViewer
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

            // Rectangular crop overlay with dark surrounding
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
                        'Ritaglia banner',
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
                    'Pizzica per ingrandire \u2022 Trascina per spostare',
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

/// Custom painter for rectangular crop overlay (3:1 aspect ratio)
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

    // Full screen rect
    final fullRect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Crop rectangle in center
    final center = Offset(size.width / 2, size.height / 2);
    final cropRect = Rect.fromCenter(
      center: center,
      width: cropWidth,
      height: cropHeight,
    );

    // Create hole effect
    final overlayPath = Path.combine(
      PathOperation.difference,
      Path()..addRect(fullRect),
      Path()..addRRect(RRect.fromRectAndRadius(cropRect, const Radius.circular(8))),
    );

    canvas.drawPath(overlayPath, paint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(
      RRect.fromRectAndRadius(cropRect, const Radius.circular(8)),
      borderPaint,
    );

    // Draw corner indicators
    final cornerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 20.0;
    final corners = [
      // Top-left
      [Offset(cropRect.left, cropRect.top + cornerLength), Offset(cropRect.left, cropRect.top), Offset(cropRect.left + cornerLength, cropRect.top)],
      // Top-right
      [Offset(cropRect.right - cornerLength, cropRect.top), Offset(cropRect.right, cropRect.top), Offset(cropRect.right, cropRect.top + cornerLength)],
      // Bottom-left
      [Offset(cropRect.left, cropRect.bottom - cornerLength), Offset(cropRect.left, cropRect.bottom), Offset(cropRect.left + cornerLength, cropRect.bottom)],
      // Bottom-right
      [Offset(cropRect.right - cornerLength, cropRect.bottom), Offset(cropRect.right, cropRect.bottom), Offset(cropRect.right, cropRect.bottom - cornerLength)],
    ];

    for (final corner in corners) {
      canvas.drawLine(corner[0], corner[1], cornerPaint);
      canvas.drawLine(corner[1], corner[2], cornerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _RectangleCropOverlayPainter oldDelegate) {
    return oldDelegate.cropWidth != cropWidth ||
        oldDelegate.cropHeight != cropHeight ||
        oldDelegate.overlayColor != overlayColor;
  }
}
