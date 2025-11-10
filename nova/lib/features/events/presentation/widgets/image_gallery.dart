// =====================================================================
// Nova - Image Gallery Widget (Instagram-style)
// =====================================================================
// Purpose: Swipeable image gallery with dot indicators
// Architecture: PageView with native Material components
// =====================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Swipeable image gallery with pagination indicators (Instagram-style)
///
/// Features:
/// - 1:1 aspect ratio images (square, Instagram-style)
/// - Horizontal swipe gesture
/// - Dot indicators (active/inactive states)
/// - Cached image loading with placeholder
/// - Supports single image (no indicators shown)
///
/// Usage:
/// ```dart
/// // For events with single image (Feature 004+):
/// ImageGallery(
///   images: event.imageUrl != null ? [event.imageUrl!] : [],
///   heroTag: 'event-${event.id}',
/// )
/// // Or for generic multi-image galleries:
/// ImageGallery(
///   images: galleryUrls,
///   heroTag: 'gallery-${id}',
/// )
/// ```
class ImageGallery extends StatefulWidget {
  /// List of image URLs to display
  final List<String> images;

  /// Optional Hero tag for animation from feed
  final String? heroTag;

  /// Optional aspect ratio (default: 1.0 for Instagram-style square)
  final double aspectRatio;

  const ImageGallery({
    super.key,
    required this.images,
    this.heroTag,
    this.aspectRatio = 1.0, // Changed to 1:1 (Instagram square)
  });

  @override
  State<ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<ImageGallery> {
  /// Current page index
  int _currentPage = 0;

  /// PageView controller
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Single image case - no pagination needed
    if (widget.images.length == 1) {
      return _buildSingleImage(widget.images.first);
    }

    // Multiple images - show gallery with indicators
    return Column(
      children: [
        // Image gallery
        AspectRatio(
          aspectRatio: widget.aspectRatio,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.images.length,
            itemBuilder: (context, index) {
              return _buildImage(widget.images[index], index == 0);
            },
          ),
        ),

        // Dot indicators
        if (widget.images.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: _buildDotIndicators(),
          ),
      ],
    );
  }

  /// Build single image (with optional Hero animation)
  Widget _buildSingleImage(String imageUrl) {
    final imageWidget = AspectRatio(
      aspectRatio: widget.aspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14), // Instagram-style rounded corners
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: const Color(0xFFF0F0F0), // Light gray placeholder
            child: const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF737373), // Instagram gray
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: const Color(0xFFF0F0F0),
            child: const Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 64,
                color: Color(0xFF737373),
              ),
            ),
          ),
        ),
      ),
    );

    // Wrap with Hero if tag provided (for first image only)
    if (widget.heroTag != null) {
      return Hero(
        tag: widget.heroTag!,
        child: imageWidget,
      );
    }

    return imageWidget;
  }

  /// Build image with optional Hero animation (for first image in gallery)
  Widget _buildImage(String imageUrl, bool isFirst) {
    final imageWidget = CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: const Color(0xFFF0F0F0),
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF737373),
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: const Color(0xFFF0F0F0),
        child: const Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 64,
            color: Color(0xFF737373),
          ),
        ),
      ),
    );

    // Wrap first image with Hero if tag provided
    if (isFirst && widget.heroTag != null) {
      return Hero(
        tag: widget.heroTag!,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: imageWidget,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: imageWidget,
    );
  }

  /// Build dot indicators for pagination
  Widget _buildDotIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        widget.images.length,
        (index) => _buildDot(index),
      ),
    );
  }

  /// Build single dot indicator (Instagram-style)
  Widget _buildDot(int index) {
    final isActive = index == _currentPage;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: isActive ? 8 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF0095f6) // Instagram blue for active
            : const Color(0xFFDBDBDB), // Light gray for inactive
        shape: BoxShape.circle,
      ),
    );
  }
}
