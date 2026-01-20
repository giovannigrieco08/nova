import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Video preview screen (simplified Instagram-style)
///
/// Features:
/// - Full screen video preview with playback controls
/// - Download to gallery
/// - View-once toggle
/// - Caption input
/// - Send functionality
class VideoPreviewScreen extends StatefulWidget {
  final XFile videoFile;
  final Function(File videoFile, {bool allowReplay, String? caption})? onSend;

  const VideoPreviewScreen({
    super.key,
    required this.videoFile,
    this.onSend,
  });

  @override
  State<VideoPreviewScreen> createState() => _VideoPreviewScreenState();
}

class _VideoPreviewScreenState extends State<VideoPreviewScreen> {
  late VideoPlayerController _videoController;
  final TextEditingController _captionController = TextEditingController();
  bool _isInitialized = false;
  bool _isPlaying = false;

  /// Whether recipient can replay the media (true = unlimited, false = 1 view)
  bool _allowReplay = true;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  @override
  void dispose() {
    _videoController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    _videoController = VideoPlayerController.file(File(widget.videoFile.path));

    try {
      await _videoController.initialize();
      _videoController.setLooping(true);
      await _videoController.play();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore caricamento video: $e')),
        );
      }
    }
  }

  void _togglePlayPause() {
    if (_videoController.value.isPlaying) {
      _videoController.pause();
      setState(() => _isPlaying = false);
    } else {
      _videoController.play();
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video preview
            if (_isInitialized)
              GestureDetector(
                onTap: _togglePlayPause,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _videoController.value.aspectRatio,
                    child: VideoPlayer(_videoController),
                  ),
                ),
              )
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Play/Pause overlay
            if (_isInitialized && !_isPlaying)
              Center(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                ),
              ),

            // Top toolbar
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopToolbar(),
            ),

            // Bottom send bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomBar(),
            ),

            // Progress indicator
            if (_isInitialized)
              Positioned(
                bottom: 100,
                left: NovaSpacing.m,
                right: NovaSpacing.m,
                child: _buildProgressBar(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          _buildToolButton(
            icon: Icons.close,
            onTap: () => Navigator.pop(context),
          ),

          // Download button (Instagram style)
          _buildToolButton(
            icon: Icons.download_outlined,
            onTap: _saveToGallery,
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return ValueListenableBuilder(
      valueListenable: _videoController,
      builder: (context, VideoPlayerValue value, child) {
        final duration = value.duration.inMilliseconds;
        final position = value.position.inMilliseconds;
        final progress = duration > 0 ? position / duration : 0.0;

        return Container(
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
        );
      },
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.m),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Caption input field
          Container(
            margin: EdgeInsets.only(bottom: NovaSpacing.m),
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.m),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: NovaRadius.circularXl,
            ),
            child: TextField(
              controller: _captionController,
              style: NovaTypography.bodyMedium.copyWith(
                color: Colors.white,
              ),
              maxLines: 2,
              minLines: 1,
              maxLength: 150,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Aggiungi una didascalia...',
                hintStyle: NovaTypography.bodyMedium.copyWith(
                  color: Colors.white60,
                ),
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(vertical: NovaSpacing.s),
              ),
            ),
          ),

          // Bottom row with replay toggle and send button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Replay toggle (tappable)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _allowReplay = !_allowReplay;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: NovaSpacing.s,
                      vertical: NovaSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(NovaRadius.m),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _allowReplay ? Icons.replay : Icons.looks_one_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            _allowReplay
                                ? 'Consenti di riprodurre di nuovo'
                                : 'Consenti 1 sola visualizzazione',
                            style: NovaTypography.bodySmall.copyWith(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              SizedBox(width: NovaSpacing.m),

              // Send button
              GestureDetector(
                onTap: _sendVideo,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: NovaSpacing.m,
                    vertical: NovaSpacing.s,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(NovaRadius.xl),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: NovaColors.primary(context),
                        child: Icon(Icons.send, size: 14, color: Colors.white),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Invia',
                        style: NovaTypography.bodyMedium.copyWith(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveToGallery() async {
    try {
      // Save to gallery using gal package
      await Gal.putVideo(widget.videoFile.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video salvato nella galleria!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Errore nel salvataggio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _sendVideo() async {
    if (widget.onSend != null) {
      final caption = _captionController.text.trim();
      widget.onSend!(
        File(widget.videoFile.path),
        allowReplay: _allowReplay,
        caption: caption.isNotEmpty ? caption : null,
      );
      // Navigator.pop is handled by the callback
    } else {
      // Just close if no callback
      Navigator.pop(context);
    }
  }
}
