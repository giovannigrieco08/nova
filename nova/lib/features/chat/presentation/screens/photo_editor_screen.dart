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
import 'package:nova/features/profile/presentation/providers/profile_provider.dart' show currentProfileProvider;

/// Photo preview screen (Instagram Stories style)
///
/// Features:
/// - Full screen photo preview with rounded corners
/// - Top toolbar: close, text, link, sticker, music, download
/// - Bottom bar: caption field, replay toggle, send button with profile picture
class PhotoEditorScreen extends ConsumerStatefulWidget {
  final XFile imageFile;
  final Function(File editedImage, {bool allowReplay, String? caption})? onSend;

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

    return Scaffold(
      backgroundColor: NovaColors.editorBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top toolbar
            _buildTopToolbar(),

            // Main photo area with rounded corners
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 2),
                child: ClipRRect(
                  borderRadius: NovaRadius.circularM,
                  child: RepaintBoundary(
                    key: _repaintKey,
                    child: Image.file(
                      File(widget.imageFile.path),
                      fit: BoxFit.cover,
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
    );
  }

  Widget _buildTopToolbar() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      child: Row(
        children: [
          // Close button (X)
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),

          const Spacer(),

          // Download button with thin outline
          GestureDetector(
            onTap: _saveToGallery,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.download_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
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
          // Caption input field (Instagram style)
          Container(
            margin: EdgeInsets.only(bottom: NovaSpacing.m),
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.m),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: NovaRadius.circularXl,
            ),
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
            children: [
              // Replay toggle (tappable)
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _allowReplay = !_allowReplay;
                    });
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white54, width: 1),
                        ),
                        child: Center(
                          child: Icon(
                            _allowReplay ? Icons.play_arrow : Icons.looks_one,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      SizedBox(width: NovaSpacing.s),
                      Flexible(
                        child: Text(
                          _allowReplay
                              ? 'Consenti di riprodurre di nuovo'
                              : 'Consenti 1 sola visualizzazione',
                          style: NovaTypography.bodySmall.copyWith(
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SizedBox(width: NovaSpacing.m),

              // Send button with profile picture
              GestureDetector(
                onTap: _sendPhoto,
                child: Container(
                  padding: EdgeInsets.only(
                    left: 4,
                    right: NovaSpacing.m,
                    top: 4,
                    bottom: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: NovaRadius.circularXl,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Profile picture
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: NovaColors.primary(context),
                        backgroundImage: profileImageUrl != null
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: profileImageUrl == null
                            ? Icon(Icons.person, size: 16, color: Colors.white)
                            : null,
                      ),
                      SizedBox(width: NovaSpacing.s),
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
      final file = await _captureImage();
      if (file != null) {
        // Check if we're on desktop (Windows/macOS/Linux)
        final isDesktop = !kIsWeb &&
            (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

        if (isDesktop) {
          // On desktop, save to Downloads folder
          final downloadsDir = await getDownloadsDirectory();
          if (downloadsDir != null) {
            final fileName = 'nova_photo_${DateTime.now().millisecondsSinceEpoch}.png';
            final destPath = '${downloadsDir.path}${Platform.pathSeparator}$fileName';
            await file.copy(destPath);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Immagine salvata in Downloads'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            throw Exception('Cartella Downloads non trovata');
          }
        } else {
          // On mobile, save to gallery using Gal package
          await Gal.putImage(file.path);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Immagine salvata nella galleria!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
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
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<File?> _captureImage() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
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
      final filePath = '${directory.path}/edited_photo_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      return file;
    } catch (e) {
      return null;
    }
  }

  Future<void> _sendPhoto() async {
    final file = await _captureImage();
    if (file != null && widget.onSend != null) {
      // Get caption if provided
      final caption = _captionController.text.trim();
      widget.onSend!(
        file,
        allowReplay: _allowReplay,
        caption: caption.isNotEmpty ? caption : null,
      );
      // Navigator.pop is handled by the callback
    } else if (file == null) {
      // Show error if capture failed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile preparare l\'immagine per l\'invio'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // No callback, just close
      Navigator.pop(context);
    }
  }
}
