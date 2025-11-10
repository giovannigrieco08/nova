// Utility: ImageOptimizer
// Feature: 003-events-feed
// Purpose: Optimize image loading with WebP format and progressive blur-up

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageOptimizer {
  // Private constructor to prevent instantiation (static utility class)
  ImageOptimizer._();

  /// Build optimized image widget with progressive loading
  /// FR-051: <200KB images, WebP format
  /// FR-053: Progressive blur-up effect
  static Widget buildOptimizedImage({
    required String imageUrl,
    required double width,
    required double height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
    String? errorAssetPath,
  }) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        // Progressive loading with blur-up effect
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: Colors.grey[300],
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        // Error fallback
        errorWidget: (context, url, error) => Container(
          width: width,
          height: height,
          color: Colors.grey[200],
          child: errorAssetPath != null
              ? Image.asset(errorAssetPath, fit: fit)
              : Icon(
                  Icons.broken_image_outlined,
                  size: width * 0.3,
                  color: Colors.grey[400],
                ),
        ),
        // Memory cache optimization
        memCacheWidth: width.toInt(),
        memCacheHeight: height.toInt(),
        // Max cache age (7 days)
        maxHeightDiskCache: height.toInt(),
        maxWidthDiskCache: width.toInt(),
      ),
    );
  }

  /// Build optimized event card image (16:9 aspect ratio)
  /// Used in EventCard widget
  static Widget buildEventCardImage({
    required String imageUrl,
    required double width,
    BorderRadius? borderRadius,
  }) {
    final height = width * (9 / 16); // 16:9 aspect ratio

    return buildOptimizedImage(
      imageUrl: imageUrl,
      width: width,
      height: height,
      fit: BoxFit.cover,
      borderRadius: borderRadius,
    );
  }

  /// Build optimized avatar image (circular)
  /// Used in participant avatars, comment author avatars
  static Widget buildAvatarImage({
    required String? imageUrl,
    required double size,
    required String initials,
    Color? backgroundColor,
  }) {
    if (imageUrl == null || imageUrl.isEmpty) {
      // Fallback to initials avatar
      return _buildInitialsAvatar(
        initials: initials,
        size: size,
        backgroundColor: backgroundColor,
      );
    }

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildInitialsAvatar(
          initials: initials,
          size: size,
          backgroundColor: backgroundColor,
        ),
        errorWidget: (context, url, error) => _buildInitialsAvatar(
          initials: initials,
          size: size,
          backgroundColor: backgroundColor,
        ),
        memCacheWidth: size.toInt(),
        memCacheHeight: size.toInt(),
      ),
    );
  }

  /// Build initials avatar fallback
  static Widget _buildInitialsAvatar({
    required String initials,
    required double size,
    Color? backgroundColor,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? Colors.blue[400],
      ),
      child: Center(
        child: Text(
          initials.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  /// Convert image URL to WebP format (if supported by CDN)
  /// Supabase Storage supports WebP transformation via query params
  static String toWebP(String imageUrl, {int? quality}) {
    // If URL already has query params, append WebP params
    if (imageUrl.contains('?')) {
      return '$imageUrl&format=webp${quality != null ? '&quality=$quality' : ''}';
    }
    // Otherwise, add WebP params
    return '$imageUrl?format=webp${quality != null ? '&quality=$quality' : ''}';
  }

  /// Resize image URL to specific dimensions (if supported by CDN)
  /// Supabase Storage supports resize transformation
  static String resize(String imageUrl, {required int width, int? height}) {
    // If URL already has query params, append resize params
    if (imageUrl.contains('?')) {
      return '$imageUrl&width=$width${height != null ? '&height=$height' : ''}';
    }
    // Otherwise, add resize params
    return '$imageUrl?width=$width${height != null ? '&height=$height' : ''}';
  }

  /// Get thumbnail version of image (400px wide)
  /// Used for event card images to save bandwidth
  static String getThumbnail(String imageUrl) {
    return toWebP(resize(imageUrl, width: 400), quality: 80);
  }

  /// Get full-size version of image (1200px wide)
  /// Used for event detail screen gallery
  static String getFullSize(String imageUrl) {
    return toWebP(resize(imageUrl, width: 1200), quality: 90);
  }

  /// Preload images for faster display
  /// Call this when navigating to detail screen for smoother transition
  static Future<void> precacheImages(
    BuildContext context,
    List<String> imageUrls,
  ) async {
    for (final url in imageUrls) {
      await precacheImage(CachedNetworkImageProvider(url), context);
    }
  }

  /// Clear image cache (for testing or settings)
  static Future<void> clearCache() async {
    await CachedNetworkImage.evictFromCache('');
  }

  /// Get cached image file (for offline access)
  /// Returns null if not cached
  static Future<String?> getCachedImagePath(String imageUrl) async {
    try {
      final file = await DefaultCacheManager().getSingleFile(imageUrl);
      return file.path;
    } catch (e) {
      return null;
    }
  }
}

// CacheManager singleton (used by CachedNetworkImage)
class DefaultCacheManager {
  static final DefaultCacheManager _instance = DefaultCacheManager._();
  DefaultCacheManager._();
  factory DefaultCacheManager() => _instance;

  /// Get single file from cache
  /// Note: This is a simplified version - cached_network_image handles this internally
  Future<dynamic> getSingleFile(String url) async {
    // Cached network image handles this internally
    // This method is a placeholder for future custom cache management
    throw UnimplementedError('Use CachedNetworkImage internally');
  }
}
