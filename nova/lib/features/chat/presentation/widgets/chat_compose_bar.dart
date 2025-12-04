import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/domain/repositories/chat_repository.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';
import 'package:nova/features/chat/presentation/widgets/chat_reply_preview.dart';
import 'package:nova/features/chat/presentation/widgets/mention_autocomplete.dart';
import 'package:nova/features/chat/presentation/screens/photo_editor_screen.dart';

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
  Duration _recordingDuration = Duration.zero;
  String? _recordingPath;

  // Mention tracking
  int? _mentionStartIndex;
  final List<Map<String, dynamic>> _selectedMentions = [];

  static const int _maxCharacters = 500;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    await _audioRecorder.openRecorder();
    _recorderInitialized = true;
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    if (_recorderInitialized) {
      _audioRecorder.closeRecorder();
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

    // Use tracked mentions from autocomplete selection
    final success = await ref.read(composeStateProvider.notifier).sendMessage(
          mentions: List.from(_selectedMentions),
        );

    if (success) {
      _controller.clear();
      _selectedMentions.clear();
      widget.onSent?.call();
    }
  }

  // =========================================================================
  // Media & Input Methods
  // =========================================================================

  /// Open camera to take a photo, then navigate to photo editor
  Future<void> _openCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (photo != null && mounted) {
        // Navigate to photo editor screen (Snapchat-style)
        final editedImage = await Navigator.push<File>(
          context,
          MaterialPageRoute(
            builder: (context) => PhotoEditorScreen(
              imageFile: photo,
              onSend: (File editedFile) {
                // Return the edited file back
                Navigator.pop(context, editedFile);
              },
            ),
          ),
        );

        // If user sent the edited photo, handle it
        if (editedImage != null && mounted) {
          _handleEditedPhoto(editedImage);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile aprire la fotocamera'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }

  /// Handle the edited photo from PhotoEditorScreen
  Future<void> _handleEditedPhoto(File editedImage) async {
    final maxViews = await _showViewCountPicker();
    if (maxViews != null) {
      await _uploadMedia(editedImage.path, ChatMediaType.image, maxViews: maxViews);
    }
  }

  /// Open gallery to pick an image
  Future<void> _openGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (image != null && mounted) {
        _handleSelectedMedia(image);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile aprire la galleria'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }

  /// Handle selected media file
  Future<void> _handleSelectedMedia(XFile file) async {
    final maxViews = await _showViewCountPicker();
    if (maxViews != null) {
      await _uploadMedia(file.path, ChatMediaType.image, maxViews: maxViews);
    }
  }

  /// Show bottom sheet to select how many times the photo can be viewed
  Future<int?> _showViewCountPicker() async {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: NovaColors.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(NovaSpacing.l),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: NovaColors.border(sheetContext),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: NovaSpacing.l),

              // Title
              Text(
                'Quante visualizzazioni?',
                style: NovaTypography.headingSmall.copyWith(
                  color: NovaColors.textPrimary(sheetContext),
                ),
              ),
              SizedBox(height: NovaSpacing.xs),
              Text(
                'Scegli quante volte può essere vista la foto',
                style: NovaTypography.bodySmall.copyWith(
                  color: NovaColors.textSecondary(sheetContext),
                ),
              ),
              SizedBox(height: NovaSpacing.l),

              // Options
              Row(
                children: [
                  // 1x option
                  Expanded(
                    child: _buildViewCountOption(
                      sheetContext,
                      count: 1,
                      icon: Icons.visibility,
                      label: '1 volta',
                      subtitle: 'Scompare dopo la prima visualizzazione',
                    ),
                  ),
                  SizedBox(width: NovaSpacing.m),
                  // 2x option
                  Expanded(
                    child: _buildViewCountOption(
                      sheetContext,
                      count: 2,
                      icon: Icons.replay,
                      label: '2 volte',
                      subtitle: 'Può essere rivista una volta',
                    ),
                  ),
                ],
              ),
              SizedBox(height: NovaSpacing.m),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewCountOption(
    BuildContext context, {
    required int count,
    required IconData icon,
    required String label,
    required String subtitle,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, count),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(NovaSpacing.m),
        decoration: BoxDecoration(
          color: NovaColors.card(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: NovaColors.border(context),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: NovaColors.primary(context).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: NovaColors.primary(context),
                size: 28,
              ),
            ),
            SizedBox(height: NovaSpacing.s),
            Text(
              label,
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.textPrimary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: NovaSpacing.xxs),
            Text(
              subtitle,
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.textSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Voice Recording Methods
  // =========================================================================

  /// Start recording voice message
  Future<void> _startRecording() async {
    try {
      // Check microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Permesso microfono necessario'),
              backgroundColor: NovaColors.error(context),
            ),
          );
        }
        return;
      }

      if (!_recorderInitialized) {
        await _initRecorder();
      }

      // Get temp directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${tempDir.path}/voice_$timestamp.aac';

      // Start recording
      await _audioRecorder.startRecorder(
        toFile: _recordingPath,
        codec: Codec.aacADTS,
      );

      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      // Start duration timer
      _updateRecordingDuration();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossibile avviare la registrazione'),
            backgroundColor: NovaColors.error(context),
          ),
        );
      }
    }
  }

  /// Update recording duration every second
  void _updateRecordingDuration() async {
    while (_isRecording && mounted) {
      await Future.delayed(const Duration(seconds: 1));
      if (_isRecording && mounted) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      }
    }
  }

  /// Stop recording and handle the audio file
  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stopRecorder();

      setState(() {
        _isRecording = false;
      });

      if (path != null && mounted) {
        // Only send if recording is at least 1 second
        if (_recordingDuration.inSeconds >= 1) {
          _handleVoiceMessage(File(path));
        } else {
          // Delete short recording
          final file = File(path);
          if (await file.exists()) {
            await file.delete();
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Registrazione troppo breve'),
                backgroundColor: NovaColors.warning(context),
              ),
            );
          }
        }
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
      });
    }
  }

  /// Cancel recording without sending
  Future<void> _cancelRecording() async {
    if (!_isRecording) return;

    try {
      final path = await _audioRecorder.stopRecorder();

      setState(() {
        _isRecording = false;
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
      });
    }
  }

  /// Handle recorded voice message
  Future<void> _handleVoiceMessage(File audioFile) async {
    // Voice messages always have 1 view (no picker needed)
    await _uploadMedia(audioFile.path, ChatMediaType.audio, maxViews: 1);
  }

  // =========================================================================
  // Media Upload
  // =========================================================================

  /// Upload media to chat (image, video, or audio)
  ///
  /// [maxViews] determines how many times the media can be viewed (1 or 2).
  Future<void> _uploadMedia(String filePath, ChatMediaType mediaType, {int maxViews = 1}) async {
    try {
      await ref.read(uploadMediaProvider((
        filePath: filePath,
        mediaType: mediaType,
        maxViews: maxViews,
      )).future);

      // Invalidate messages stream to refresh with new media
      ref.invalidate(chatMessagesStreamProvider);

      // Notify parent that something was sent
      widget.onSent?.call();
    } on ChatMediaLimitException catch (e) {
      // Show limit error as snackbar (this is important feedback)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: NovaColors.warning(context),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      // Debug: log the actual error
      print('=== MEDIA UPLOAD ERROR ===');
      print('Error: $e');
      print('Stack: $stackTrace');
      print('==========================');

      // TODO: Mark the message as failed with red X indicator
      // For now, show error snackbar only for upload failures
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Errore durante l\'invio. Riprova.'),
            backgroundColor: NovaColors.error(context),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Format duration as mm:ss
  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// Build recording UI widget
  Widget _buildRecordingUI() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: NovaSpacing.s,
        vertical: NovaSpacing.s,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: NovaSpacing.m,
          vertical: NovaSpacing.s,
        ),
        decoration: BoxDecoration(
          color: NovaColors.error(context).withOpacity(0.1),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: NovaColors.error(context).withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Cancel button
            GestureDetector(
              onTap: _cancelRecording,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: NovaColors.card(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  color: NovaColors.textSecondary(context),
                  size: 20,
                ),
              ),
            ),

            SizedBox(width: NovaSpacing.m),

            // Recording indicator
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: NovaColors.error(context),
                shape: BoxShape.circle,
              ),
            ),

            SizedBox(width: NovaSpacing.s),

            // Duration
            Text(
              _formatDuration(_recordingDuration),
              style: NovaTypography.bodyMedium.copyWith(
                color: NovaColors.error(context),
                fontWeight: FontWeight.w600,
              ),
            ),

            Spacer(),

            // Recording message
            Text(
              'Registrando...',
              style: NovaTypography.bodySmall.copyWith(
                color: NovaColors.textSecondary(context),
              ),
            ),

            SizedBox(width: NovaSpacing.m),

            // Stop/Send button
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: NovaColors.primary(context),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send,
                  color: Colors.white,
                  size: 18,
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
                color: NovaColors.error(context).withOpacity(0.1),
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
                          color: Colors.white,
                          size: 22,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),

                    SizedBox(width: NovaSpacing.s),

                    // Text input field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: NovaColors.card(context),
                          borderRadius: BorderRadius.circular(22),
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
                                    horizontal: NovaSpacing.m,
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
                      // Microphone - hold to record
                      GestureDetector(
                        onLongPressStart: (_) => _startRecording(),
                        onLongPressEnd: (_) => _stopRecording(),
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
                          child: Icon(
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
          ],
        ),
      ),
    );
  }
}
