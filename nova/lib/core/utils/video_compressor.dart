// Core Utility: VideoCompressor
// Purpose: Compress videos before upload to reduce file size and bandwidth
//
// Requirements:
// - Compress videos larger than threshold (10MB by default)
// - Target quality: Medium (good balance between size and quality)
// - Output format: MP4 (widely supported)
// - Returns path to compressed file

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:video_compress/video_compress.dart';

/// Video compression utility for chat media uploads
///
/// Compresses videos to reduce file size before uploading to storage.
/// Uses medium quality preset for good balance between size and quality.
class VideoCompressor {
  // Prevent instantiation - static utility class
  VideoCompressor._();

  /// Compression threshold in bytes (10MB)
  /// Videos smaller than this will not be compressed
  static const int compressionThresholdBytes = 10 * 1024 * 1024; // 10MB

  /// Maximum file size in bytes (50MB) - matches Supabase bucket limit
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50MB

  /// Compress video if needed
  ///
  /// Returns the path to the compressed video, or the original path if
  /// compression is not needed or fails.
  ///
  /// Compression is skipped if:
  /// - File is smaller than [compressionThresholdBytes]
  /// - Running on web (not supported)
  ///
  /// Example:
  /// ```dart
  /// final compressedPath = await VideoCompressor.compressIfNeeded(videoFile.path);
  /// ```
  static Future<String> compressIfNeeded(String filePath) async {
    // Skip on web - video_compress doesn't support web
    if (kIsWeb) {
      debugPrint('[VideoCompressor] Skipping compression on web');
      return filePath;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('[VideoCompressor] File does not exist: $filePath');
        return filePath;
      }

      final fileSize = await file.length();
      debugPrint(
          '[VideoCompressor] Original file size: ${_formatSize(fileSize)}');

      // Skip compression if file is small enough
      if (fileSize < compressionThresholdBytes) {
        debugPrint(
            '[VideoCompressor] File is small enough, skipping compression');
        return filePath;
      }

      // Check if file is too large even for compression
      if (fileSize > maxFileSizeBytes * 2) {
        debugPrint(
            '[VideoCompressor] File is very large, compression may take a while');
      }

      debugPrint('[VideoCompressor] Starting compression...');

      // Compress with medium quality (good balance)
      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        filePath,
        quality: VideoQuality.MediumQuality,
        deleteOrigin: false, // Keep original file
        includeAudio: true,
      );

      if (mediaInfo == null || mediaInfo.path == null) {
        debugPrint('[VideoCompressor] Compression failed, using original');
        return filePath;
      }

      final compressedFile = File(mediaInfo.path!);
      if (!await compressedFile.exists()) {
        debugPrint(
            '[VideoCompressor] Compressed file not found, using original');
        return filePath;
      }

      final compressedSize = await compressedFile.length();
      final compressionRatio =
          _calculateCompressionRatio(fileSize, compressedSize);

      debugPrint(
          '[VideoCompressor] Compressed size: ${_formatSize(compressedSize)}');
      debugPrint(
          '[VideoCompressor] Compression ratio: ${compressionRatio.toStringAsFixed(1)}%');

      // Only use compressed version if it's actually smaller
      if (compressedSize >= fileSize) {
        debugPrint(
            '[VideoCompressor] Compressed file is not smaller, using original');
        // Clean up compressed file
        await compressedFile.delete();
        return filePath;
      }

      // Check if compressed file is still too large
      if (compressedSize > maxFileSizeBytes) {
        debugPrint(
            '[VideoCompressor] Compressed file still too large: ${_formatSize(compressedSize)}');
        // Try more aggressive compression
        final aggressiveResult = await _compressAggressive(filePath);
        if (aggressiveResult != null) {
          // Clean up medium quality compressed file
          await compressedFile.delete();
          return aggressiveResult;
        }
        // Fall through to use the medium quality compression anyway
      }

      debugPrint('[VideoCompressor] Compression successful!');
      return mediaInfo.path!;
    } catch (e, stackTrace) {
      debugPrint('[VideoCompressor] Error during compression: $e');
      debugPrint('[VideoCompressor] Stack: $stackTrace');
      // Return original file path on error
      return filePath;
    }
  }

  /// Aggressive compression for very large files
  static Future<String?> _compressAggressive(String filePath) async {
    try {
      debugPrint(
          '[VideoCompressor] Trying aggressive compression (LowQuality)...');

      final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
        filePath,
        quality: VideoQuality.LowQuality,
        deleteOrigin: false,
        includeAudio: true,
      );

      if (mediaInfo?.path == null) return null;

      final compressedFile = File(mediaInfo!.path!);
      final compressedSize = await compressedFile.length();

      debugPrint(
          '[VideoCompressor] Aggressive compressed size: ${_formatSize(compressedSize)}');

      if (compressedSize > maxFileSizeBytes) {
        debugPrint(
            '[VideoCompressor] Still too large after aggressive compression');
        await compressedFile.delete();
        return null;
      }

      return mediaInfo.path;
    } catch (e) {
      debugPrint('[VideoCompressor] Aggressive compression failed: $e');
      return null;
    }
  }

  /// Cancel any ongoing compression
  static Future<void> cancelCompression() async {
    try {
      await VideoCompress.cancelCompression();
      debugPrint('[VideoCompressor] Compression cancelled');
    } catch (e) {
      debugPrint('[VideoCompressor] Error cancelling compression: $e');
    }
  }

  /// Delete all temporary compressed files
  static Future<void> deleteAllCompressedFiles() async {
    try {
      await VideoCompress.deleteAllCache();
      debugPrint('[VideoCompressor] Deleted all compressed file cache');
    } catch (e) {
      debugPrint('[VideoCompressor] Error deleting cache: $e');
    }
  }

  /// Format file size for logging
  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Calculate compression ratio percentage
  static double _calculateCompressionRatio(
      int originalSize, int compressedSize) {
    if (originalSize == 0) return 0.0;
    return ((originalSize - compressedSize) / originalSize) * 100;
  }
}

/// Exception thrown when video compression fails critically
class VideoCompressionException implements Exception {
  final String message;

  VideoCompressionException(this.message);

  @override
  String toString() => 'VideoCompressionException: $message';
}
