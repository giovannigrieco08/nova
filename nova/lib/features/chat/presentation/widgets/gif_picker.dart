import 'package:flutter/material.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_radius.dart';

/// A GIF picker widget that uses GIPHY/Tenor.
///
/// Shows a bottom sheet with trending GIFs and search functionality.
/// Returns the selected GIF's URL and ID.
class GifPicker {
  /// Show the GIF picker bottom sheet and return selected GIF info.
  ///
  /// Returns a record with (gifUrl, gifId) or null if cancelled.
  static Future<({String url, String id})?> show(BuildContext context) async {
    // Get GIPHY API key from environment
    final apiKey = dotenv.env['GIPHY_API_KEY'] ?? '';

    if (apiKey.isEmpty) {
      // Show fallback message if no API key configured
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('GIF non disponibile - configura GIPHY_API_KEY'),
          backgroundColor: NovaColors.warning(context),
        ),
      );
      return null;
    }

    final gif = await GiphyGet.getGif(
      context: context,
      apiKey: apiKey,
      lang: GiphyLanguage.italian,
      tabColor: NovaColors.primary(context),
      debounceTimeInMilliseconds: 350,
      searchText: 'Cerca GIF...',
      modal: true,
      showPreview: true,
      showGIFs: true,
      showStickers: true,
      showEmojis: false,
    );

    if (gif == null) return null;

    // Return the fixed width GIF for consistent sizing
    final gifUrl = gif.images?.fixedWidth?.url ?? gif.images?.original?.url;
    final gifId = gif.id;

    if (gifUrl == null || gifId == null) return null;

    return (url: gifUrl, id: gifId);
  }
}

/// A widget that displays a GIF message bubble.
///
/// Shows the GIF inline in the chat with proper sizing and loading states.
class GifBubble extends StatelessWidget {
  final String gifUrl;
  final bool isOwnMessage;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const GifBubble({
    super.key,
    required this.gifUrl,
    required this.isOwnMessage,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
          maxHeight: 200,
        ),
        decoration: BoxDecoration(
          borderRadius: NovaRadius.circularL,
          color: isOwnMessage
              ? NovaColors.primary(context)
              : NovaColors.card(context),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // GIF Image
            ClipRRect(
              borderRadius: NovaRadius.circularL,
              child: Image.network(
                gifUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    width: 200,
                    height: 150,
                    color: NovaColors.card(context),
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                        color: NovaColors.primary(context),
                        strokeWidth: 2,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: 200,
                    height: 150,
                    color: NovaColors.card(context),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image_outlined,
                          color: NovaColors.textTertiary(context),
                          size: 32,
                        ),
                        SizedBox(height: NovaSpacing.xs),
                        Text(
                          'GIF non disponibile',
                          style: NovaTypography.bodySmall.copyWith(
                            color: NovaColors.textTertiary(context),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // GIF badge
            Positioned(
              right: NovaSpacing.xs,
              bottom: NovaSpacing.xs,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.xs,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: NovaRadius.circularXs,
                ),
                child: Text(
                  'GIF',
                  style: NovaTypography.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
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
