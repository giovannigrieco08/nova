import 'dart:async';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/utils/image_orientation_fixer.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Native-like camera screen with photo and video support
///
/// Features:
/// - Fullscreen camera preview
/// - Glass effect controls
/// - Flash toggle (off/auto/on)
/// - Front/back camera flip
/// - Photo/Video mode selector with sliding indicator
/// - Gallery shortcut
/// - Premium shutter button with glow effects
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isFrontCamera = false;
  FlashMode _flashMode = FlashMode.off;

  /// Prevents double-tap on shutter button
  bool _isProcessingShutter = false;

  /// 0 = Photo, 1 = Video
  int _selectedMode = 0;

  /// Flash overlay for photo capture effect
  bool _showFlash = false;

  /// Recording timer
  Timer? _recordingTimer;
  int _recordingSeconds = 0;

  final ImagePicker _imagePicker = ImagePicker();

  /// Animation controller for recording pulse effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  /// Animation controller for mode selector sliding indicator
  late AnimationController _modeSlideController;
  late Animation<double> _modeSlideAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Setup pulse animation for recording
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Setup mode slide animation
    _modeSlideController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _modeSlideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _modeSlideController, curve: Curves.easeInOutCubic),
    );

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _pulseController.dispose();
    _modeSlideController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    // Check camera permission
    final status = await Permission.camera.request();
    if (status.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permesso fotocamera negato')),
        );
        Navigator.pop(context);
      }
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nessuna fotocamera disponibile')),
          );
          Navigator.pop(context);
        }
        return;
      }

      await _setupCamera(_isFrontCamera ? 1 : 0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore inizializzazione: $e')),
        );
      }
    }
  }

  Future<void> _setupCamera(int cameraIndex) async {
    if (_cameras.isEmpty || cameraIndex >= _cameras.length) return;

    _controller?.dispose();

    final camera = _cameras[cameraIndex];
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: true,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore camera: $e')),
        );
      }
    }
  }

  void _toggleFlash() {
    if (_controller == null) return;

    setState(() {
      switch (_flashMode) {
        case FlashMode.off:
          _flashMode = FlashMode.auto;
          break;
        case FlashMode.auto:
          _flashMode = FlashMode.always;
          break;
        case FlashMode.always:
        case FlashMode.torch:
          _flashMode = FlashMode.off;
          break;
      }
    });

    _controller!.setFlashMode(_flashMode);
  }

  void _flipCamera() async {
    if (_cameras.length < 2) return;

    setState(() {
      _isFrontCamera = !_isFrontCamera;
      _isInitialized = false;
    });

    await _setupCamera(_isFrontCamera ? 1 : 0);
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;
    if (_isProcessingShutter) return;

    setState(() => _isProcessingShutter = true);

    // Show flash effect
    setState(() => _showFlash = true);
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) setState(() => _showFlash = false);

    try {
      final XFile file = await _controller!.takePicture();

      // Fix orientation issues on iOS
      final fixedPath = await ImageOrientationFixer.fixOrientation(
        file.path,
        isFrontCamera: _isFrontCamera,
      );

      if (mounted) {
        setState(() => _isProcessingShutter = false);
        Navigator.pop(context, {'type': 'photo', 'file': XFile(fixedPath)});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingShutter = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore scatto: $e')),
        );
      }
    }
  }

  Future<void> _startVideoRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isRecordingVideo) return;
    if (_isProcessingShutter) return;

    setState(() => _isProcessingShutter = true);

    try {
      final micStatus = await Permission.microphone.request();
      if (micStatus.isDenied && mounted) {
        setState(() => _isProcessingShutter = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permesso microfono negato')),
        );
        return;
      }

      await _controller!.startVideoRecording();
      if (mounted) {
        setState(() {
          _isRecording = true;
          _isProcessingShutter = false;
          _recordingSeconds = 0;
        });
        // Start recording timer
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordingSeconds++;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingShutter = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore registrazione: $e')),
        );
      }
    }
  }

  Future<void> _stopVideoRecording() async {
    if (_controller == null || !_controller!.value.isRecordingVideo) return;
    if (_isProcessingShutter) return;

    setState(() => _isProcessingShutter = true);
    _recordingTimer?.cancel();
    _recordingTimer = null;

    try {
      final XFile file = await _controller!.stopVideoRecording();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isProcessingShutter = false;
          _recordingSeconds = 0;
        });
        Navigator.pop(context, {'type': 'video', 'file': file});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isProcessingShutter = false;
          _recordingSeconds = 0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore stop registrazione: $e')),
        );
      }
    }
  }

  String _formatRecordingTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  Future<void> _openGallery() async {
    try {
      if (_selectedMode == 0) {
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (image != null && mounted) {
          final fixedPath = await ImageOrientationFixer.fixOrientation(
            image.path,
            isFrontCamera: false,
          );
          if (mounted) {
            Navigator.pop(context, {'type': 'photo', 'file': XFile(fixedPath)});
          }
        }
      } else {
        final XFile? video = await _imagePicker.pickVideo(
          source: ImageSource.gallery,
        );
        if (video != null && mounted) {
          Navigator.pop(context, {'type': 'video', 'file': video});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore galleria: $e')),
        );
      }
    }
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
      case FlashMode.torch:
        return Icons.flash_on;
    }
  }

  void _setMode(int mode) {
    if (_isRecording) return;
    if (mode == _selectedMode) return;

    setState(() {
      _selectedMode = mode;
    });

    if (mode == 1) {
      _modeSlideController.forward();
    } else {
      _modeSlideController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview
          if (_isInitialized && _controller != null)
            _buildCameraPreview()
          else
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),

          // Flash overlay effect
          if (_showFlash)
            AnimatedOpacity(
              opacity: _showFlash ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 100),
              child: Container(color: Colors.white),
            ),

          // Safe area content
          SafeArea(
            child: Stack(
              children: [
                // Top controls - Glass bar
                Positioned(
                  top: NovaSpacing.m,
                  left: NovaSpacing.m,
                  right: NovaSpacing.m,
                  child: _buildTopControlsGlassBar(),
                ),

                // Bottom controls
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _buildBottomControls(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    final size = MediaQuery.of(context).size;
    final scale = 1 / (_controller!.value.aspectRatio * size.aspectRatio);

    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Center(
          child: CameraPreview(_controller!),
        ),
      ),
    );
  }

  Widget _buildTopControlsGlassBar() {
    return ClipRRect(
      borderRadius: NovaRadius.circularXl,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.s,
            vertical: NovaSpacing.s,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: NovaRadius.circularXl,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close button
              _GlassIconButton(
                icon: Icons.close,
                onTap: () => Navigator.pop(context),
              ),

              // Flash toggle (only for back camera)
              if (!_isFrontCamera)
                _GlassIconButton(
                  icon: _getFlashIcon(),
                  onTap: _toggleFlash,
                )
              else
                const SizedBox(width: 48),

              // Flip camera
              _GlassIconButton(
                icon: Icons.flip_camera_ios,
                onTap: _flipCamera,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.l,
        vertical: NovaSpacing.xl,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode selector or recording timer
          if (_isRecording)
            _buildRecordingTimer()
          else
            _buildModeSelector(),

          SizedBox(height: NovaSpacing.xl),

          // Main controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery button
              _buildGalleryButton(),

              // Shutter button
              _buildShutterButton(),

              // Placeholder for symmetry
              const SizedBox(width: 50, height: 50),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingTimer() {
    return ClipRRect(
      borderRadius: NovaRadius.circularFull,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: 36,
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.l,
            vertical: NovaSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFED4956).withValues(alpha: 0.3),
            borderRadius: NovaRadius.circularFull,
            border: Border.all(
              color: const Color(0xFFED4956).withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pulsing red dot
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFFED4956).withValues(
                        alpha: 0.5 + (_pulseAnimation.value * 0.5),
                      ),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              SizedBox(width: NovaSpacing.s),
              // Timer text
              Text(
                _formatRecordingTime(_recordingSeconds),
                style: NovaTypography.labelMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontFeatures: [const FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeSelector() {
    const double tabWidth = 70;
    const double tabHeight = 36;

    return ClipRRect(
      borderRadius: NovaRadius.circularFull,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          height: tabHeight,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            borderRadius: NovaRadius.circularFull,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              // Sliding indicator
              AnimatedBuilder(
                animation: _modeSlideAnimation,
                builder: (context, child) {
                  return Positioned(
                    left: _modeSlideAnimation.value * tabWidth,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: tabWidth,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: NovaRadius.circularFull,
                      ),
                    ),
                  );
                },
              ),
              // Labels
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeTab('FOTO', 0, tabWidth),
                  _buildModeTab('VIDEO', 1, tabWidth),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeTab(String label, int index, double width) {
    return GestureDetector(
      onTap: () => _setMode(index),
      child: AnimatedBuilder(
        animation: _modeSlideAnimation,
        builder: (context, child) {
          final isSelected = _selectedMode == index;
          final animValue = index == 0
              ? 1 - _modeSlideAnimation.value
              : _modeSlideAnimation.value;

          return Container(
            width: width,
            alignment: Alignment.center,
            child: Text(
              label,
              style: NovaTypography.labelMedium.copyWith(
                color: Color.lerp(
                  Colors.white.withValues(alpha: 0.7),
                  Colors.black,
                  animValue,
                ),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildShutterButton() {
    final isVideoMode = _selectedMode == 1;
    final Color buttonColor = isVideoMode ? const Color(0xFFED4956) : Colors.white;

    return GestureDetector(
      onTap: _isProcessingShutter
          ? null
          : () {
              if (isVideoMode) {
                if (_isRecording) {
                  _stopVideoRecording();
                } else {
                  _startVideoRecording();
                }
              } else {
                _takePhoto();
              }
            },
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final double glowOpacity = _isRecording ? 0.3 + (_pulseAnimation.value * 0.3) : 0.0;
          final double glowRadius = _isRecording ? 15 + (_pulseAnimation.value * 10) : 0.0;

          return Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _isRecording ? buttonColor : Colors.white,
                width: 5,
              ),
              boxShadow: [
                if (_isRecording || isVideoMode)
                  BoxShadow(
                    color: buttonColor.withValues(alpha: glowOpacity),
                    blurRadius: glowRadius,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOutCubic,
                width: _isRecording ? 36 : 72,
                height: _isRecording ? 36 : 72,
                decoration: BoxDecoration(
                  color: buttonColor,
                  borderRadius: BorderRadius.circular(_isRecording ? 10 : 36),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGalleryButton() {
    return GestureDetector(
      onTap: _openGallery,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: const Center(
          child: Icon(
            Icons.photo_library_outlined,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// Glass effect icon button for camera controls
class _GlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  State<_GlassIconButton> createState() => _GlassIconButtonState();
}

class _GlassIconButtonState extends State<_GlassIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _isPressed
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.white.withValues(alpha: 0.05),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Icon(
              widget.icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
