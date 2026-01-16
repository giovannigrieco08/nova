import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/chat/presentation/widgets/view_once_icon.dart';

/// A bubble widget displaying ephemeral media (photo/video/audio) with view status.
///
/// Shows different states:
/// - Not viewed: Clickable with "Foto" label and view count indicator
/// - Partially viewed (for 2x): Shows remaining views
/// - Fully viewed: "Aperta" label with checkmark
/// - Expired: "Scaduta" label
class ChatMediaBubble extends ConsumerWidget {
  final ChatMediaInfo media;
  final bool isOwnMessage;
  final VoidCallback? onTap;

  const ChatMediaBubble({
    super.key,
    required this.media,
    required this.isOwnMessage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canView = media.canView;
    final isExpired = media.isExpired;
    final isViewed = media.isViewed;

    // Audio messages get special inline player UI (Instagram-style)
    if (media.mediaType == ChatMediaType.audio) {
      return _InlineAudioPlayer(
        media: media,
        isOwnMessage: isOwnMessage,
      );
    }

    // Image and Video use standard bubble UI
    return GestureDetector(
      onTap: canView ? onTap : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.m,
          vertical: NovaSpacing.s,
        ),
        decoration: BoxDecoration(
          color: _getBackgroundColor(context, isOwnMessage, canView, isViewed),
          borderRadius: NovaRadius.circularL,
          // No border - Instagram style (clean look)
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            _buildIcon(context, isOwnMessage, canView, isViewed, isExpired),
            SizedBox(width: NovaSpacing.s),

            // Label
            Text(
              _getLabel(isExpired, isViewed, canView),
              style: NovaTypography.bodyMedium.copyWith(
                color: _getTextColor(context, isOwnMessage, canView, isViewed),
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),

            // View count indicator (only for available media with multiple views)
            if (canView && media.maxViews > 1) ...[
              SizedBox(width: NovaSpacing.xs),
              _buildViewCountBadge(context, isOwnMessage),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(
    BuildContext context,
    bool isOwnMessage,
    bool canView,
    bool isViewed,
    bool isExpired,
  ) {
    // Expired media - show timer icon for all types
    // Use high contrast colors: white on purple (own), dark gray on light (others)
    if (isExpired) {
      return Icon(
        Icons.timer_off_outlined,
        size: 18,
        color: isOwnMessage
            ? NovaColors.onPrimaryLight.withValues(alpha: 0.7)
            : NovaColors.textSecondary(context),
      );
    }

    // For images, use ViewOnceIcon with 2 states:
    // - Viewable: white solid outline
    // - Not viewable: high contrast dashed circle
    if (media.mediaType == ChatMediaType.image) {
      return ViewOnceIcon(
        isViewable: canView,
        isOwnMessage: isOwnMessage,
        size: 24,
      );
    }

    // For video and audio, use standard icons
    IconData icon;
    Color color;

    if (isViewed) {
      icon = Icons.check_circle_outline;
      color = isOwnMessage ? NovaColors.onPrimaryLight.withValues(alpha: 0.7) : NovaColors.textSecondary(context);
    } else {
      // Can view - show media type icon
      icon = _getMediaTypeIcon();
      color = isOwnMessage ? NovaColors.onPrimaryLight : NovaColors.primary(context);
    }

    // Wrap in a circle container for better visibility
    if (canView) {
      return Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: (isOwnMessage ? NovaColors.onPrimaryLight : NovaColors.primary(context))
              .withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: color),
      );
    }

    return Icon(icon, size: 18, color: color);
  }

  IconData _getMediaTypeIcon() {
    switch (media.mediaType) {
      case ChatMediaType.image:
        return Icons.photo_camera_outlined;
      case ChatMediaType.video:
        return Icons.videocam_outlined;
      case ChatMediaType.audio:
        return Icons.mic_outlined;
    }
  }

  Widget _buildViewCountBadge(BuildContext context, bool isOwnMessage) {
    final remaining = media.remainingViews;
    final total = media.maxViews;

    // Instagram style: badge matches bubble style
    final badgeColor = isOwnMessage
        ? NovaColors.onPrimaryLight.withValues(alpha: 0.2)
        : NovaColors.primary(context).withValues(alpha: 0.2);
    final textColor = isOwnMessage
        ? NovaColors.onPrimaryLight
        : NovaColors.primary(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: NovaRadius.circularXs,
      ),
      child: Text(
        '$remaining/$total',
        style: NovaTypography.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 11,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }

  String _getLabel(bool isExpired, bool isViewed, bool canView) {
    if (isExpired) return 'Scaduta';
    if (isViewed) return 'Aperta';

    // Can view
    switch (media.mediaType) {
      case ChatMediaType.image:
        return 'Foto';
      case ChatMediaType.video:
        return 'Video';
      case ChatMediaType.audio:
        return 'Audio';
    }
  }

  Color _getBackgroundColor(
    BuildContext context,
    bool isOwnMessage,
    bool canView,
    bool isViewed,
  ) {
    // Always use same background as normal messages (Instagram style)
    return isOwnMessage
        ? NovaColors.primary(context)
        : NovaColors.card(context);
  }

  Color _getTextColor(
    BuildContext context,
    bool isOwnMessage,
    bool canView,
    bool isViewed,
  ) {
    // High contrast text colors based on background:
    // - Own message (purple bg): white when viewable, light gray when expired/viewed
    // - Other message (light bg): purple when viewable, dark gray when expired/viewed
    if (canView) {
      return isOwnMessage ? NovaColors.onPrimaryLight : NovaColors.primary(context);
    } else {
      // Expired or fully viewed - use muted but readable colors
      return isOwnMessage
          ? NovaColors.onPrimaryLight.withValues(alpha: 0.7)
          : NovaColors.textSecondary(context);
    }
  }
}

/// Instagram-style inline audio player for voice messages
/// Shows: [Play/Pause] [Waveform/Progress] [Duration]
class _InlineAudioPlayer extends StatefulWidget {
  final ChatMediaInfo media;
  final bool isOwnMessage;

  const _InlineAudioPlayer({
    required this.media,
    required this.isOwnMessage,
  });

  @override
  State<_InlineAudioPlayer> createState() => _InlineAudioPlayerState();
}

class _InlineAudioPlayerState extends State<_InlineAudioPlayer> {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamSubscription? _progressSubscription;

  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  String? _audioUrl;

  // Playback speed control (WhatsApp-style)
  static const List<double> _speeds = [1.0, 1.5, 2.0];
  int _speedIndex = 0;
  double get _currentSpeed => _speeds[_speedIndex];

  /// Get the saved duration from media metadata (if available)
  Duration get _savedDuration =>
      widget.media.duration ?? Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      await _player.openPlayer();

      // Enable progress events (required for duration/position updates)
      await _player.setSubscriptionDuration(const Duration(milliseconds: 100));

      // Subscribe to progress events immediately
      _progressSubscription = _player.onProgress?.listen((event) {
        if (mounted) {
          setState(() {
            _position = event.position;
            _duration = event.duration;
          });
        }
      });

      setState(() => _isInitialized = true);

      // Get signed URL for the audio file
      final supabase = Supabase.instance.client;
      final signedUrl = await supabase.storage
          .from('ephemeral-media')
          .createSignedUrl(widget.media.storagePath, 3600); // 1 hour

      setState(() => _audioUrl = signedUrl);
    } catch (e) {
      // Ignore initialization errors
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _player.closePlayer();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    if (!_isInitialized || _audioUrl == null) return;

    if (_isPlaying) {
      await _player.pausePlayer();
      setState(() => _isPlaying = false);
    } else {
      setState(() => _isLoading = true);
      try {
        // If at end, restart from beginning
        if (_position >= _duration && _duration > Duration.zero) {
          await _player.stopPlayer();
          _position = Duration.zero;
        }

        if (_player.isStopped) {
          await _player.startPlayer(
            fromURI: _audioUrl,
            codec: Codec.aacADTS,
            whenFinished: () {
              if (mounted) {
                setState(() {
                  _isPlaying = false;
                  _position = _duration;
                });
              }
            },
          );
        } else {
          await _player.resumePlayer();
        }

        setState(() {
          _isPlaying = true;
          _isLoading = false;
        });
      } catch (e) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Cycle through playback speeds (1x -> 1.5x -> 2x -> 1x)
  Future<void> _cycleSpeed() async {
    setState(() {
      _speedIndex = (_speedIndex + 1) % _speeds.length;
    });

    // Apply new speed if currently playing
    if (_isPlaying && _isInitialized) {
      try {
        await _player.setSpeed(_currentSpeed);
      } catch (e) {
        // Ignore speed change errors
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwn = widget.isOwnMessage;

    // Colors based on ownership - own messages have purple background
    final backgroundColor = isOwn
        ? NovaColors.primary(context)
        : NovaColors.card(context);

    // For own messages (purple bg): white icons/text, gray waveform unplayed, white played
    // For others (light bg): purple icons, gray waveform unplayed, purple played
    final iconColor = isOwn ? NovaColors.onPrimaryLight : NovaColors.primary(context);

    // Duration text - make it clearly readable!
    // Own message: white text on purple background
    // Other message: dark text on light background
    final durationColor = isOwn
        ? NovaColors.onPrimaryLight
        : NovaColors.textPrimary(context);

    // Waveform colors:
    // Played (active) = WHITE for own, PURPLE for others
    // Unplayed (inactive) = GRAY for both
    final waveformPlayedColor = isOwn ? NovaColors.onPrimaryLight : NovaColors.primary(context);
    final waveformUnplayedColor = isOwn
        ? NovaColors.onPrimaryLight.withValues(alpha: 0.35)
        : NovaColors.textTertiary(context);

    // Calculate progress (0.0 to 1.0)
    final progress = _duration.inMilliseconds > 0
        ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      constraints: BoxConstraints(maxWidth: 240),
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: NovaRadius.circularL,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Play/Pause button
          GestureDetector(
            onTap: _isInitialized && _audioUrl != null ? _togglePlayPause : null,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? Padding(
                      padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: iconColor,
                      size: 24,
                    ),
            ),
          ),
          SizedBox(width: NovaSpacing.s),

          // 2. Waveform visualization (progress) - optimized with CustomPainter
          Expanded(
            child: SizedBox(
              height: 28,
              child: CustomPaint(
                painter: _WaveformPainter(
                  progress: progress,
                  playedColor: waveformPlayedColor,
                  unplayedColor: waveformUnplayedColor,
                ),
                size: Size.infinite,
              ),
            ),
          ),
          SizedBox(width: NovaSpacing.s),

          // 3. Speed control button (WhatsApp-style)
          GestureDetector(
            onTap: _cycleSpeed,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: NovaSpacing.xs,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: NovaRadius.circularXs,
              ),
              child: Text(
                '${_currentSpeed}x',
                style: NovaTypography.bodySmall.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),

          SizedBox(width: NovaSpacing.xs),

          // 4. Duration display - clearly readable!
          // Show: position if playing, saved duration if not played yet
          Text(
            _isPlaying || _position > Duration.zero
                ? _formatDuration(_position)
                : _formatDuration(_duration > Duration.zero ? _duration : _savedDuration),
            style: NovaTypography.bodySmall.copyWith(
              color: durationColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
              decoration: TextDecoration.none, // Prevent Android spell-check underline
            ),
          ),
        ],
      ),
    );
  }
}

/// Optimized waveform painter using CustomPainter instead of multiple Containers.
/// This reduces widget tree complexity and improves performance.
class _WaveformPainter extends CustomPainter {
  final double progress;
  final Color playedColor;
  final Color unplayedColor;

  // Precomputed waveform heights (pseudo-random pattern)
  static const List<double> _heights = [
    0.35, 0.7, 0.5, 0.9, 0.4, 0.85, 0.55, 1.0, 0.5, 0.75,
    0.4, 0.8, 0.6, 0.95, 0.35, 0.7, 0.5, 0.85, 0.45, 0.65,
    0.5, 0.75, 0.4, 0.6
  ];

  _WaveformPainter({
    required this.progress,
    required this.playedColor,
    required this.unplayedColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = _heights.length;
    final barWidth = 3.0;
    final totalBarsWidth = barCount * barWidth;
    final spacing = (size.width - totalBarsWidth) / (barCount - 1);

    final playedPaint = Paint()
      ..color = playedColor
      ..style = PaintingStyle.fill;

    final unplayedPaint = Paint()
      ..color = unplayedColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final barProgress = (i + 1) / barCount;
      final isPlayed = barProgress <= progress;

      final x = i * (barWidth + spacing);
      final barHeight = size.height * _heights[i];
      final y = (size.height - barHeight) / 2;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, barHeight),
        const Radius.circular(1.5),
      );

      canvas.drawRRect(rect, isPlayed ? playedPaint : unplayedPaint);
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.playedColor != playedColor ||
        oldDelegate.unplayedColor != unplayedColor;
  }
}
