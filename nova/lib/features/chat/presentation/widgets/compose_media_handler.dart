import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:nova/core/animations/page_transitions.dart';
import 'package:nova/core/utils/image_orientation_fixer.dart';
import 'package:nova/core/utils/video_compressor.dart';
import 'package:nova/features/chat/domain/repositories/chat_repository.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';
import 'package:nova/features/chat/presentation/providers/chat_realtime_provider.dart';
import 'package:nova/features/chat/presentation/screens/camera_screen.dart';
import 'package:nova/features/chat/presentation/screens/photo_editor_screen.dart';
import 'package:nova/features/chat/presentation/screens/video_preview_screen.dart';
import 'package:nova/features/safety/presentation/screens/tos_acceptance_screen.dart';

/// Encapsulates camera, gallery, and media upload logic for the compose bar.
///
/// This is not a widget — it's a plain class that holds the media-related
/// methods previously inlined in [ChatComposeBar]. It requires a
/// [BuildContext], a [WidgetRef], and callbacks for toast / onSent.
class ComposeMediaHandler {
  final BuildContext Function() context;
  final WidgetRef ref;
  final void Function(String message, {bool isError, bool isWarning}) showToast;
  final VoidCallback? onSent;
  final bool Function() isMounted;

  final ImagePicker _imagePicker = ImagePicker();

  bool isOpeningGallery = false;

  ComposeMediaHandler({
    required this.context,
    required this.ref,
    required this.showToast,
    required this.onSent,
    required this.isMounted,
  });

  /// Pre-request photo permissions to avoid delay when opening gallery.
  Future<void> preRequestPhotoPermissions() async {
    if (Platform.isIOS) {
      Permission.photos.request();
    } else {
      Permission.storage.request();
    }
  }

  // ---------------------------------------------------------------------------
  // Camera
  // ---------------------------------------------------------------------------

  Future<void> openCamera() async {
    try {
      final result = await Navigator.push<Map<String, dynamic>>(
        context(),
        NovaPageRoute.swipeBack(page: const CameraScreen()),
      );

      if (result == null || !isMounted()) return;

      final String type = result['type'] as String;
      final XFile file = result['file'] as XFile;

      if (type == 'photo') {
        await Navigator.push(
          context(),
          NovaPageRoute.swipeBack(
            page: PhotoEditorScreen(
              imageFile: file,
              onSend: (File editedFile,
                  {bool allowReplay = true, String? caption}) async {
                await _handleMediaFromEditor(
                    editedFile, ChatMediaType.image, allowReplay,
                    caption: caption);
                if (isMounted()) Navigator.pop(context());
              },
            ),
          ),
        );
      } else if (type == 'video') {
        await Navigator.push(
          context(),
          NovaPageRoute.swipeBack(
            page: VideoPreviewScreen(
              videoFile: file,
              onSend: (File videoFile,
                  {bool allowReplay = true, String? caption}) async {
                await _handleMediaFromEditor(
                    videoFile, ChatMediaType.video, allowReplay,
                    caption: caption);
                if (isMounted()) Navigator.pop(context());
              },
            ),
          ),
        );
      }
    } catch (e) {
      showToast('Impossibile aprire la fotocamera', isError: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Gallery
  // ---------------------------------------------------------------------------

  Future<void> openGallery(void Function(void Function()) setState) async {
    if (isOpeningGallery) return;

    HapticFeedback.selectionClick();

    setState(() => isOpeningGallery = true);

    try {
      final XFile? media = await _imagePicker.pickMedia(
        requestFullMetadata: false,
      );

      if (media != null && isMounted()) {
        final extension = media.path.toLowerCase().split('.').last;
        final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'm4v', '3gp', 'webm']
            .contains(extension);

        if (isVideo) {
          _handleSelectedVideo(media);
        } else {
          final fixedPath = await ImageOrientationFixer.fixOrientation(
            media.path,
            isFrontCamera: false,
          );
          _handleSelectedImage(XFile(fixedPath));
        }
      }
    } catch (e) {
      showToast('Impossibile aprire la galleria', isError: true);
    } finally {
      if (isMounted()) {
        setState(() => isOpeningGallery = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Upload
  // ---------------------------------------------------------------------------

  Future<void> uploadMedia(
    String filePath,
    ChatMediaType mediaType, {
    int maxViews = 1,
    int? durationSeconds,
    String? caption,
  }) async {
    final tosAccepted =
        await showTosAcceptanceIfNeeded(context(), ref);
    if (!tosAccepted) return;

    debugPrint('[MediaUpload] _uploadMedia called');
    debugPrint('[MediaUpload] - filePath: $filePath');
    debugPrint('[MediaUpload] - mediaType: ${mediaType.value}');
    debugPrint('[MediaUpload] - maxViews: $maxViews');
    debugPrint('[MediaUpload] - caption: $caption');

    final file = File(filePath);
    if (!await file.exists()) {
      debugPrint(
          '[MediaUpload] ERROR: File does not exist at path: $filePath');
      showToast('File non trovato. Riprova.', isError: true);
      return;
    }

    var uploadPath = filePath;

    if (mediaType == ChatMediaType.video) {
      debugPrint('[MediaUpload] Compressing video...');
      showToast('Ottimizzazione video...');
      uploadPath = await VideoCompressor.compressIfNeeded(filePath);
      debugPrint('[MediaUpload] Using path after compression: $uploadPath');
    }

    final uploadFile = File(uploadPath);
    final fileSize = await uploadFile.length();
    debugPrint(
        '[MediaUpload] File size: $fileSize bytes (${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB)');

    if (fileSize > 50 * 1024 * 1024) {
      debugPrint('[MediaUpload] ERROR: File too large: $fileSize bytes');
      showToast('Video troppo grande (max 50MB). Prova un video più corto.',
          isError: true);
      return;
    }

    try {
      debugPrint('[MediaUpload] Starting upload via provider...');
      final result = await ref.read(uploadMediaProvider((
        filePath: uploadPath,
        mediaType: mediaType,
        maxViews: maxViews,
        durationSeconds: durationSeconds,
        caption: caption,
      )).future);

      debugPrint('[MediaUpload] Upload SUCCESS! Media ID: ${result.id}');

      debugPrint(
          '[MediaUpload] Refreshing message ${result.messageId} in realtime state...');
      await ref
          .read(chatRealtimeProvider.notifier)
          .refreshMessage(result.messageId);
      debugPrint('[MediaUpload] Message refreshed!');

      onSent?.call();
      debugPrint('[MediaUpload] Upload complete!');
    } on ChatMediaLimitException catch (e) {
      debugPrint(
          '[MediaUpload] ERROR: ChatMediaLimitException - ${e.message}');
      showToast(e.message, isWarning: true);
    } catch (e, stackTrace) {
      debugPrint('[MediaUpload] ERROR: $e');
      debugPrint('[MediaUpload] StackTrace: $stackTrace');
      String errorMsg = 'Errore durante l\'invio. Riprova.';
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('storage') ||
          errorStr.contains('exceeded') ||
          errorStr.contains('413')) {
        errorMsg = 'Video troppo grande. Prova un video più corto.';
      } else if (errorStr.contains('permission') ||
          errorStr.contains('403')) {
        errorMsg = 'Permesso negato. Riprova più tardi.';
      } else if (errorStr.contains('timeout') ||
          errorStr.contains('network')) {
        errorMsg = 'Connessione lenta. Riprova.';
      }
      showToast(errorMsg, isError: true);
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _handleMediaFromEditor(
      File file, ChatMediaType mediaType, bool allowReplay,
      {String? caption}) async {
    debugPrint('[MediaUpload] _handleMediaFromEditor called');
    debugPrint('[MediaUpload] - file: ${file.path}');
    debugPrint('[MediaUpload] - mediaType: ${mediaType.value}');
    debugPrint('[MediaUpload] - allowReplay: $allowReplay');
    debugPrint('[MediaUpload] - caption: $caption');
    final maxViews = allowReplay ? 2 : 1;
    await uploadMedia(file.path, mediaType,
        maxViews: maxViews, caption: caption);
  }

  void _handleSelectedImage(XFile file) {
    if (!isMounted()) return;

    Navigator.push(
      context(),
      NovaPageRoute.swipeBack(
        page: PhotoEditorScreen(
          imageFile: file,
          onSend: (editedFile,
              {bool allowReplay = true, String? caption}) async {
            await _handleMediaFromEditor(
                editedFile, ChatMediaType.image, allowReplay,
                caption: caption);
            if (isMounted()) Navigator.pop(context());
          },
        ),
      ),
    );
  }

  void _handleSelectedVideo(XFile file) {
    if (!isMounted()) return;

    Navigator.push(
      context(),
      NovaPageRoute.swipeBack(
        page: VideoPreviewScreen(
          videoFile: file,
          onSend: (videoFile,
              {bool allowReplay = true, String? caption}) async {
            await _handleMediaFromEditor(
                videoFile, ChatMediaType.video, allowReplay,
                caption: caption);
            if (isMounted()) Navigator.pop(context());
          },
        ),
      ),
    );
  }
}
