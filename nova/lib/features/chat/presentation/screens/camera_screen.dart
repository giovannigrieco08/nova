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
/// - Flash toggle (off/auto/on)
/// - Front/back camera flip
/// - Photo/Video mode selector
/// - Gallery shortcut
/// - Maximum resolution support
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
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

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
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

    // Microphone permission will be requested when video mode is used

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
      ResolutionPreset.high, // Good quality, faster init than max
      enableAudio: true, // Keep audio ready for video mode
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

    try {
      final XFile file = await _controller!.takePicture();

      // Fix orientation issues on iOS (both front and rear cameras)
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
      // Request microphone permission when video recording starts
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

    try {
      final XFile file = await _controller!.stopVideoRecording();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isProcessingShutter = false;
        });
        Navigator.pop(context, {'type': 'video', 'file': file});
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isProcessingShutter = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Errore stop registrazione: $e')),
        );
      }
    }
  }

  Future<void> _openGallery() async {
    try {
      if (_selectedMode == 0) {
        // Photo mode
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 90,
        );
        if (image != null && mounted) {
          // Fix orientation issues on iOS for gallery images
          final fixedPath = await ImageOrientationFixer.fixOrientation(
            image.path,
            isFrontCamera: false,
          );
          Navigator.pop(context, {'type': 'photo', 'file': XFile(fixedPath)});
        }
      } else {
        // Video mode
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera preview
            if (_isInitialized && _controller != null)
              _buildCameraPreview()
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),

            // Top controls
            Positioned(
              top: NovaSpacing.m,
              left: NovaSpacing.m,
              right: NovaSpacing.m,
              child: _buildTopControls(),
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

  Widget _buildTopControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Close button
        _buildCircleButton(
          icon: Icons.close,
          onTap: () => Navigator.pop(context),
        ),

        // Flash toggle (only for back camera)
        if (!_isFrontCamera)
          _buildCircleButton(
            icon: _getFlashIcon(),
            onTap: _toggleFlash,
          )
        else
          const SizedBox(width: 44),

        // Flip camera
        _buildCircleButton(
          icon: Icons.flip_camera_ios,
          onTap: _flipCamera,
        ),
      ],
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
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode selector tabs
          _buildModeSelector(),

          SizedBox(height: NovaSpacing.l),

          // Main controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Gallery button
              _buildCircleButton(
                icon: Icons.photo_library_outlined,
                size: 50,
                onTap: _openGallery,
              ),

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

  Widget _buildModeSelector() {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: NovaRadius.circularXl,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeTab('FOTO', 0),
          _buildModeTab('VIDEO', 1),
        ],
      ),
    );
  }

  Widget _buildModeTab(String label, int index) {
    final isSelected = _selectedMode == index;

    return GestureDetector(
      onTap: () {
        if (!_isRecording) {
          setState(() {
            _selectedMode = index;
          });
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.m,
          vertical: NovaSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: NovaRadius.circularL,
        ),
        child: Text(
          label,
          style: NovaTypography.labelMedium.copyWith(
            color: isSelected ? Colors.black : Colors.white,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _buildShutterButton() {
    final isVideoMode = _selectedMode == 1;

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
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: _isRecording ? Colors.red : Colors.white,
            width: 4,
          ),
        ),
        padding: const EdgeInsets.all(4),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isRecording ? 32 : 64,
            height: _isRecording ? 32 : 64,
            decoration: BoxDecoration(
              color: isVideoMode ? Colors.red : Colors.white,
              // Use borderRadius for both states to avoid animation issues
              // Circle = very large radius, Square = small radius
              borderRadius: BorderRadius.circular(_isRecording ? 8 : 32),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 44,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Icon(
            icon,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}
