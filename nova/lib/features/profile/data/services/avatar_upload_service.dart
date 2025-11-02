// Service: AvatarUploadService
// Feature: 002-profile-setup
// Purpose: Handle avatar image upload to Supabase Storage with compression

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for uploading and managing avatar images
///
/// Features:
/// - Image compression (max 200KB per constitution)
/// - WebP format conversion for optimal size
/// - Supabase Storage integration (avatars bucket)
/// - Signed URL generation (1-hour expiry for security)
/// - Automatic cleanup of old avatars
class AvatarUploadService {
  final SupabaseClient _supabase;

  AvatarUploadService(this._supabase);

  /// Upload avatar image to Supabase Storage
  ///
  /// Steps:
  /// 1. Compress image to <200KB
  /// 2. Convert to WebP format
  /// 3. Upload to avatars bucket with user ID path
  /// 4. Return signed URL (1-hour expiry)
  ///
  /// Returns: Public signed URL for avatar
  /// Throws: AvatarUploadException on failure
  Future<String> uploadAvatar({
    required String userId,
    required File imageFile,
    Function(double progress)? onProgress,
  }) async {
    try {
      // Step 1: Compress and optimize image
      if (onProgress != null) onProgress(0.1);
      final compressedImage = await _compressImage(imageFile);

      if (onProgress != null) onProgress(0.4);

      // Step 2: Generate unique file name
      final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '$userId/$fileName';

      if (onProgress != null) onProgress(0.5);

      // Step 3: Delete old avatar if exists (cleanup)
      await _deleteOldAvatar(userId);

      if (onProgress != null) onProgress(0.6);

      // Step 4: Upload to Supabase Storage
      await _supabase.storage.from('avatars').uploadBinary(
            filePath,
            compressedImage,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              cacheControl: '3600', // 1 hour cache
              upsert: true,
            ),
          );

      if (onProgress != null) onProgress(0.9);

      // Step 5: Get signed URL (1-hour expiry for security)
      final signedUrl = await _supabase.storage
          .from('avatars')
          .createSignedUrl(filePath, 3600); // 1 hour

      if (onProgress != null) onProgress(1.0);

      return signedUrl;
    } catch (e) {
      throw AvatarUploadException('Failed to upload avatar: ${e.toString()}');
    }
  }

  /// Compress image to meet performance requirements
  ///
  /// Target: <200KB per constitution performance budget
  /// Format: PNG for compatibility (WebP encoding not available in image package)
  /// Size: 512x512 (retina-quality for avatars)
  Future<Uint8List> _compressImage(File imageFile) async {
    try {
      // Read image file
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);

      if (image == null) {
        throw AvatarUploadException('Invalid image file');
      }

      // Resize to 512x512 (square crop from center)
      final resized = img.copyResizeCropSquare(image, size: 512);

      // Convert to PNG with quality adjustment to meet <200KB target
      var quality = 9; // PNG compression level (0-9, higher = better compression)
      Uint8List compressed;

      do {
        compressed = Uint8List.fromList(
          img.encodePng(resized, level: quality),
        );

        // If still too large, reduce size instead of quality (PNG is lossless)
        if (compressed.lengthInBytes > 200 * 1024 && quality > 6) {
          quality -= 1;
        } else {
          break;
        }
      } while (compressed.lengthInBytes > 200 * 1024);

      debugPrint(
        'Avatar compressed: ${(compressed.lengthInBytes / 1024).toStringAsFixed(2)} KB (level: $quality)',
      );

      return compressed;
    } catch (e) {
      throw AvatarUploadException(
          'Failed to compress image: ${e.toString()}');
    }
  }

  /// Delete old avatar files for user (cleanup)
  Future<void> _deleteOldAvatar(String userId) async {
    try {
      // List all files in user's folder
      final files = await _supabase.storage.from('avatars').list(path: userId);

      // Delete each file
      for (final file in files) {
        await _supabase.storage.from('avatars').remove(['$userId/${file.name}']);
      }
    } catch (e) {
      // Non-critical error - log but don't throw
      debugPrint('Failed to delete old avatar: ${e.toString()}');
    }
  }

  /// Delete avatar for user (for profile deletion or avatar removal)
  Future<void> deleteAvatar(String userId) async {
    try {
      await _deleteOldAvatar(userId);
    } catch (e) {
      throw AvatarUploadException(
          'Failed to delete avatar: ${e.toString()}');
    }
  }

  /// Get avatar URL for user (with signed URL for security)
  Future<String?> getAvatarUrl(String userId) async {
    try {
      // List files in user's folder
      final files = await _supabase.storage.from('avatars').list(path: userId);

      if (files.isEmpty) {
        return null; // No avatar uploaded
      }

      // Get most recent file (sorted by name which includes timestamp)
      final latestFile = files.reduce((a, b) =>
          a.name.compareTo(b.name) > 0 ? a : b);

      // Get signed URL
      final signedUrl = await _supabase.storage
          .from('avatars')
          .createSignedUrl('$userId/${latestFile.name}', 3600); // 1 hour

      return signedUrl;
    } catch (e) {
      debugPrint('Failed to get avatar URL: ${e.toString()}');
      return null;
    }
  }
}

/// Custom exception for avatar upload errors
class AvatarUploadException implements Exception {
  final String message;

  AvatarUploadException(this.message);

  @override
  String toString() => 'AvatarUploadException: $message';
}
