import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/theme/nova_shadows.dart';
import 'package:nova/features/profile/presentation/providers/profile_provider.dart'
    show currentProfileProvider;

/// Photo preview screen with premium glass UI (Instagram Stories style)
///
/// Features:
/// - Full screen photo preview with rounded corners and shadow
/// - Glass effect top toolbar
/// - Glass caption input field
/// - Segmented replay toggle control
/// - Gradient send button with profile picture
class PhotoEditorScreen extends ConsumerStatefulWidget {
  final XFile imageFile;
  final Future<void> Function(File editedImage,
      {bool allowReplay, String? caption})? onSend;

  const PhotoEditorScreen({
    super.key,
    required this.imageFile,
    this.onSend,
  });

  @override
  ConsumerState<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends ConsumerState<PhotoEditorScreen> {
  final GlobalKey _repaintKey = GlobalKey();
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();

  /// Whether recipient can replay the media (true = unlimited, false = 1 view)
  bool _allowReplay = true;
  bool _isSending = false;

  @override
  void dispose() {
    _captionController.dispose();
    _captionFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final profileImageUrl = profileAsync.valueOrNull?.avatarUrl;

    return GestureDetector(
      onTap: () {
        // Close keyboard when tapping outside caption field
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: NovaColors.editorBackground,
        body: SafeArea(
          child: Column(
            children: [
              // Top toolbar with glass effect
              _buildTopToolbar(),

              // Main photo area with rounded corners and shadow
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: NovaSpacing.xxs,
                    vertical: NovaSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: NovaRadius.circularL,
                    boxShadow: NovaShadows.large,
                    color: Colors.black,
                  ),
                  child: ClipRRect(
                    borderRadius: NovaRadius.circularL,
                    child: RepaintBoundary(
                      key: _repaintKey,
                      child: Image.file(
                        File(widget.imageFile.path),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom send bar
              _buildBottomBar(profileImageUrl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopToolbar() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.s,
        vertical: NovaSpacing.s,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Close button
          _GlassIconButton(
            icon: Icons.close,
            onTap: () => Navigator.pop(context),
          ),

          // Download button
          _GlassIconButton(
            icon: Icons.download_outlined,
            onTap: _saveToGallery,
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(String? profileImageUrl) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.m,
      ),
      color: NovaColors.editorBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Caption input field (glass style)
          _buildCaptionInput(),

          SizedBox(height: NovaSpacing.m),

          // Bottom row with replay toggle and send button
          Row(
            children: [
              // Replay toggle (segmented control style)
              _buildReplayToggle(),

              SizedBox(width: NovaSpacing.m),

              // Send button with gradient
              _buildSendButton(profileImageUrl),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCaptionInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: NovaRadius.circularXl,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: NovaSpacing.m),
          Icon(
            Icons.edit_outlined,
            color: Colors.white.withValues(alpha: 0.54),
            size: 20,
          ),
          SizedBox(width: NovaSpacing.s),
          Expanded(
            child: TextField(
              controller: _captionController,
              focusNode: _captionFocusNode,
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
                  color: Colors.white.withValues(alpha: 0.38),
                ),
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.symmetric(
                  vertical: NovaSpacing.s,
                ),
              ),
            ),
          ),
          SizedBox(width: NovaSpacing.m),
        ],
      ),
    );
  }

  Widget _buildReplayToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: NovaRadius.circularFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ReplayOption(
            icon: Icons.replay,
            label: 'Replay',
            isSelected: _allowReplay,
            onTap: () => setState(() => _allowReplay = true),
          ),
          _ReplayOption(
            icon: Icons.looks_one_outlined,
            label: '1x',
            isSelected: !_allowReplay,
            onTap: () => setState(() => _allowReplay = false),
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(String? profileImageUrl) {
    return Expanded(
      child: GestureDetector(
        onTap: _isSending ? null : _sendPhoto,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: NovaSpacing.m,
            vertical: NovaSpacing.s,
          ),
          decoration: BoxDecoration(
            color: _isSending
                ? NovaColors.primaryDark.withValues(alpha: 0.6)
                : NovaColors.primaryDark,
            borderRadius: NovaRadius.circularFull,
            boxShadow: [
              BoxShadow(
                color: NovaColors.primaryDark.withValues(alpha: 0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isSending)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              else ...[
                // Profile picture
                ClipOval(
                  child: Container(
                    width: 32,
                    height: 32,
                    color: Colors.white.withValues(alpha: 0.2),
                    child: profileImageUrl != null
                        ? Image.network(
                            profileImageUrl,
                            fit: BoxFit.cover,
                            width: 32,
                            height: 32,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.person,
                                    size: 16, color: Colors.white),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Icon(Icons.person,
                                  size: 16, color: Colors.white);
                            },
                          )
                        : const Icon(Icons.person,
                            size: 16, color: Colors.white),
                  ),
                ),
                SizedBox(width: NovaSpacing.s),
                Text(
                  'Invia',
                  style: NovaTypography.labelMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: NovaSpacing.xs),
                const Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveToGallery() async {
    try {
      final file = await _captureImage();
      if (file != null) {
        final isDesktop = !kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

        if (isDesktop) {
          final downloadsDir = await getDownloadsDirectory();
          if (downloadsDir != null) {
            final fileName =
                'nova_photo_${DateTime.now().millisecondsSinceEpoch}.png';
            final destPath =
                '${downloadsDir.path}${Platform.pathSeparator}$fileName';
            await file.copy(destPath);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Immagine salvata in Downloads'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            throw Exception('Cartella Downloads non trovata');
          }
        } else {
          await Gal.putImage(file.path);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Immagine salvata nella galleria!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossibile catturare l\'immagine'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<File?> _captureImage() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        return null;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        return null;
      }

      final bytes = byteData.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final filePath =
          '${directory.path}/edited_photo_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return file;
    } catch (e) {
      return null;
    }
  }

  Future<void> _sendPhoto() async {
    if (_isSending) return;

    // Use original file directly instead of capturing the rendered view
    // This preserves full resolution and avoids black padding from BoxFit.contain
    final file = File(widget.imageFile.path);
    if (await file.exists() && widget.onSend != null) {
      setState(() => _isSending = true);

      try {
        final caption = _captionController.text.trim();
        await widget.onSend!(
          file,
          allowReplay: _allowReplay,
          caption: caption.isNotEmpty ? caption : null,
        );
      } finally {
        if (mounted) {
          setState(() => _isSending = false);
        }
      }
    } else if (file == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossibile preparare l\'immagine per l\'invio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}

/// Glass effect icon button for editor toolbar
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
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _isPressed
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.1),
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

/// Replay option button for segmented control
class _ReplayOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ReplayOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.m,
          vertical: NovaSpacing.s,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? NovaColors.primary(context).withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: NovaRadius.circularFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white70,
              size: 18,
            ),
            SizedBox(width: NovaSpacing.xs),
            Text(
              label,
              style: NovaTypography.labelSmall.copyWith(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
