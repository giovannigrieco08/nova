import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/animations/heart_explosion_animation.dart';

/// Image section: 3:4 aspect ratio, full width, with double-tap like overlay.
class EventCardImage extends StatelessWidget {
  final String? imageUrl;
  final String? emoji;
  final bool isLiked;
  final bool isProcessing;
  final VoidCallback? onDoubleTapLike;

  const EventCardImage({
    super.key,
    this.imageUrl,
    this.emoji,
    required this.isLiked,
    required this.isProcessing,
    this.onDoubleTapLike,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: ClipRRect(
          borderRadius: NovaRadius.circularS,
          child: DoubleTapLikeOverlay(
            onDoubleTap: isLiked || isProcessing ? null : onDoubleTapLike,
            child: emoji != null
                ? _buildEmojiPlaceholder(emoji!)
                : imageUrl != null
                    ? _buildNetworkImage(imageUrl!)
                    : _buildDefaultPlaceholder(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiPlaceholder(String emoji) {
    return Container(
      color: NovaColors.placeholder,
      child: Center(
        child: Text(emoji, style: const TextStyle(fontSize: 120)),
      ),
    );
  }

  Widget _buildNetworkImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: NovaColors.placeholder,
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => _buildDefaultPlaceholder(),
    );
  }

  Widget _buildDefaultPlaceholder() {
    return Container(
      color: NovaColors.placeholder,
      child: const Center(
        child: Icon(Icons.event_rounded, size: 64, color: NovaColors.handleBar),
      ),
    );
  }
}
