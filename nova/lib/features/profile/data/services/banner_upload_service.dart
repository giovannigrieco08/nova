// Service: BannerUploadService
// Feature: 014-profile-banner
// Purpose: Handle banner image upload to Supabase Storage with compression

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for uploading and managing profile banner images
///
/// Features:
/// - Image compression (max 300KB per constitution)
/// - JPEG format conversion for optimal size
/// - 3:1 aspect ratio (1200x400px)
/// - Supabase Storage integration (banners bucket)
/// - Public URL generation (permanent, no expiry)
/// - Automatic cleanup of old banners
class BannerUploadService {
  final SupabaseClient _supabase;

  /// Banner dimensions (3:1 aspect ratio)
  static const int bannerWidth = 1200;
  static const int bannerHeight = 400;

  /// Minimum input dimensions
  static const int minWidth = 600;
  static const int minHeight = 200;

  /// Max file size after compression (300KB)
  static const int maxFileSizeBytes = 300 * 1024;

  BannerUploadService(this._supabase);

  /// Upload banner image to Supabase Storage
  ///
  /// Steps:
  /// 1. Validate minimum dimensions
  /// 2. Resize to 1200x400 (3:1 aspect ratio)
  /// 3. Compress to JPEG <300KB
  /// 4. Delete old banner if exists
  /// 5. Upload to banners bucket
  /// 6. Return public URL
  ///
  /// Returns: Public URL for banner
  /// Throws: BannerUploadException on failure
  Future<String> uploadBanner({
    required String userId,
    required File imageFile,
    Function(double progress)? onProgress,
  }) async {
    try {
      // Step 1: Read and validate image
      if (onProgress != null) onProgress(0.1);
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw BannerUploadException('Invalid image file');
      }

      // Validate minimum dimensions
      if (image.width < minWidth || image.height < minHeight) {
        throw BannerUploadException(
          'Image too small. Minimum size: ${minWidth}x${minHeight}px',
        );
      }

      if (onProgress != null) onProgress(0.2);

      // Step 2: Resize and compress
      final compressedImage = await _compressImage(image);

      if (onProgress != null) onProgress(0.5);

      // Step 3: Generate unique file name
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$userId/$fileName';

      // Step 4: Delete old banner if exists (cleanup)
      await _deleteOldBanner(userId);

      if (onProgress != null) onProgress(0.6);

      // Step 5: Upload to Supabase Storage
      await _supabase.storage.from('banners').uploadBinary(
            filePath,
            compressedImage,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              cacheControl: '3600', // 1 hour cache
              upsert: true,
            ),
          );

      if (onProgress != null) onProgress(0.9);

      // Step 6: Get public URL (permanent, no expiry)
      final publicUrl = _supabase.storage
          .from('banners')
          .getPublicUrl(filePath);

      if (onProgress != null) onProgress(1.0);

      return publicUrl;
    } on BannerUploadException {
      rethrow;
    } catch (e) {
      throw BannerUploadException('Failed to upload banner: ${e.toString()}');
    }
  }

  /// Compress and resize image to banner specifications
  ///
  /// Target: 1200x400 JPEG, <300KB
  Future<Uint8List> _compressImage(img.Image image) async {
    try {
      // Calculate crop area for 3:1 aspect ratio (center crop)
      final targetRatio = bannerWidth / bannerHeight; // 3.0
      final imageRatio = image.width / image.height;

      img.Image cropped;
      if (imageRatio > targetRatio) {
        // Image is wider than target - crop width
        final newWidth = (image.height * targetRatio).round();
        final x = ((image.width - newWidth) / 2).round();
        cropped = img.copyCrop(image, x: x, y: 0, width: newWidth, height: image.height);
      } else {
        // Image is taller than target - crop height
        final newHeight = (image.width / targetRatio).round();
        final y = ((image.height - newHeight) / 2).round();
        cropped = img.copyCrop(image, x: 0, y: y, width: image.width, height: newHeight);
      }

      // Resize to target dimensions
      final resized = img.copyResize(
        cropped,
        width: bannerWidth,
        height: bannerHeight,
        interpolation: img.Interpolation.linear,
      );

      // Encode to JPEG with quality adjustment to meet size target
      var quality = 85;
      Uint8List compressed;

      do {
        compressed = Uint8List.fromList(
          img.encodeJpg(resized, quality: quality),
        );

        // Reduce quality if still too large
        if (compressed.lengthInBytes > maxFileSizeBytes && quality > 50) {
          quality -= 5;
        } else {
          break;
        }
      } while (compressed.lengthInBytes > maxFileSizeBytes);

      return compressed;
    } catch (e) {
      throw BannerUploadException('Failed to compress image: ${e.toString()}');
    }
  }

  /// Delete old banner files for user (cleanup)
  Future<void> _deleteOldBanner(String userId) async {
    try {
      // List all files in user's folder
      final files = await _supabase.storage.from('banners').list(path: userId);

      // Delete each file
      for (final file in files) {
        await _supabase.storage.from('banners').remove(['$userId/${file.name}']);
      }
    } catch (e) {
      // Non-critical error - ignore but don't throw
    }
  }

  /// Delete banner for user (for profile update or banner removal)
  Future<void> deleteBanner(String userId) async {
    try {
      await _deleteOldBanner(userId);
    } catch (e) {
      throw BannerUploadException('Failed to delete banner: ${e.toString()}');
    }
  }

  /// Convert a signed URL to a public URL
  ///
  /// Signed URLs contain "token=" and expire after 1 hour.
  /// This extracts the path and returns a permanent public URL.
  /// Returns the original URL if it's already public or invalid.
  String normalizeBannerUrl(String? signedUrl) {
    if (signedUrl == null || signedUrl.isEmpty) return '';

    // If URL doesn't contain token, it's already public
    if (!signedUrl.contains('token=')) return signedUrl;

    try {
      // Extract the path from the signed URL
      // Format: .../storage/v1/object/sign/banners/userId/filename?token=...
      // Target: .../storage/v1/object/public/banners/userId/filename
      final uri = Uri.parse(signedUrl);
      final pathSegments = uri.pathSegments.toList();

      // Find 'sign' and replace with 'public'
      final signIndex = pathSegments.indexOf('sign');
      if (signIndex != -1) {
        pathSegments[signIndex] = 'public';

        // Reconstruct URL without query parameters
        final publicUrl = Uri(
          scheme: uri.scheme,
          host: uri.host,
          pathSegments: pathSegments,
        ).toString();

        return publicUrl;
      }
    } catch (e) {
      // If parsing fails, return original URL
    }

    return signedUrl;
  }

  /// Get banner URL for user (public URL, no expiry)
  Future<String?> getBannerUrl(String userId) async {
    try {
      // List files in user's folder
      final files = await _supabase.storage.from('banners').list(path: userId);

      if (files.isEmpty) {
        return null; // No banner uploaded
      }

      // Get most recent file (sorted by name which includes timestamp)
      final latestFile = files.reduce((a, b) =>
          a.name.compareTo(b.name) > 0 ? a : b);

      // Get public URL (permanent, no expiry)
      final publicUrl = _supabase.storage
          .from('banners')
          .getPublicUrl('$userId/${latestFile.name}');

      return publicUrl;
    } catch (e) {
      return null;
    }
  }
}

/// Custom exception for banner upload errors
class BannerUploadException implements Exception {
  final String message;

  BannerUploadException(this.message);

  @override
  String toString() => 'BannerUploadException: $message';
}
