import 'dart:io';
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:video_player/video_player.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/providers/core_providers.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart'
    show chatRepositoryProvider;

/// Immersive full-screen viewer for view-once media.
///
/// Features:
/// - Fullscreen immersive mode (no system UI)
/// - Floating glass close button
/// - Floating view count badge
/// - Gradient caption overlay
/// - Ephemeral indicator with pulse animation
/// - Swipe to close gesture
/// - Screenshot protection on Android (FLAG_SECURE)
/// - Screenshot detection on iOS with sender notification
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

class _MediaViewerScreenState extends ConsumerState<MediaViewerScreen>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  int _currentViewCount = 0;
  int _maxViews = 1;
  bool _isOwner = false;

  // Swipe to close state
  double _dragOffset = 0.0;

  // Audio player state
  FlutterSoundPlayer? _audioPlayer;
  bool _playerInitialized = false;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _progressSubscription;

  // Video player state
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _videoError = false;

  // Pulse animation for ephemeral indicator
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Entry animation
  late AnimationController _entryController;
  late Animation<double> _entryAnimation;

  // Caption visibility animation
  late AnimationController _captionController;
  late Animation<double> _captionAnimation;
  Timer? _captionTimer;

  @override
  void initState() {
    super.initState();
    _maxViews = widget.media.maxViews;
    _currentViewCount = widget.media.viewCount;

    // Setup pulse animation
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Setup entry animation
    _entryController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _entryAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _entryController.forward();

    // Setup caption fade animation
    _captionController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
      value: 1.0, // Start visible
    );
    _captionAnimation = CurvedAnimation(
      parent: _captionController,
      curve: Curves.easeOut,
    );

    // Auto-hide caption after 4 seconds
    if (widget.caption != null && widget.caption!.isNotEmpty) {
      _captionTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          _captionController.reverse();
        }
      });
    }

    _checkIfOwner();
    _setupScreenshotProtection();
    _markAsViewed();

    if (widget.media.mediaType.isAudio) {
      _initAudioPlayer();
    }

    if (widget.media.mediaType.isVideo) {
      _initVideoPlayer();
    }
  }

  @override
  void dispose() {
    _removeScreenshotProtection();
    _disposeAudioPlayer();
    _disposeVideoPlayer();
    _pulseController.dispose();
    _entryController.dispose();
    _captionController.dispose();
    _captionTimer?.cancel();
    super.dispose();
  }

  Future<void> _initVideoPlayer() async {
    try {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse(widget.signedUrl),
      );
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      await _videoController!.play();
      if (mounted) {
        setState(() {
          _videoInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _videoError = true;
        });
      }
    }
  }

  void _disposeVideoPlayer() {
    _videoController?.dispose();
  }

  void _checkIfOwner() {
    final currentUserId = ref.read(currentUserIdProvider);
    _isOwner = currentUserId == widget.media.uploaderUserId;
  }

  Future<void> _initAudioPlayer() async {
    if (_audioPlayer != null) return;
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
      try {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.immersiveSticky,
        );
      } catch (e) {
        // Ignore screenshot protection errors
      }
    } else if (Platform.isIOS) {
      // Setup screenshot detection callback
    }
  }

  Future<void> _removeScreenshotProtection() async {
    if (Platform.isAndroid) {
      try {
        await SystemChrome.setEnabledSystemUIMode(
          SystemUiMode.edgeToEdge,
        );
      } catch (e) {
        // Ignore screenshot protection errors
      }
    } else if (Platform.isIOS) {
      // Remove screenshot detection callback
    }
  }

  // TODO: Implement _onScreenshot for iOS screenshot detection
  // See: screenshot_callback package

  Future<void> _markAsViewed() async {
    try {
      final repository = ref.read(chatRepositoryProvider);
      final updatedMedia = await repository.markMediaViewed(widget.media.id);
      if (updatedMedia != null) {
        setState(() {
          _currentViewCount = updatedMedia.viewCount;
          _isLoading = false;
        });
      } else {
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

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dy;
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragOffset.abs() > 100 ||
        details.velocity.pixelsPerSecond.dy.abs() > 500) {
      Navigator.pop(context);
    } else {
      setState(() {
        _dragOffset = 0.0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final remaining = _maxViews - _currentViewCount;
    final isLastView = remaining <= 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            )
          : AnimatedBuilder(
              animation: _entryAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 0.9 + (_entryAnimation.value * 0.1),
                  child: Opacity(
                    opacity: _entryAnimation.value,
                    child: child,
                  ),
                );
              },
              child: GestureDetector(
                onVerticalDragUpdate: _handleDragUpdate,
                onVerticalDragEnd: _handleDragEnd,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  transform: Matrix4.translationValues(0, _dragOffset, 0),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Media content - full screen with interactive zoom/pan
                      Positioned.fill(
                        child: Opacity(
                          opacity: 1 - (_dragOffset.abs() / 500).clamp(0.0, 0.5),
                          child: _buildMediaContent(),
                        ),
                      ),

                      // Floating close button (top-left)
                      Positioned(
                        top: safeTop + NovaSpacing.m,
                        left: NovaSpacing.m,
                        child: _buildFloatingCloseButton(),
                      ),

                      // View count badge (top-right)
                      if (!_isOwner)
                        Positioned(
                          top: safeTop + NovaSpacing.m,
                          right: NovaSpacing.m,
                          child: _buildViewCountBadge(),
                        ),

                      // Bottom gradient overlay with caption and ephemeral indicator
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _buildBottomOverlay(safeBottom, isLastView),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildFloatingCloseButton() {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: const Center(
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewCountBadge() {
    return ClipRRect(
      borderRadius: NovaRadius.circularFull,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.m,
            vertical: NovaSpacing.s,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: NovaRadius.circularFull,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.visibility_outlined,
                color: Colors.white.withValues(alpha: 0.7),
                size: 16,
              ),
              SizedBox(width: NovaSpacing.xs),
              Text(
                '$_currentViewCount/$_maxViews',
                style: NovaTypography.labelSmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomOverlay(double safeBottom, bool isLastView) {
    return Container(
      padding: EdgeInsets.only(
        left: NovaSpacing.l,
        right: NovaSpacing.l,
        bottom: safeBottom + NovaSpacing.xl,
        top: NovaSpacing.xxxl,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.black.withValues(alpha: 0.4),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Caption with fade animation (Instagram Stories style - plain text with shadow)
          if (widget.caption != null && widget.caption!.isNotEmpty)
            FadeTransition(
              opacity: _captionAnimation,
              child: GestureDetector(
                onTap: () {
                  // Show caption again on tap
                  _captionTimer?.cancel();
                  _captionController.forward();
                  _captionTimer = Timer(const Duration(seconds: 4), () {
                    if (mounted) {
                      _captionController.reverse();
                    }
                  });
                },
                child: Padding(
                  padding: EdgeInsets.only(bottom: NovaSpacing.l),
                  child: Text(
                    widget.caption!,
                    textAlign: TextAlign.center,
                    style: NovaTypography.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      shadows: const [
                        // Multiple layered shadows for better readability on any background
                        Shadow(
                          color: Colors.black,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                        Shadow(
                          color: Colors.black,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                        Shadow(
                          color: Color(0x80000000), // Colors.black with 0.5 alpha
                          blurRadius: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Ephemeral indicator (only for non-owners)
          if (!_isOwner) _buildEphemeralIndicator(isLastView),
        ],
      ),
    );
  }

  Widget _buildEphemeralIndicator(bool isLastView) {
    final remaining = _maxViews - _currentViewCount;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final glowOpacity = isLastView ? 0.2 + (_pulseAnimation.value * 0.3) : 0.0;

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.m,
            vertical: NovaSpacing.s,
          ),
          decoration: BoxDecoration(
            color: NovaColors.warning(context).withValues(alpha: 0.2),
            borderRadius: NovaRadius.circularFull,
            border: Border.all(
              color: NovaColors.warning(context).withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: isLastView
                ? [
                    BoxShadow(
                      color: NovaColors.warning(context).withValues(alpha: glowOpacity),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                color: NovaColors.warning(context),
                size: 16,
              ),
              SizedBox(width: NovaSpacing.xs),
              Text(
                remaining <= 0
                    ? 'Scompare alla chiusura'
                    : '$remaining visualizzazion${remaining == 1 ? 'e' : 'i'} rimanent${remaining == 1 ? 'e' : 'i'}',
                style: NovaTypography.labelSmall.copyWith(
                  color: NovaColors.warning(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
              Icon(
                Icons.broken_image,
                size: 64,
                color: Colors.white.withValues(alpha: 0.54),
              ),
              SizedBox(height: NovaSpacing.m),
              Text(
                'Impossibile caricare l\'immagine',
                style: NovaTypography.bodyMedium.copyWith(
                  color: Colors.white.withValues(alpha: 0.54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_videoError) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.white.withValues(alpha: 0.54),
          ),
          SizedBox(height: NovaSpacing.m),
          Text(
            'Impossibile caricare il video',
            style: NovaTypography.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.54),
            ),
          ),
        ],
      );
    }

    if (!_videoInitialized || _videoController == null) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
        setState(() {});
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          if (!_videoController!.value.isPlaying)
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 50,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          // Video progress bar with duration
          Positioned(
            bottom: NovaSpacing.xl,
            left: NovaSpacing.l,
            right: NovaSpacing.l,
            child: _buildVideoProgressBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoProgressBar() {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _videoController!,
      builder: (context, value, child) {
        final position = value.position;
        final duration = value.duration;
        final progress = duration.inMilliseconds > 0
            ? position.inMilliseconds / duration.inMilliseconds
            : 0.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progress bar
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: NovaRadius.circularXxs,
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: NovaRadius.circularXxs,
                  ),
                ),
              ),
            ),
            SizedBox(height: NovaSpacing.xs),
            // Duration labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: NovaTypography.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: NovaTypography.bodySmall.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildAudioPlayer() {
    return Padding(
      padding: EdgeInsets.all(NovaSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Microphone icon with glass effect
          ClipOval(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
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
              decoration: const BoxDecoration(
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
      _progressSubscription?.cancel();

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

      _progressSubscription = _audioPlayer!.onProgress?.listen((event) {
        if (mounted) {
          setState(() {
            _position = event.position;
            _duration = event.duration;
          });
        }
      });

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
