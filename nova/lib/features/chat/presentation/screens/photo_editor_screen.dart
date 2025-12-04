import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_typography.dart';

/// Photo editor screen like Instagram/Snapchat
///
/// Features:
/// - Full screen photo preview
/// - Add text overlays
/// - Drawing/doodle mode
/// - Sticker/emoji overlays
/// - Save and send functionality
class PhotoEditorScreen extends StatefulWidget {
  final XFile imageFile;
  final Function(File editedImage)? onSend;

  const PhotoEditorScreen({
    super.key,
    required this.imageFile,
    this.onSend,
  });

  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  final GlobalKey _repaintKey = GlobalKey();

  // Text overlays
  final List<_TextOverlay> _textOverlays = [];
  bool _isAddingText = false;
  final TextEditingController _textController = TextEditingController();
  Color _currentTextColor = Colors.white;

  // Drawing mode
  bool _isDrawingMode = false;
  final List<_DrawingPath> _drawingPaths = [];
  List<Offset> _currentPath = [];
  Color _drawingColor = Colors.white;
  double _strokeWidth = 5.0;

  // Stickers/Emojis
  final List<_StickerOverlay> _stickers = [];

  // Available colors
  final List<Color> _colors = [
    Colors.white,
    Colors.black,
    Colors.red,
    Colors.orange,
    Colors.yellow,
    Colors.green,
    Colors.blue,
    Colors.purple,
    Colors.pink,
  ];

  // Quick emojis for stickers
  final List<String> _quickEmojis = [
    '😀', '😂', '🥰', '😍', '🔥', '❤️', '👍', '🎉',
    '✨', '💯', '🥳', '😎', '🤔', '😭', '💪', '🙌',
  ];

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main content with repaint boundary for export
            RepaintBoundary(
              key: _repaintKey,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo
                  Image.file(
                    File(widget.imageFile.path),
                    fit: BoxFit.contain,
                  ),

                  // Drawing canvas
                  if (_drawingPaths.isNotEmpty || _isDrawingMode)
                    CustomPaint(
                      painter: _DrawingPainter(
                        paths: _drawingPaths,
                        currentPath: _currentPath,
                        currentColor: _drawingColor,
                        strokeWidth: _strokeWidth,
                      ),
                      size: Size.infinite,
                    ),

                  // Text overlays
                  ..._textOverlays.map((overlay) => _buildTextOverlay(overlay)),

                  // Sticker overlays
                  ..._stickers.map((sticker) => _buildStickerOverlay(sticker)),
                ],
              ),
            ),

            // Drawing gesture detector (only when in drawing mode)
            if (_isDrawingMode)
              GestureDetector(
                onPanStart: _onDrawStart,
                onPanUpdate: _onDrawUpdate,
                onPanEnd: _onDrawEnd,
                child: Container(color: Colors.transparent),
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

            // Text input overlay
            if (_isAddingText)
              _buildTextInputOverlay(),
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

          // Tools
          Row(
            children: [
              // Text tool
              _buildToolButton(
                icon: Icons.text_fields,
                label: 'Aa',
                isSelected: _isAddingText,
                onTap: () {
                  setState(() {
                    _isAddingText = true;
                    _isDrawingMode = false;
                  });
                },
              ),
              SizedBox(width: NovaSpacing.s),

              // Drawing tool
              _buildToolButton(
                icon: Icons.brush,
                isSelected: _isDrawingMode,
                onTap: () {
                  setState(() {
                    _isDrawingMode = !_isDrawingMode;
                    _isAddingText = false;
                  });
                },
              ),
              SizedBox(width: NovaSpacing.s),

              // Sticker/emoji tool
              _buildToolButton(
                icon: Icons.emoji_emotions,
                onTap: _showStickerPicker,
              ),
              SizedBox(width: NovaSpacing.s),

              // Music (placeholder)
              _buildToolButton(
                icon: Icons.music_note,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Musica in arrivo presto!')),
                  );
                },
              ),
              SizedBox(width: NovaSpacing.s),

              // Download/Save
              _buildToolButton(
                icon: Icons.download,
                onTap: _saveToGallery,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolButton({
    IconData? icon,
    String? label,
    bool isSelected = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.3)
              : Colors.black.withOpacity(0.5),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: label != null
              ? Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : Icon(
                  icon,
                  color: Colors.white,
                  size: 22,
                ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.all(NovaSpacing.m),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Replay option (placeholder)
          Row(
            children: [
              Icon(Icons.play_circle_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Consenti di riprodurre di nuovo',
                style: NovaTypography.bodySmall.copyWith(color: Colors.white),
              ),
            ],
          ),

          // Send button
          GestureDetector(
            onTap: _sendPhoto,
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
                    child: Icon(Icons.person, size: 14, color: Colors.white),
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
    );
  }

  Widget _buildTextInputOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Color picker
          Padding(
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.m),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _colors.map((color) {
                final isSelected = color == _currentTextColor;
                return GestureDetector(
                  onTap: () => setState(() => _currentTextColor = color),
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: NovaSpacing.l),

          // Text input
          Padding(
            padding: EdgeInsets.symmetric(horizontal: NovaSpacing.xl),
            child: TextField(
              controller: _textController,
              autofocus: true,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _currentTextColor,
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
              decoration: InputDecoration(
                hintText: 'Scrivi qualcosa...',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 32,
                ),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _addText(),
            ),
          ),
          SizedBox(height: NovaSpacing.l),

          // Done button
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _isAddingText = false;
                    _textController.clear();
                  });
                },
                child: Text(
                  'Annulla',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              SizedBox(width: NovaSpacing.xl),
              ElevatedButton(
                onPressed: _addText,
                style: ElevatedButton.styleFrom(
                  backgroundColor: NovaColors.primary(context),
                  padding: EdgeInsets.symmetric(
                    horizontal: NovaSpacing.l,
                    vertical: NovaSpacing.s,
                  ),
                ),
                child: Text(
                  'Aggiungi',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextOverlay(_TextOverlay overlay) {
    return Positioned(
      left: overlay.position.dx,
      top: overlay.position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            overlay.position += details.delta;
          });
        },
        onLongPress: () => _removeTextOverlay(overlay),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            overlay.text,
            style: TextStyle(
              color: overlay.color,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  blurRadius: 4,
                  color: Colors.black.withOpacity(0.5),
                  offset: Offset(1, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerOverlay(_StickerOverlay sticker) {
    return Positioned(
      left: sticker.position.dx,
      top: sticker.position.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            sticker.position += details.delta;
          });
        },
        onLongPress: () => _removeSticker(sticker),
        child: Text(
          sticker.emoji,
          style: TextStyle(fontSize: sticker.size),
        ),
      ),
    );
  }

  void _addText() {
    if (_textController.text.isNotEmpty) {
      setState(() {
        _textOverlays.add(_TextOverlay(
          text: _textController.text,
          color: _currentTextColor,
          position: Offset(
            MediaQuery.of(context).size.width / 2 - 50,
            MediaQuery.of(context).size.height / 2 - 50,
          ),
        ));
        _textController.clear();
        _isAddingText = false;
      });
    }
  }

  void _removeTextOverlay(_TextOverlay overlay) {
    setState(() {
      _textOverlays.remove(overlay);
    });
  }

  void _removeSticker(_StickerOverlay sticker) {
    setState(() {
      _stickers.remove(sticker);
    });
  }

  void _showStickerPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(top: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: NovaSpacing.m),
            Padding(
              padding: EdgeInsets.all(NovaSpacing.m),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _quickEmojis.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      _addSticker(emoji);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(emoji, style: TextStyle(fontSize: 32)),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: NovaSpacing.m),
          ],
        ),
      ),
    );
  }

  void _addSticker(String emoji) {
    setState(() {
      _stickers.add(_StickerOverlay(
        emoji: emoji,
        position: Offset(
          MediaQuery.of(context).size.width / 2 - 30,
          MediaQuery.of(context).size.height / 2 - 30,
        ),
      ));
    });
  }

  // Drawing methods
  void _onDrawStart(DragStartDetails details) {
    setState(() {
      _currentPath = [details.localPosition];
    });
  }

  void _onDrawUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPath.add(details.localPosition);
    });
  }

  void _onDrawEnd(DragEndDetails details) {
    if (_currentPath.isNotEmpty) {
      setState(() {
        _drawingPaths.add(_DrawingPath(
          points: List.from(_currentPath),
          color: _drawingColor,
          strokeWidth: _strokeWidth,
        ));
        _currentPath = [];
      });
    }
  }

  Future<void> _saveToGallery() async {
    try {
      final file = await _captureImage();
      if (file != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Immagine salvata!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Errore nel salvataggio'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<File?> _captureImage() async {
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

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
      widget.onSend!(file);
      Navigator.pop(context);
    } else {
      // Just close if no callback
      Navigator.pop(context);
    }
  }
}

// Helper classes
class _TextOverlay {
  String text;
  Color color;
  Offset position;

  _TextOverlay({
    required this.text,
    required this.color,
    required this.position,
  });
}

class _StickerOverlay {
  String emoji;
  Offset position;
  double size;

  _StickerOverlay({
    required this.emoji,
    required this.position,
    this.size = 60,
  });
}

class _DrawingPath {
  List<Offset> points;
  Color color;
  double strokeWidth;

  _DrawingPath({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });
}

class _DrawingPainter extends CustomPainter {
  final List<_DrawingPath> paths;
  final List<Offset> currentPath;
  final Color currentColor;
  final double strokeWidth;

  _DrawingPainter({
    required this.paths,
    required this.currentPath,
    required this.currentColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw completed paths
    for (final path in paths) {
      final paint = Paint()
        ..color = path.color
        ..strokeWidth = path.strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (path.points.length > 1) {
        final drawPath = Path();
        drawPath.moveTo(path.points.first.dx, path.points.first.dy);
        for (int i = 1; i < path.points.length; i++) {
          drawPath.lineTo(path.points[i].dx, path.points[i].dy);
        }
        canvas.drawPath(drawPath, paint);
      }
    }

    // Draw current path
    if (currentPath.isNotEmpty) {
      final paint = Paint()
        ..color = currentColor
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      if (currentPath.length > 1) {
        final drawPath = Path();
        drawPath.moveTo(currentPath.first.dx, currentPath.first.dy);
        for (int i = 1; i < currentPath.length; i++) {
          drawPath.lineTo(currentPath[i].dx, currentPath[i].dy);
        }
        canvas.drawPath(drawPath, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DrawingPainter oldDelegate) => true;
}
