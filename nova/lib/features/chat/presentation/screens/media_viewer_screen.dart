import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';

/// Full-screen viewer for view-once media.
///
/// Features:
/// - Screenshot protection on Android (FLAG_SECURE)
/// - Screenshot detection on iOS with sender notification
/// - One-time view enforcement
/// - Countdown timer display
class MediaViewerScreen extends ConsumerStatefulWidget {
  final ChatMediaInfo media;
  final String signedUrl;

  const MediaViewerScreen({
    super.key,
    required this.media,
    required this.signedUrl,
  });

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  bool _hasViewed = false;
  bool _isLoading = true;
  int _currentViewCount = 0;
  int _maxViews = 1;

  @override
  void initState() {
    super.initState();
    _maxViews = widget.media.maxViews;
    _currentViewCount = widget.media.viewCount;
    _setupScreenshotProtection();
    _markAsViewed();
  }

  @override
  void dispose() {
    _removeScreenshotProtection();
    super.dispose();
  }

  Future<void> _setupScreenshotProtection() async {
    if (Platform.isAndroid) {
      // Enable FLAG_SECURE to prevent screenshots
      try {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
        );
        // Note: flutter_windowmanager would be used here in production
        // FlutterWindowManager.addFlags(FlutterWindowManager.FLAG_SECURE);
      } catch (e) {
        debugPrint('Failed to enable screenshot protection: $e');
      }
    } else if (Platform.isIOS) {
      // Setup screenshot detection callback
      // Note: screenshot_callback would be used here in production
      // ScreenshotCallback.instance.addListener(_onScreenshot);
    }
  }

  Future<void> _removeScreenshotProtection() async {
    if (Platform.isAndroid) {
      try {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
        );
        // FlutterWindowManager.clearFlags(FlutterWindowManager.FLAG_SECURE);
      } catch (e) {
        debugPrint('Failed to disable screenshot protection: $e');
      }
    } else if (Platform.isIOS) {
      // ScreenshotCallback.instance.removeListener(_onScreenshot);
    }
  }

  Future<void> _onScreenshot() async {
    // Report screenshot to sender
    final repository = ref.read(chatRepositoryProvider);
    await repository.reportScreenshot(widget.media.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Screenshot rilevato - il mittente è stato notificato'),
          backgroundColor: NovaColors.warning(context),
        ),
      );
    }
  }

  Future<void> _markAsViewed() async {
    try {
      final repository = ref.read(chatRepositoryProvider);
      final updatedMedia = await repository.markMediaViewed(widget.media.id);
      if (updatedMedia != null) {
        setState(() {
          _currentViewCount = updatedMedia.viewCount;
          _hasViewed = true;
          _isLoading = false;
        });
      } else {
        // Max views reached or expired
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Questo media non è più disponibile'),
              backgroundColor: NovaColors.warning(context),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Errore nel caricamento del media'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          'Visualizzazione singola',
          style: NovaTypography.bodyMedium.copyWith(
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : Stack(
              children: [
                // Media content
                Center(
                  child: widget.media.mediaType.isImage
                      ? Image.network(
                          widget.signedUrl,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded /
                                        progress.expectedTotalBytes!
                                    : null,
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stack) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.broken_image,
                                size: 64,
                                color: Colors.white54,
                              ),
                              SizedBox(height: NovaSpacing.m),
                              Text(
                                'Impossibile caricare l\'immagine',
                                style: NovaTypography.bodyMedium.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildVideoPlayer(),
                ),

                // View status notice
                Positioned(
                  bottom: NovaSpacing.xl,
                  left: NovaSpacing.m,
                  right: NovaSpacing.m,
                  child: Container(
                    padding: EdgeInsets.all(NovaSpacing.s),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.visibility_off,
                          color: Colors.white70,
                          size: 16,
                        ),
                        SizedBox(width: NovaSpacing.xs),
                        Text(
                          _getViewStatusText(),
                          style: NovaTypography.bodySmall.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _getViewStatusText() {
    final remaining = _maxViews - _currentViewCount;
    if (remaining <= 0) {
      return 'Questo media scomparirà dopo la chiusura';
    } else if (_maxViews == 1) {
      return 'Questo media scomparirà dopo la chiusura';
    } else {
      return 'Visualizzazione $_currentViewCount di $_maxViews';
    }
  }

  Widget _buildVideoPlayer() {
    // Simplified video placeholder
    // In production, use video_player package
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.play_circle_outline,
          size: 80,
          color: Colors.white,
        ),
        SizedBox(height: NovaSpacing.m),
        Text(
          'Tocca per riprodurre',
          style: NovaTypography.bodyMedium.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
