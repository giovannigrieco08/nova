import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_radius.dart';
import 'package:nova/core/theme/nova_spacing.dart';

/// Callback when a voice recording is completed.
typedef OnVoiceRecordingComplete = void Function(
    File audioFile, int durationSeconds);

/// Self-contained voice recorder widget with WhatsApp-style waveform UI.
///
/// Manages its own [FlutterSoundRecorder] lifecycle, permissions, timer,
/// and waveform animation. Reports the final audio file via [onComplete].
class ComposeVoiceRecorder extends StatefulWidget {
  final OnVoiceRecordingComplete onComplete;
  final VoidCallback onCancel;

  /// Called to show toast messages in the parent.
  final void Function(String message, {bool isError, bool isWarning}) showToast;

  const ComposeVoiceRecorder({
    super.key,
    required this.onComplete,
    required this.onCancel,
    required this.showToast,
  });

  @override
  State<ComposeVoiceRecorder> createState() => ComposeVoiceRecorderState();
}

class ComposeVoiceRecorderState extends State<ComposeVoiceRecorder> {
  final FlutterSoundRecorder _audioRecorder = FlutterSoundRecorder();
  bool _recorderInitialized = false;

  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  String? _recordingPath;
  Timer? _durationTimer;

  List<double> _waveformLevels = List.filled(50, 0.2);

  bool get isRecording => _isRecording;

  @override
  void dispose() {
    _durationTimer?.cancel();
    _durationTimer = null;
    if (_recorderInitialized) {
      try {
        _audioRecorder.closeRecorder();
      } catch (_) {}
    }
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Public API (called by parent)
  // ---------------------------------------------------------------------------

  Future<void> startRecording() async {
    debugPrint('[VoiceRecorder] _startRecording called');
    try {
      debugPrint('[VoiceRecorder] Checking microphone permission...');
      var status = await Permission.microphone.status;
      debugPrint('[VoiceRecorder] Current permission status: $status');

      if (status.isDenied || status.isRestricted) {
        debugPrint('[VoiceRecorder] Requesting permission...');
        status = await Permission.microphone.request();
        debugPrint('[VoiceRecorder] After request status: $status');
      }

      if (!status.isGranted && !status.isLimited) {
        if (status.isPermanentlyDenied && mounted) {
          showCupertinoDialog(
            context: context,
            builder: (context) => CupertinoAlertDialog(
              title: const Text('Permesso microfono'),
              content: const Text(
                  'Per registrare messaggi vocali, abilita il microfono nelle Impostazioni.'),
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
          widget.showToast('Permesso microfono necessario', isError: true);
        }
        return;
      }

      debugPrint('[VoiceRecorder] Permission granted, proceeding...');

      if (!_recorderInitialized) {
        debugPrint('[VoiceRecorder] Initializing recorder...');
        final initialized = await _initRecorder();
        debugPrint('[VoiceRecorder] Recorder initialized: $initialized');
        if (!initialized) {
          widget.showToast('Impossibile inizializzare il registratore',
              isError: true);
          return;
        }
      }

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = Platform.isIOS ? 'm4a' : 'aac';
      _recordingPath = '${tempDir.path}/voice_$timestamp.$extension';
      debugPrint('[VoiceRecorder] Recording path: $_recordingPath');

      debugPrint(
          '[VoiceRecorder] Starting recorder with codec: ${Platform.isIOS ? "aacMP4" : "aacADTS"}');
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

      _durationTimer?.cancel();
      final random = Random();
      _durationTimer =
          Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (_isRecording && !_isPaused && mounted) {
          setState(() {
            if (timer.tick % 10 == 0) {
              _recordingDuration += const Duration(seconds: 1);
            }
            _waveformLevels =
                List.generate(50, (_) => 0.2 + random.nextDouble() * 0.8);
          });
        } else if (!_isRecording) {
          timer.cancel();
        }
      });
    } catch (e, stackTrace) {
      debugPrint('[VoiceRecorder] ERROR in _startRecording: $e');
      debugPrint('[VoiceRecorder] Stack trace: $stackTrace');
      widget.showToast('Impossibile avviare la registrazione', isError: true);
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    _durationTimer?.cancel();
    _durationTimer = null;

    try {
      final path = await _audioRecorder.stopRecorder();

      setState(() {
        _isRecording = false;
        _isPaused = false;
      });

      if (path != null && mounted) {
        if (_recordingDuration.inSeconds >= 1) {
          widget.onComplete(File(path), _recordingDuration.inSeconds);
        } else {
          final file = File(path);
          if (await file.exists()) await file.delete();
          widget.showToast('Registrazione troppo breve', isWarning: true);
        }
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
    }
  }

  Future<void> cancelRecording() async {
    if (!_isRecording) return;

    _durationTimer?.cancel();
    _durationTimer = null;

    try {
      final path = await _audioRecorder.stopRecorder();

      setState(() {
        _isRecording = false;
        _isPaused = false;
      });

      if (path != null) {
        final file = File(path);
        if (await file.exists()) await file.delete();
      }
    } catch (e) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
      });
    }

    widget.onCancel();
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

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

  Future<void> _togglePauseRecording() async {
    if (!_isRecording) return;
    try {
      if (_isPaused) {
        await _audioRecorder.resumeRecorder();
        setState(() => _isPaused = false);
      } else {
        await _audioRecorder.pauseRecorder();
        setState(() => _isPaused = true);
      }
    } catch (_) {}
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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
            // 1. Trash/Delete button
            GestureDetector(
              onTap: cancelRecording,
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

            // 2. Timer + Waveform
            Expanded(
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    Text(
                      _formatDuration(_recordingDuration),
                      style: TextStyle(
                        color: NovaColors.textPrimary(context),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
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

            // 3. Pause/Resume button
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

            // 4. Send button
            GestureDetector(
              onTap: stopRecording,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: NovaColors.primary(context),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
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
}
