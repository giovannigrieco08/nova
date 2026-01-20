import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/core/utils/image_orientation_fixer.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/domain/repositories/chat_repository.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';
import 'package:nova/features/chat/presentation/widgets/chat_reply_preview.dart';
import 'package:nova/features/chat/presentation/widgets/mention_autocomplete.dart';
import 'package:nova/features/chat/presentation/screens/photo_editor_screen.dart';
import 'package:nova/features/chat/presentation/screens/camera_screen.dart';
import 'package:nova/features/chat/presentation/screens/video_preview_screen.dart';
import 'package:nova/core/animations/page_transitions.dart';

/// Compose bar for sending chat messages.
///
/// Features:
/// - Text input with character counter (max 500)
/// - Reply preview with dismiss
/// - Send button with loading state
/// - @mention detection and autocomplete trigger
class ChatComposeBar extends ConsumerStatefulWidget {
  final ChatMessage? replyTo;
  final VoidCallback? onCancelReply;
  final VoidCallback? onSent;

  const ChatComposeBar({
    super.key,
    this.replyTo,
    this.onCancelReply,
    this.onSent,
  });

  @override
  ConsumerState<ChatComposeBar> createState() => _ChatComposeBarState();
}

class _ChatComposeBarState extends ConsumerState<ChatComposeBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  bool _recorderInitialized = false;

  // Voice recording state
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  String? _recordingPath;
  Timer? _durationTimer;

  // Waveform animation (more bars for WhatsApp-like density)
  List<double> _waveformLevels = List.filled(50, 0.2);

  // Mention tracking
  int? _mentionStartIndex;
  final List<Map<String, dynamic>> _selectedMentions = [];

  // Emoji picker state
  bool _showEmojiPicker = false;

  // Gallery state
  bool _isOpeningGallery = false;

  static const int _maxCharacters = 500;

  /// Show a toast-style notification (Cupertino compatible)
  void _showToast(String message, {bool isError = false, bool isWarning = false}) {
    if (!mounted) return;

    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: MediaQuery.of(context).viewInsets.bottom + 100,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isError
                  ? CupertinoColors.systemRed.darkColor
                  : isWarning
                      ? CupertinoColors.systemOrange.darkColor
                      : CupertinoColors.systemGrey.darkColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message,
              style: const TextStyle(
                color: CupertinoColors.white,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _initRecorder();
    // Pre-request photo permissions for faster gallery opening
    _preRequestPhotoPermissions();
  }

  /// Pre-request photo permissions to avoid delay when opening gallery
  Future<void> _preRequestPhotoPermissions() async {
    // Request permission in background - don't wait for result
    if (Platform.isIOS) {
      Permission.photos.request();
    } else {
      Permission.storage.request();
    }
  }

  Future<bool> _initRecorder() async {
    try {
      debugPrint('[VoiceRecorder] Opening recorder...');
      await _audioRecorder.openRecorder();
      _recorderInitialized = true;
      debugPrint('[VoiceRecorder] Recorder opened successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[VoiceRecorder] ERROR opening recorder: $e');
      debugPrint('[VoiceRecorder] Stack trace: $stackTrace');
      _recorderInitialized = false;
      return false;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _durationTimer?.cancel();
    _durationTimer = null;
    if (_recorderInitialized) {
      try {
        _audioRecorder.closeRecorder();
      } catch (e) {
        // Ignore errors during cleanup
      }
    }
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    ref.read(composeStateProvider.notifier).updateContent(text);

    // Check for @mention trigger
    _checkMentionTrigger(text);
  }

  void _checkMentionTrigger(String text) {
    final cursorPosition = _controller.selection.baseOffset;
    if (cursorPosition < 0) return;

    // Find the last @ before cursor
    final textBeforeCursor = text.substring(0, cursorPosition);
    final lastAtIndex = textBeforeCursor.lastIndexOf('@');

    if (lastAtIndex >= 0) {
      // Check if we're still in a mention (no space after @)
      final textAfterAt = textBeforeCursor.substring(lastAtIndex + 1);
      if (!textAfterAt.contains(' ')) {
        // Track the @ start position
        _mentionStartIndex = lastAtIndex;
        // Trigger mention search
        ref.read(composeStateProvider.notifier).searchMentions(textAfterAt);
        return;
      }
    }

    // Hide mention picker if not in mention
    _mentionStartIndex = null;
    ref.read(composeStateProvider.notifier).hideMentionPicker();
  }

  /// Handle mention selection from autocomplete
  void _onMentionSelected(MentionSearchResult result) {
    if (_mentionStartIndex == null) return;

    final text = _controller.text;
    final cursorPosition = _controller.selection.baseOffset;

    // Replace @query with @fullName
    final beforeMention = text.substring(0, _mentionStartIndex!);
    final afterCursor = cursorPosition < text.length ? text.substring(cursorPosition) : '';
    final mentionText = '@${result.fullName} ';
    final newText = beforeMention + mentionText + afterCursor;

    // Track this mention for sending
    _selectedMentions.add({
      'user_id': result.userId,
      'username': result.fullName,
      'start_index': _mentionStartIndex!,
      'end_index': _mentionStartIndex! + mentionText.length - 1, // -1 for trailing space
    });

    // Update text field
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: beforeMention.length + mentionText.length,
    );

    // Hide autocomplete
    _mentionStartIndex = null;
    ref.read(composeStateProvider.notifier).hideMentionPicker();
  }

  Future<void> _sendMessage() async {
    final state = ref.read(composeStateProvider);
    if (state.content.trim().isEmpty || state.isSending) return;

    // Store message content before sending (in case it fails)
    final messageContent = state.content.trim();
    final messageMentions = List<Map<String, dynamic>>.from(_selectedMentions);
    final messageReplyToId = state.replyToId;

    // Use tracked mentions from autocomplete selection
    final success = await ref.read(composeStateProvider.notifier).sendMessage(
          mentions: messageMentions,
        );

    if (success) {
      _controller.clear();
      _selectedMentions.clear();
      widget.onSent?.call();
    } else {
      // Check if it's a generic error (not rate limit or profanity)
      final error = ref.read(composeStateProvider).error;
      if (error != null &&
          !error.contains('rate limit') &&
          !error.contains('linguaggio') &&
          !error.contains('offensiv')) {
        // Add to failed messages for retry
        ref.read(failedMessagesProvider.notifier).addFailedMessage(
              content: messageContent,
              mentions: messageMentions,
              replyToId: messageReplyToId,
              errorMessage: error,
            );

        // Clear the compose bar so user can type new messages
        _controller.clear();
        _selectedMentions.clear();
        ref.read(composeStateProvider.notifier).clearError();
      }
      // For rate limit/profanity, keep message in compose bar so user can edit
    }
  }

  // =========================================================================
  // Emoji Picker Methods
  // =========================================================================

  /// Toggle emoji picker visibility
  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      // Hide emoji picker and show keyboard
      setState(() => _showEmojiPicker = false);
      _focusNode.requestFocus();
    } else {
      // Hide keyboard and show emoji picker
      _focusNode.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  /// Handle emoji selection
  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _controller.text;
    final cursorPosition = _controller.selection.baseOffset;

    // Insert emoji at cursor position
    final newText = cursorPosition >= 0
        ? text.substring(0, cursorPosition) + emoji.emoji + text.substring(cursorPosition)
        : text + emoji.emoji;

    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: (cursorPosition >= 0 ? cursorPosition : text.length) + emoji.emoji.length,
    );
  }

  /// Handle backspace in emoji picker
  void _onEmojiBackspace() {
    final text = _controller.text;
    if (text.isEmpty) return;

    final cursorPosition = _controller.selection.baseOffset;
    if (cursorPosition <= 0) return;

    // Remove character before cursor
    final newText = text.substring(0, cursorPosition - 1) + text.substring(cursorPosition);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(offset: cursorPosition - 1);
  }

  // =========================================================================
  // Media & Input Methods
  // =========================================================================

  /// Open custom camera screen (photo + video support)
  Future<void> _openCamera() async {
    try {
      // Navigate to custom camera screen
      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        NovaPageRoute.swipeBack(page: const CameraScreen()),
      );

      if (result == null || !mounted) return;

      final String type = result['type'] as String;
      final XFile file = result['file'] as XFile;

      if (type == 'photo') {
        // Navigate to photo editor screen
        await Navigator.push(
          context,
          NovaPageRoute.swipeBack(
            page: PhotoEditorScreen(
              imageFile: file,
              onSend: (File editedFile, {bool allowReplay = true, String? caption}) {
                _handleMediaFromEditor(editedFile, ChatMediaType.image, allowReplay, caption: caption);
                Navigator.pop(context);
              },
            ),
          ),
        );
      } else if (type == 'video') {
        // Navigate to video preview screen
        await Navigator.push(
          context,
          NovaPageRoute.swipeBack(
            page: VideoPreviewScreen(
              videoFile: file,
              onSend: (File videoFile, {bool allowReplay = true, String? caption}) {
                _handleMediaFromEditor(videoFile, ChatMediaType.video, allowReplay, caption: caption);
                Navigator.pop(context);
              },
            ),
          ),
        );
      }
    } catch (e) {
      _showToast('Impossibile aprire la fotocamera', isError: true);
    }
  }

  /// Handle media from photo/video editor screens
  Future<void> _handleMediaFromEditor(File file, ChatMediaType mediaType, bool allowReplay, {String? caption}) async {
    debugPrint('[MediaUpload] _handleMediaFromEditor called');
    debugPrint('[MediaUpload] - file: ${file.path}');
    debugPrint('[MediaUpload] - mediaType: ${mediaType.value}');
    debugPrint('[MediaUpload] - allowReplay: $allowReplay');
    debugPrint('[MediaUpload] - caption: $caption');
    final maxViews = allowReplay ? 2 : 1;
    await _uploadMedia(file.path, mediaType, maxViews: maxViews, caption: caption);
  }

  /// Open gallery to pick an image or video - optimized for speed
  Future<void> _openGallery() async {
    // Prevent double-tap
    if (_isOpeningGallery) return;

    // Immediate haptic feedback for responsiveness
    HapticFeedback.selectionClick();

    setState(() => _isOpeningGallery = true);

    try {
      // Use pickMedia to allow both images and videos
      // requestFullMetadata: false for faster gallery opening
      final XFile? media = await _imagePicker.pickMedia(
        requestFullMetadata: false,
      );

      if (media != null && mounted) {
        // Determine if it's a video or image based on extension
        final extension = media.path.toLowerCase().split('.').last;
        final isVideo = ['mp4', 'mov', 'avi', 'mkv', 'm4v', '3gp', 'webm'].contains(extension);

        if (isVideo) {
          _handleSelectedVideo(media);
        } else {
          // Fix orientation issues on iOS for gallery images
          final fixedPath = await ImageOrientationFixer.fixOrientation(
            media.path,
            isFrontCamera: false,
          );
          _handleSelectedImage(XFile(fixedPath));
        }
      }
    } catch (e) {
      _showToast('Impossibile aprire la galleria', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isOpeningGallery = false);
      }
    }
  }

  /// Handle selected image file - opens PhotoEditorScreen for preview
  Future<void> _handleSelectedImage(XFile file) async {
    if (!mounted) return;

    // Open photo editor screen (same flow as camera)
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(
        page: PhotoEditorScreen(
          imageFile: file,
          onSend: (editedFile, {bool allowReplay = true, String? caption}) {
            _handleMediaFromEditor(editedFile, ChatMediaType.image, allowReplay, caption: caption);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  /// Handle selected video file - opens VideoPreviewScreen for preview
  Future<void> _handleSelectedVideo(XFile file) async {
    if (!mounted) return;

    // Open video preview screen (same flow as camera)
    Navigator.push(
      context,
      NovaPageRoute.swipeBack(
        page: VideoPreviewScreen(
          videoFile: file,
          onSend: (videoFile, {bool allowReplay = true, String? caption}) {
            _handleMediaFromEditor(videoFile, ChatMediaType.video, allowReplay, caption: caption);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  // =========================================================================
  // Voice Recording Methods
  // =========================================================================

  /// Start recording voice message
  Future<void> _startRecording() async {
    debugPrint('[VoiceRecorder] _startRecording called');
    try {
      // Check microphone permission - first check current status
      debugPrint('[VoiceRecorder] Checking microphone permission...');
      var status = await Permission.microphone.status;
      debugPrint('[VoiceRecorder] Current permission status: $status');

      // If not determined yet, request permission
      if (status.isDenied || status.isRestricted) {
        debugPrint('[VoiceRecorder] Requesting permission...');
        status = await Permission.microphone.request();
        debugPrint('[VoiceRecorder] After request status: $status');
      }

      // Check if permission is granted (includes limited on iOS)
      if (!status.isGranted && !status.isLimited) {
        if (status.isPermanentlyDenied && mounted) {
          // Show dialog to guide user to Settings
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Permesso microfono'),
              content: const Text('Per registrare messaggi vocali, abilita il microfono nelle Impostazioni.'),
              actions: [
                CupertinoDialogAction(
                  child: const Text('Annulla'),
                  onPressed: () => Navigator.pop(context),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
                  child: const Text('Impostazioni'),
                  onPressed: () {
                    Navigator.pop(context);
                    openAppSettings();
                  },
                ),
              ],
            ),
          );
        } else {
          _showToast('Permesso microfono necessario', isError: true);
        }
        return;
      }

      debugPrint('[VoiceRecorder] Permission granted, proceeding...');

      // Initialize recorder if needed
      if (!_recorderInitialized) {
        debugPrint('[VoiceRecorder] Initializing recorder...');
        final initialized = await _initRecorder();
        debugPrint('[VoiceRecorder] Recorder initialized: $initialized');
        if (!initialized) {
          _showToast('Impossibile inizializzare il registratore', isError: true);
          return;
        }
      }

      // Get temp directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      // Use .m4a for iOS (aacMP4 codec) and .aac for Android (aacADTS codec)
      final extension = Platform.isIOS ? 'm4a' : 'aac';
      _recordingPath = '${tempDir.path}/voice_$timestamp.$extension';
      debugPrint('[VoiceRecorder] Recording path: $_recordingPath');

      // Start recording (use aacMP4 for better iOS compatibility)
      debugPrint('[VoiceRecorder] Starting recorder with codec: ${Platform.isIOS ? "aacMP4" : "aacADTS"}');
      await _audioRecorder.startRecorder(
        toFile: _recordingPath,
        codec: Platform.isIOS ? Codec.aacMP4 : Codec.aacADTS,
      );
      debugPrint('[VoiceRecorder] Recorder started successfully');

      setState(() {
        _isRecording = true;
        _isPaused = false;
        _recordingDuration = Duration.zero;
        _waveformLevels = List.filled(50, 0.2);
      });

      // Start duration timer using Timer.periodic (replaces while loop)
      _durationTimer?.cancel();
      final random = Random();
      _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (_isRecording && !_isPaused && mounted) {
          setState(() {
            // Update duration every second
            if (timer.tick % 10 == 0) {
              _recordingDuration += const Duration(seconds: 1);
            }
            // Update waveform with random levels (simulated)
            _waveformLevels = List.generate(50, (_) => 0.2 + random.nextDouble() * 0.8);
          });
        } else if (!_isRecording) {
          timer.cancel();
        }
      });
    } catch (e, stackTrace) {
      debugPrint('[VoiceRecorder] ERROR in _startRecording: $e');
      debugPrint('[VoiceRecorder] Stack trace: $stackTrace');
      _showToast('Impossibile avviare la registrazione', isError: true);
    }
  }

  /// Stop recording and handle the audio file
  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    // Cancel the duration timer
    _durationTimer?.cancel();
    _durationTimer = null;

    try {
      final path = await _audioRecorder.stopRecorder();

      setState(() {
        _isRecording = false;
        _isPaused = false;
      });

      if (path != null && mounted) {
        // Only send if recording is at least 1 second
        if (_recordingDuration.inSeconds >= 1) {
          _handleVoiceMessage(File(path), _recordingDuration.inSeconds);
        } else {
          // Delete short recording
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
          _showToast('Registrazione troppo breve', isWarning: true);
        }
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
    }
  }

  /// Toggle pause/resume recording
  Future<void> _togglePauseRecording() async {
    if (!_isRecording) return;

    try {
      if (_isPaused) {
        // Resume recording
        await _audioRecorder.resumeRecorder();
        setState(() => _isPaused = false);
      } else {
        // Pause recording
        await _audioRecorder.pauseRecorder();
        setState(() => _isPaused = true);
      }
    } catch (e) {
      // Ignore errors during pause toggle
    }
  }

  /// Cancel recording without sending
  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    // Cancel the duration timer
    _durationTimer?.cancel();
    _durationTimer = null;

    try {
      final path = await _audioRecorder.stopRecorder();

      setState(() {
        _isRecording = false;
        _isPaused = false;
      });

      // Delete the recording
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
    }
  }

  /// Handle recorded voice message
  Future<void> _handleVoiceMessage(File audioFile, int durationSeconds) async {
    // Voice messages always have 1 view (no picker needed)
    await _uploadMedia(
      audioFile.path,
      ChatMediaType.audio,
      maxViews: 1,
      durationSeconds: durationSeconds,
    );
  }

  // =========================================================================
  // Media Upload
  // =========================================================================

  /// Upload media to chat (image, video, or audio)
  ///
  /// [maxViews] determines how many times the media can be viewed (1 or 2).
  /// [durationSeconds] is the duration for audio messages.
  /// [caption] is an optional caption for images/videos.
  Future<void> _uploadMedia(
    String filePath,
    ChatMediaType mediaType, {
    int maxViews = 1,
    int? durationSeconds,
    String? caption,
  }) async {
    debugPrint('[MediaUpload] _uploadMedia called');
    debugPrint('[MediaUpload] - filePath: $filePath');
    debugPrint('[MediaUpload] - mediaType: ${mediaType.value}');
    debugPrint('[MediaUpload] - maxViews: $maxViews');
    debugPrint('[MediaUpload] - caption: $caption');

    try {
      debugPrint('[MediaUpload] Starting upload via provider...');
      final result = await ref.read(uploadMediaProvider((
        filePath: filePath,
        mediaType: mediaType,
        maxViews: maxViews,
        durationSeconds: durationSeconds,
        caption: caption,
      )).future);

      debugPrint('[MediaUpload] Upload SUCCESS! Media ID: ${result.id}');

      // Invalidate messages stream to refresh with new media
      debugPrint('[MediaUpload] Invalidating chatMessagesStreamProvider...');
      ref.invalidate(chatMessagesStreamProvider);

      // Notify parent that something was sent
      widget.onSent?.call();
      debugPrint('[MediaUpload] Upload complete!');
    } on ChatMediaLimitException catch (e) {
      // Show limit error as toast
      debugPrint('[MediaUpload] ERROR: ChatMediaLimitException - ${e.message}');
      _showToast(e.message, isWarning: true);
    } catch (e, stackTrace) {
      debugPrint('[MediaUpload] ERROR: $e');
      debugPrint('[MediaUpload] StackTrace: $stackTrace');
      _showToast('Errore durante l\'invio. Riprova.', isError: true);
    }
  }

  /// Format duration as mm:ss
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Build recording UI widget - WhatsApp style (single row)
  /// Layout: [🗑️] [timer waveform] [⏸️] [▶️]
  Widget _buildRecordingUI() {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.m,
        vertical: NovaSpacing.s,
      ),
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        border: Border(
          top: BorderSide(color: NovaColors.border(context)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Trash/Delete button (LEFT)
            GestureDetector(
              onTap: _cancelRecording,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: Icon(
                  Icons.delete_outline,
                  color: NovaColors.textSecondary(context),
                  size: 24,
                ),
              ),
            ),

            SizedBox(width: NovaSpacing.xs),

            // 2. Timer + Waveform (CENTER - expanded)
            Expanded(
              child: Container(
                height: 44,
                padding: EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: NovaColors.card(context),
                  borderRadius: NovaRadius.circularXl,
                  border: Border.all(
                    color: NovaColors.border(context),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Timer
                    Text(
                      _formatDuration(_recordingDuration),
                      style: TextStyle(
                        color: NovaColors.textPrimary(context),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),

                    SizedBox(width: 8),

                    // Waveform visualization
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: _waveformLevels.map((level) {
                          return Container(
                            width: 2,
                            height: 24 * level,
                            decoration: BoxDecoration(
                              color: _isPaused
                                  ? NovaColors.textTertiary(context)
                                  : NovaColors.primary(context),
                              borderRadius: NovaRadius.circularXxs,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(width: NovaSpacing.xs),

            // 3. Pause/Resume button (red circle outline)
            GestureDetector(
              onTap: _togglePauseRecording,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: NovaColors.error(context),
                    width: 2,
                  ),
                ),
                child: Icon(
                  _isPaused ? Icons.mic : Icons.pause,
                  color: NovaColors.error(context),
                  size: 22,
                ),
              ),
            ),

            SizedBox(width: NovaSpacing.xs),

            // 4. Send button (Nova purple circle)
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: NovaColors.primary(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send,
                  color: NovaColors.onPrimaryLight,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(composeStateProvider);
    final characterCount = state.content.length;
    final isOverLimit = characterCount > _maxCharacters;
    final canSend =
        state.content.trim().isNotEmpty && !isOverLimit && !state.isSending;

    return Container(
      decoration: BoxDecoration(
        color: NovaColors.surface(context),
        border: Border(
          top: BorderSide(color: NovaColors.border(context)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Mention autocomplete dropdown
            if (state.isShowingMentionPicker && state.mentionResults.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.m,
                  vertical: NovaSpacing.xs,
                ),
                child: MentionAutocomplete(
                  results: state.mentionResults,
                  onSelect: _onMentionSelected,
                ),
              ),

            // Reply preview
            if (widget.replyTo != null)
              Container(
                padding: EdgeInsets.fromLTRB(
                  NovaSpacing.m,
                  NovaSpacing.s,
                  NovaSpacing.m,
                  0,
                ),
                child: ChatReplyPreview(
                  replyTo: widget.replyTo!,
                  onDismiss: widget.onCancelReply,
                ),
              ),

            // Error message
            if (state.error != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.m,
                  vertical: NovaSpacing.xs,
                ),
                color: NovaColors.error(context).withValues(alpha: 0.1),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: NovaColors.error(context),
                    ),
                    SizedBox(width: NovaSpacing.xs),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: NovaTypography.bodySmall.copyWith(
                          color: NovaColors.error(context),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () =>
                          ref.read(composeStateProvider.notifier).clearError(),
                      color: NovaColors.error(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      tooltip: 'Chiudi',
                    ),
                  ],
                ),
              ),

            // Input row - Instagram style OR Recording UI
            if (_isRecording)
              // Recording UI
              _buildRecordingUI()
            else
              // Normal input row
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: NovaSpacing.s,
                  vertical: NovaSpacing.xs,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Camera button (prominent, left side)
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            NovaColors.primary(context),
                            NovaColors.primary(context).withBlue(255),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: _openCamera,
                        icon: const Icon(
                          Icons.camera_alt,
                          color: NovaColors.onPrimaryLight,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: 'Fotocamera',
                      ),
                    ),

                    SizedBox(width: NovaSpacing.s),

                    // Text input field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: NovaColors.card(context),
                          borderRadius: NovaRadius.circularXl,
                          border: Border.all(
                            color: NovaColors.border(context),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            // Text field
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                maxLines: 4,
                                minLines: 1,
                                textCapitalization: TextCapitalization.sentences,
                                onTap: () {
                                  // Hide emoji picker when text field is tapped
                                  if (_showEmojiPicker) {
                                    setState(() => _showEmojiPicker = false);
                                  }
                                },
                                style: NovaTypography.bodyMedium.copyWith(
                                  color: NovaColors.textPrimary(context),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Messaggio...',
                                  hintStyle: NovaTypography.bodyMedium.copyWith(
                                    color: NovaColors.textTertiary(context),
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: NovaSpacing.s,
                                    vertical: NovaSpacing.s,
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ),

                            // Send button (when typing)
                            if (state.content.isNotEmpty) ...[
                              Padding(
                                padding: EdgeInsets.only(right: NovaSpacing.xs),
                                child: state.isSending
                                    ? Padding(
                                        padding: EdgeInsets.all(8),
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: NovaColors.primary(context),
                                          ),
                                        ),
                                      )
                                    : TextButton(
                                        onPressed: canSend ? _sendMessage : null,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.symmetric(horizontal: 12),
                                          minimumSize: Size(0, 36),
                                        ),
                                        child: Text(
                                          'Invia',
                                          style: NovaTypography.bodyMedium.copyWith(
                                            color: canSend
                                                ? NovaColors.primary(context)
                                                : NovaColors.textTertiary(context),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Icons outside the text input (when not typing)
                    if (state.content.isEmpty) ...[
                      SizedBox(width: NovaSpacing.xs),
                      // Microphone - tap to start recording
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          debugPrint('[VoiceRecorder] Microphone button TAPPED!');
                          _startRecording();
                        },
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            Icons.mic_none,
                            color: NovaColors.textSecondary(context),
                            size: 26,
                          ),
                        ),
                      ),
                      // Image picker
                      GestureDetector(
                        onTap: _openGallery,
                        child: Padding(
                          padding: EdgeInsets.only(left: 2, right: 4),
                          child: _isOpeningGallery
                              ? SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: NovaColors.textSecondary(context),
                                  ),
                                )
                              : Icon(
                                  Icons.image_outlined,
                                  color: NovaColors.textSecondary(context),
                                  size: 26,
                                ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            // Character counter (only when approaching limit)
            if (characterCount > _maxCharacters - 50)
              Padding(
                padding: EdgeInsets.only(
                  right: NovaSpacing.m,
                  bottom: NovaSpacing.xs,
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '$characterCount / $_maxCharacters',
                    style: NovaTypography.bodySmall.copyWith(
                      color: isOverLimit
                          ? NovaColors.error(context)
                          : NovaColors.textTertiary(context),
                    ),
                  ),
                ),
              ),

            // Emoji picker
            if (_showEmojiPicker)
              SizedBox(
                height: 250,
                child: EmojiPicker(
                  onEmojiSelected: _onEmojiSelected,
                  onBackspacePressed: _onEmojiBackspace,
                  config: Config(
                    height: 250,
                    checkPlatformCompatibility: true,
                    emojiViewConfig: EmojiViewConfig(
                      columns: 8,
                      emojiSizeMax: 28,
                      verticalSpacing: 0,
                      horizontalSpacing: 0,
                      gridPadding: EdgeInsets.zero,
                      recentsLimit: 28,
                      replaceEmojiOnLimitExceed: true,
                      noRecents: Text(
                        'Nessun emoji recente',
                        style: NovaTypography.bodySmall.copyWith(
                          color: NovaColors.textTertiary(context),
                        ),
                      ),
                      loadingIndicator: Center(
                        child: CircularProgressIndicator(
                          color: NovaColors.primary(context),
                        ),
                      ),
                      buttonMode: ButtonMode.MATERIAL,
                      backgroundColor: NovaColors.surface(context),
                    ),
                    categoryViewConfig: CategoryViewConfig(
                      initCategory: Category.RECENT,
                      backgroundColor: NovaColors.surface(context),
                      indicatorColor: NovaColors.primary(context),
                      iconColor: NovaColors.textTertiary(context),
                      iconColorSelected: NovaColors.primary(context),
                      tabIndicatorAnimDuration: kTabScrollDuration,
                      categoryIcons: const CategoryIcons(),
                    ),
                    bottomActionBarConfig: BottomActionBarConfig(
                      backgroundColor: NovaColors.surface(context),
                      buttonColor: NovaColors.primary(context),
                      buttonIconColor: NovaColors.onPrimaryLight,
                      showBackspaceButton: true,
                      showSearchViewButton: true,
                    ),
                    searchViewConfig: SearchViewConfig(
                      backgroundColor: NovaColors.surface(context),
                      buttonIconColor: NovaColors.textSecondary(context),
                      hintText: 'Cerca emoji...',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
