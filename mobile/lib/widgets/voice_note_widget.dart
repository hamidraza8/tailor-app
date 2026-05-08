import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/constants.dart';

/// Widget for recording a voice note during order creation.
class VoiceNoteRecorder extends StatefulWidget {
  final String? recordingPath;
  final ValueChanged<String> onRecorded;

  const VoiceNoteRecorder({
    super.key,
    this.recordingPath,
    required this.onRecorded,
  });

  @override
  State<VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

class _VoiceNoteRecorderState extends State<VoiceNoteRecorder> {
  final _recorder = FlutterSoundRecorder();
  final _player = AudioPlayer();
  bool _recorderReady = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _path;
  Duration _duration = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _path = widget.recordingPath;
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_recorderReady) _recorder.closeRecorder();
    _player.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission required')),
        );
      }
      return;
    }

    if (!_recorderReady) {
      await _recorder.openRecorder();
      _recorderReady = true;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_note_${DateTime.now().millisecondsSinceEpoch}.aac';

    await _recorder.startRecorder(toFile: path, codec: Codec.aacADTS);
    setState(() {
      _isRecording = true;
      _duration = Duration.zero;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _duration += const Duration(seconds: 1));
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final path = await _recorder.stopRecorder();
    if (path != null) {
      setState(() {
        _isRecording = false;
        _path = path;
      });
      widget.onRecorded(path);
    }
  }

  Future<void> _play() async {
    if (_path == null) return;
    if (_path!.startsWith('http')) {
      await _player.play(UrlSource(_path!));
    } else {
      await _player.play(DeviceFileSource(_path!));
    }
    setState(() => _isPlaying = true);
  }

  Future<void> _stop() async {
    await _player.stop();
    setState(() => _isPlaying = false);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    // Has recording
    if (_path != null && !_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: _isPlaying ? _stop : _play,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Voice Note',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text(
                    _isPlaying ? 'Playing...' : 'Tap to play',
                    style: const TextStyle(color: AppColors.textMedium, fontSize: 11),
                  ),
                ],
              ),
            ),
            // Re-record
            GestureDetector(
              onTap: () {
                setState(() => _path = null);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.refresh, color: AppColors.error, size: 18),
              ),
            ),
          ],
        ),
      );
    }

    // Recording state
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text('Recording ${_formatDuration(_duration)}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.error)),
            const Spacer(),
            GestureDetector(
              onTap: _stopRecording,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Stop',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      );
    }

    // Empty state — tap to record
    return GestureDetector(
      onTap: _startRecording,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic, color: AppColors.primary.withOpacity(0.6), size: 24),
            const SizedBox(width: 8),
            Text(
              'Tap to record voice note',
              style: TextStyle(
                color: AppColors.primary.withOpacity(0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact voice note player for order detail / list views.
class VoiceNotePlayer extends StatefulWidget {
  final String url;

  const VoiceNotePlayer({super.key, required this.url});

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final _player = AudioPlayer();
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _isPlaying = false);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_isPlaying) {
      await _player.stop();
      setState(() => _isPlaying = false);
    } else {
      if (widget.url.startsWith('http')) {
        await _player.play(UrlSource(widget.url));
      } else {
        await _player.play(DeviceFileSource(widget.url));
      }
      setState(() => _isPlaying = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPlaying ? Icons.stop_circle : Icons.play_circle_filled,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: 6),
            Text(
              _isPlaying ? 'Playing...' : 'Voice Note',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
