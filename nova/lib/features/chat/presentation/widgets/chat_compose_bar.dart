import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_typography.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/presentation/providers/chat_providers.dart';
import 'package:nova/features/chat/presentation/widgets/chat_reply_preview.dart';
import 'package:nova/features/safety/presentation/providers/content_filter_provider.dart';
import 'package:nova/features/safety/presentation/widgets/content_warning_banner.dart';

import 'compose_emoji_picker.dart';
import 'compose_media_handler.dart';
import 'compose_text_input.dart';
import 'compose_voice_recorder.dart';

/// Compose bar for sending chat messages.
///
/// Features:
/// - Text input with character counter (max 500)
/// - Reply preview with dismiss
/// - Send button with loading state
/// - @mention detection and autocomplete trigger
/// - Voice recording (WhatsApp-style)
/// - Camera + gallery media sending
/// - Emoji picker
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

  final GlobalKey<ComposeVoiceRecorderState> _recorderKey = GlobalKey();
  bool _isRecording = false;
  bool _showEmojiPicker = false;

  late final ComposeMediaHandler _mediaHandler;

  @override
  void initState() {
    super.initState();
    _mediaHandler = ComposeMediaHandler(
      context: () => context,
      ref: ref,
      showToast: _showToast,
      onSent: widget.onSent,
      isMounted: () => mounted,
    );
    _mediaHandler.preRequestPhotoPermissions();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Toast
  // ---------------------------------------------------------------------------

  void _showToast(String message,
      {bool isError = false, bool isWarning = false}) {
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

  // ---------------------------------------------------------------------------
  // Voice recording callbacks
  // ---------------------------------------------------------------------------

  void _onVoiceRecordingComplete(File audioFile, int durationSeconds) {
    setState(() => _isRecording = false);
    _mediaHandler.uploadMedia(
      audioFile.path,
      ChatMediaType.audio,
      maxViews: 1,
      durationSeconds: durationSeconds,
    );
  }

  void _onVoiceRecordingCancel() {
    setState(() => _isRecording = false);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(composeStateProvider);
    final contentCheckState = ref.watch(contentCheckNotifierProvider);

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

            // UGC Safety: Content warning banner (T075)
            if (contentCheckState.isBlocked || contentCheckState.hasWarnings)
              const ContentWarningBanner(compact: false),

            // Error message
            if (state.error != null) _buildErrorBanner(state.error!),

            // Main input area: recording UI or text input
            if (_isRecording)
              ComposeVoiceRecorder(
                key: _recorderKey,
                onComplete: _onVoiceRecordingComplete,
                onCancel: _onVoiceRecordingCancel,
                showToast: _showToast,
              )
            else
              ComposeTextInput(
                controller: _controller,
                focusNode: _focusNode,
                showEmojiPicker: _showEmojiPicker,
                onToggleEmojiPicker: () =>
                    setState(() => _showEmojiPicker = false),
                onSent: widget.onSent,
                trailing: [
                  SizedBox(width: NovaSpacing.s),
                  // Camera button
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
                      onPressed: _mediaHandler.openCamera,
                      icon: const Icon(
                        Icons.camera_alt,
                        color: NovaColors.onPrimaryLight,
                        size: 22,
                      ),
                      padding: EdgeInsets.zero,
                      tooltip: 'Fotocamera',
                    ),
                  ),
                  SizedBox(width: NovaSpacing.xs),
                  // Microphone
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      debugPrint(
                          '[VoiceRecorder] Microphone button TAPPED!');
                      setState(() => _isRecording = true);
                      // Start recording after the recorder widget is built
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _recorderKey.currentState?.startRecording();
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.mic_none,
                        color: NovaColors.textSecondary(context),
                        size: 26,
                      ),
                    ),
                  ),
                  // Gallery
                  GestureDetector(
                    onTap: () =>
                        _mediaHandler.openGallery(setState),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 2, right: 4),
                      child: _mediaHandler.isOpeningGallery
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
              ),

            // Emoji picker
            if (_showEmojiPicker)
              ComposeEmojiPicker(controller: _controller),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Error banner
  // ---------------------------------------------------------------------------

  Widget _buildErrorBanner(String error) {
    return Container(
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
              error,
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
    );
  }
}
