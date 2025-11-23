// Service: AvatarUploadService (AvatarStorageDatasource)
// Feature: 006-user-profile (evolved from 002-profile-setup)
// Purpose: Handle avatar image upload to Supabase Storage with WebP compression

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for uploading and managing avatar images
///
/// Features:
/// - Image compression to <500KB target (spec: FR-013)
/// - WebP format conversion for optimal size/quality
/// - Supabase Storage integration (public avatars bucket)
/// - Public URLs (bucket is public per migration)
/// - Automatic cleanup of old avatars
class AvatarUploadService {
  final SupabaseClient _supabase;

  AvatarUploadService(this._supabase);

  /// Upload avatar image to Supabase Storage
  ///
  /// Steps:
  /// 1. Compress image to <500KB WebP format
  /// 2. Upload to avatars bucket at {user_id}/avatar.webp
  /// 3. Delete old avatar (cleanup)
  /// 4. Return public URL
  ///
  /// Returns: Public URL for avatar (permanent, no expiry)
  /// Throws: AvatarUploadException on failure
  Future<String> uploadAvatar({
    required String userId,
    required File imageFile,
    Function(double progress)? onProgress,
  }) async {
    try {
      // Step 1: Compress and optimize image to WebP
      if (onProgress != null) onProgress(0.1);
      final compressedImage = await _compressImageToWebP(imageFile);

      if (onProgress != null) onProgress(0.5);

      // Step 2: Fixed file path (always avatar.webp, upsert replaces old one)
      final filePath = '$userId/avatar.webp';

      if (onProgress != null) onProgress(0.6);

      // Step 3: Upload to Supabase Storage (upsert=true replaces old file)
      await _supabase.storage.from('avatars').uploadBinary(
            filePath,
            compressedImage,
            fileOptions: const FileOptions(
              contentType: 'image/webp',
              cacheControl: '86400', // 24 hours cache for CDN
              upsert: true, // Replace existing file
            ),
          );

      if (onProgress != null) onProgress(0.9);

      // Step 4: Get public URL (bucket is public, no signature needed)
      final publicUrl = _supabase.storage.from('avatars').getPublicUrl(filePath);

      if (onProgress != null) onProgress(1.0);

      return publicUrl;
    } catch (e) {
      throw AvatarUploadException('Failed to upload avatar: ${e.toString()}');
    }
  }

  /// Compress image to WebP format with target <500KB
  ///
  /// Uses flutter_image_compress for native WebP encoding
  /// Target: <500KB (spec: FR-013)
  /// Format: WebP (better compression than PNG/JPEG)
  /// Size: 512x512 (retina-quality for circular avatars)
  Future<Uint8List> _compressImageToWebP(File imageFile) async {
    try {
      // Compress to WebP with quality 85 (good balance of size/quality)
      var quality = 85;
      Uint8List? compressed;

      do {
        compressed = await FlutterImageCompress.compressWithFile(
          imageFile.absolute.path,
          minWidth: 512,
          minHeight: 512,
          quality: quality,
          format: CompressFormat.webp,
        );

        // If null or still too large, reduce quality
        if (compressed == null) {
          throw AvatarUploadException('Failed to compress image to WebP');
        }

        if (compressed.lengthInBytes > 500 * 1024 && quality > 60) {
          quality -= 5; // Reduce quality in steps of 5
        } else {
          break;
        }
      } while (compressed.lengthInBytes > 500 * 1024 && quality >= 60);

      assert(() {
        debugPrint(
          'Avatar compressed: ${(compressed!.lengthInBytes / 1024).toStringAsFixed(2)} KB (quality: $quality)',
        );
        return true;
      }());

      return compressed;
    } catch (e) {
      throw AvatarUploadException(
          'Failed to compress image: ${e.toString()}');
    }
  }

  /// Delete avatar for user (GDPR Right to Erasure or manual removal)
  /// Removes avatar.webp from {user_id}/ folder
  Future<void> deleteAvatar(String userId) async {
    try {
      final filePath = '$userId/avatar.webp';
      await _supabase.storage.from('avatars').remove([filePath]);
    } catch (e) {
      throw AvatarUploadException(
          'Failed to delete avatar: ${e.toString()}');
    }
  }

  /// Get avatar URL for user (public URL, no expiry)
  /// Returns null if no avatar exists
  String getAvatarUrl(String userId) {
    final filePath = '$userId/avatar.webp';
    return _supabase.storage.from('avatars').getPublicUrl(filePath);
  }

  /// Check if avatar exists for user
  /// Useful for showing avatar placeholder vs actual image
  Future<bool> hasAvatar(String userId) async {
    try {
      final files = await _supabase.storage.from('avatars').list(path: userId);
      return files.any((file) => file.name == 'avatar.webp');
    } catch (e) {
      assert(() {
        debugPrint('Failed to check avatar existence: ${e.toString()}');
        return true;
      }());
      return false;
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
