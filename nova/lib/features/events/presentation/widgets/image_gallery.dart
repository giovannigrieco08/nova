// =====================================================================
// Nova - Image Gallery Widget
// =====================================================================
// Purpose: Swipeable image gallery with dot indicators for event details
// Architecture: PageView with AnimatedContainer dot indicators
// =====================================================================

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_spacing.dart';
import '../../../../core/theme/nova_radius.dart';

/// Swipeable image gallery with pagination indicators
///
/// Features:
/// - 16:9 aspect ratio images
/// - Horizontal swipe gesture
/// - Dot indicators (active/inactive states)
/// - Cached image loading with placeholder
/// - Supports single image (no indicators shown)
///
/// Usage:
/// ```dart
/// ImageGallery(
///   images: event.coverImages,
///   heroTag: 'event-${event.id}',
/// )
/// ```
class ImageGallery extends StatefulWidget {
  /// List of image URLs to display
  final List<String> images;

  /// Optional Hero tag for animation from feed
  final String? heroTag;

  /// Optional aspect ratio (default: 16/9 for Instagram-style)
  final double aspectRatio;

  const ImageGallery({
    super.key,
    required this.images,
    this.heroTag,
    this.aspectRatio = 16 / 9,
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
            padding: const EdgeInsets.symmetric(vertical: NovaSpacing.m),
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(NovaRadius.l),
        ),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            color: NovaColors.surface(context),
            child: Center(
              child: CircularProgressIndicator(
                color: NovaColors.primary(context),
                strokeWidth: 2,
              ),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            color: NovaColors.surface(context),
            child: Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                size: 64,
                color: NovaColors.textSecondary(context),
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
        color: NovaColors.surface(context),
        child: Center(
          child: CircularProgressIndicator(
            color: NovaColors.primary(context),
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: NovaColors.surface(context),
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            size: 64,
            color: NovaColors.textSecondary(context),
          ),
        ),
      ),
    );

    // Wrap first image with Hero if tag provided
    if (isFirst && widget.heroTag != null) {
      return Hero(
        tag: widget.heroTag!,
        child: ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(NovaRadius.l),
          ),
          child: imageWidget,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(NovaRadius.l),
      ),
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

  /// Build single dot indicator
  Widget _buildDot(int index) {
    final isActive = index == _currentPage;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: NovaSpacing.xxs),
      width: isActive ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? NovaColors.primary(context)
            : NovaColors.textTertiary(context),
        borderRadius: BorderRadius.circular(NovaRadius.full),
      ),
    );
  }
}
