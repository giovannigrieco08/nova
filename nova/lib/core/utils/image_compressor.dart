// Core Utility: ImageCompressor
// Feature: 004-event-creation-moderation
// Purpose: Compress event images to WebP/JPEG with size and dimension limits
//
// Requirements (BeReal-style 3:4 portrait images):
// - Target dimensions: 1080x1440px (3:4 aspect ratio)
// - Max file size: 500KB
// - Format priority: WebP (88% quality) → JPEG fallback (82% quality)
// - EXIF metadata removal (automatic with flutter_image_compress)

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

/// Image compression utility for event cover images
///
/// Compresses images to WebP (primary) or JPEG (fallback) with automatic
/// EXIF metadata removal for privacy.
class ImageCompressor {
  // Prevent instantiation - static utility class
  ImageCompressor._();

  /// Target dimensions (3:4 aspect ratio for BeReal-style portrait images)
  static const int targetWidth = 1080;
  static const int targetHeight = 1440;

  /// Maximum file size in bytes (500KB)
  static const int maxFileSizeBytes = 500 * 1024; // 500KB

  /// Compression quality settings
  static const int webpQuality = 88;
  static const int jpegQuality = 82;

  /// Compress image file to WebP format with fallback to JPEG
  ///
  /// Returns compressed image bytes, or throws [ImageCompressionException]
  /// if compression fails.
  ///
  /// Example:
  /// ```dart
  /// final compressedBytes = await ImageCompressor.compressImage(imageFile);
  /// ```
  static Future<Uint8List> compressImage(File imageFile) async {
    try {
      // Try WebP compression first (better compression, smaller files)
      final webpBytes = await _compressToWebP(imageFile);

      if (webpBytes != null && webpBytes.length <= maxFileSizeBytes) {
        return webpBytes;
      }

      // Fallback to JPEG if WebP fails or exceeds size limit
      final jpegBytes = await _compressToJPEG(imageFile);

      if (jpegBytes != null && jpegBytes.length <= maxFileSizeBytes) {
        return jpegBytes;
      }

      // If still too large, compress JPEG more aggressively
      final aggressiveJpegBytes = await _compressToJPEG(
        imageFile,
        quality: 72, // More aggressive compression (minimum acceptable quality)
      );

      if (aggressiveJpegBytes != null &&
          aggressiveJpegBytes.length <= maxFileSizeBytes) {
        return aggressiveJpegBytes;
      }

      throw ImageCompressionException(
        'Failed to compress image below ${maxFileSizeBytes ~/ 1024}KB. '
        'Final size: ${aggressiveJpegBytes?.length ?? 0 ~/ 1024}KB',
      );
    } catch (e) {
      if (e is ImageCompressionException) rethrow;
      throw ImageCompressionException('Image compression failed: $e');
    }
  }

  /// Compress image to WebP format
  static Future<Uint8List?> _compressToWebP(File imageFile) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        format: CompressFormat.webp,
        quality: webpQuality,
        minWidth: targetWidth,
        minHeight: targetHeight,
        // Automatically removes EXIF metadata (privacy requirement)
        keepExif: false,
      );

      return result;
    } catch (e) {
      // WebP might not be supported on all devices, return null to trigger JPEG fallback
      return null;
    }
  }

  /// Compress image to JPEG format (fallback)
  static Future<Uint8List?> _compressToJPEG(
    File imageFile, {
    int quality = jpegQuality,
  }) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        format: CompressFormat.jpeg,
        quality: quality,
        minWidth: targetWidth,
        minHeight: targetHeight,
        // Automatically removes EXIF metadata (privacy requirement)
        keepExif: false,
      );

      return result;
    } catch (e) {
      return null;
    }
  }

  /// Get compressed image file extension based on format
  static String getImageExtension(Uint8List bytes) {
    // Check magic bytes to determine format
    if (bytes.length >= 12) {
      // WebP signature: "RIFF....WEBP"
      if (bytes[0] == 0x52 && // R
          bytes[1] == 0x49 && // I
          bytes[2] == 0x46 && // F
          bytes[3] == 0x46 && // F
          bytes[8] == 0x57 && // W
          bytes[9] == 0x45 && // E
          bytes[10] == 0x42 && // B
          bytes[11] == 0x50) { // P
        return 'webp';
      }
    }

    // JPEG signature: FF D8 FF
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }

    // Default to jpg for unknown formats
    return 'jpg';
  }

  /// Calculate compression ratio (for debugging/metrics)
  static double calculateCompressionRatio(int originalSize, int compressedSize) {
    if (originalSize == 0) return 0.0;
    return ((originalSize - compressedSize) / originalSize) * 100;
  }
}

/// Exception thrown when image compression fails
class ImageCompressionException implements Exception {
  final String message;

  ImageCompressionException(this.message);

  @override
  String toString() => 'ImageCompressionException: $message';
}
