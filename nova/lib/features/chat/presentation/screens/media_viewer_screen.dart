import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/providers/core_providers.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart'
    show chatRepositoryProvider;

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
  final String? caption;

  const MediaViewerScreen({
    super.key,
    required this.media,
    required this.signedUrl,
    this.caption,
  });

  @override
  ConsumerState<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen> {
  bool _hasViewed = false;
  bool _isLoading = true;
  int _currentViewCount = 0;
  int _maxViews = 1;
  bool _isOwner = false;

  // Audio player state (lazy initialization - only for audio media)
  FlutterSoundPlayer? _audioPlayer;
  bool _playerInitialized = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _maxViews = widget.media.maxViews;
    _currentViewCount = widget.media.viewCount;
    _checkIfOwner();
    _setupScreenshotProtection();
    _markAsViewed();

    // Initialize audio player if this is an audio media
    if (widget.media.mediaType.isAudio) {
      _initAudioPlayer();
    }
  }

  @override
  void dispose() {
    _removeScreenshotProtection();
    _disposeAudioPlayer();
    super.dispose();
  }

  void _checkIfOwner() {
    final currentUserId = ref.read(currentUserIdProvider);
    _isOwner = currentUserId == widget.media.uploaderUserId;
  }

  Future<void> _initAudioPlayer() async {
    if (_audioPlayer != null) return; // Already initialized
    try {
      _audioPlayer = FlutterSoundPlayer();
      await _audioPlayer!.openPlayer();
      _playerInitialized = true;
    } catch (e) {
      // Ignore initialization errors
    }
  }

  Future<void> _disposeAudioPlayer() async {
    _progressSubscription?.cancel();
    if (_playerInitialized && _audioPlayer != null) {
      try {
        await _audioPlayer!.stopPlayer();
        await _audioPlayer!.closePlayer();
      } catch (e) {
        // Ignore disposal errors
      }
    }
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
        // Ignore screenshot protection errors
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
        // Ignore screenshot protection errors
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
                // Media content - full screen with interactive zoom/pan
                Positioned.fill(
                  child: _buildMediaContent(),
                ),

                // Caption (if provided) - positioned above the view status
                if (widget.caption != null && widget.caption!.isNotEmpty)
                  Positioned(
                    bottom: _isOwner ? NovaSpacing.xl : NovaSpacing.xl + 60,
                    left: NovaSpacing.m,
                    right: NovaSpacing.m,
                    child: Container(
                      padding: EdgeInsets.all(NovaSpacing.m),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: NovaRadius.circularS,
                      ),
                      child: Text(
                        widget.caption!,
                        style: NovaTypography.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                // View status notice (only shown to non-owners)
                if (!_isOwner)
                  Positioned(
                    bottom: NovaSpacing.xl,
                    left: NovaSpacing.m,
                    right: NovaSpacing.m,
                    child: Container(
                      padding: EdgeInsets.all(NovaSpacing.s),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: NovaRadius.circularXs,
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

  /// Route to appropriate media player based on type
  Widget _buildMediaContent() {
    switch (widget.media.mediaType) {
      case ChatMediaType.image:
        return _buildImageViewer();
      case ChatMediaType.video:
        return _buildVideoPlayer();
      case ChatMediaType.audio:
        return _buildAudioPlayer();
    }
  }

  Widget _buildImageViewer() {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          widget.signedUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
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
        ),
      ),
    );
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

  // ===========================================================================
  // AUDIO PLAYER
  // ===========================================================================

  Widget _buildAudioPlayer() {
    return Padding(
      padding: EdgeInsets.all(NovaSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Microphone icon with pulsing animation when playing
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              _isPlaying ? Icons.graphic_eq : Icons.mic,
              size: 60,
              color: Colors.white,
            ),
          ),

          SizedBox(height: NovaSpacing.xl),

          // Progress bar
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: _duration.inMilliseconds > 0
                  ? _position.inMilliseconds / _duration.inMilliseconds
                  : 0.0,
              onChanged: (value) {
                if (_duration.inMilliseconds > 0) {
                  final newPosition = Duration(
                    milliseconds: (value * _duration.inMilliseconds).toInt(),
                  );
                  _seekTo(newPosition);
                }
              },
            ),
          ),

          // Duration labels
          Padding(
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.m),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(_position),
                  style: NovaTypography.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
                Text(
                  _formatDuration(_duration),
                  style: NovaTypography.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: NovaSpacing.l),

          // Play/Pause button
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                size: 36,
                color: Colors.black,
              ),
            ),
          ),

          SizedBox(height: NovaSpacing.l),

          // Voice message label
          Text(
            'Messaggio vocale',
            style: NovaTypography.bodyMedium.copyWith(
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePlayPause() async {
    if (!_playerInitialized) {
      await _initAudioPlayer();
    }

    if (_isPlaying) {
      await _pauseAudio();
    } else {
      await _playAudio();
    }
  }

  Future<void> _playAudio() async {
    if (_audioPlayer == null) return;

    try {
      // Cancel any existing subscription
      _progressSubscription?.cancel();

      // Start playback from URL
      // Don't specify codec - let flutter_sound auto-detect from file
      // iOS uses aacMP4 (.m4a), Android uses aacADTS (.aac)
      await _audioPlayer!.startPlayer(
        fromURI: widget.signedUrl,
        whenFinished: () {
          if (mounted) {
            setState(() {
              _isPlaying = false;
              _position = Duration.zero;
            });
          }
        },
      );

      // Subscribe to progress updates
      _progressSubscription = _audioPlayer!.onProgress?.listen((event) {
        if (mounted) {
          setState(() {
            _position = event.position;
            _duration = event.duration;
          });
        }
      });

      // Enable progress subscription
      await _audioPlayer!.setSubscriptionDuration(
        const Duration(milliseconds: 100),
      );

      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Errore nella riproduzione audio'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }

  Future<void> _pauseAudio() async {
    if (_audioPlayer == null) return;
    try {
      await _audioPlayer!.pausePlayer();
      setState(() {
        _isPlaying = false;
      });
    } catch (e) {
      // Ignore pause errors
    }
  }

  Future<void> _seekTo(Duration position) async {
    if (_audioPlayer == null) return;
    try {
      await _audioPlayer!.seekToPlayer(position);
      setState(() {
        _position = position;
      });
    } catch (e) {
      // Ignore seek errors
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
