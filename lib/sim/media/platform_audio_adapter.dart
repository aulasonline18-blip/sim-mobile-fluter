import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'audio_core.dart';

/// Real audio adapter — plays WAV data URLs from the TTS endpoint.
/// Mirrors Web behaviour: single currentAudio instance, overwritten on each new speak().
class PlatformAudioAdapter implements AudioPlaybackAdapter {
  PlatformAudioAdapter() {
    _player.onPlayerComplete.listen((_) {
      _onEnd?.call();
      _onEnd = null;
    });
  }

  final AudioPlayer _player = AudioPlayer();
  void Function()? _onEnd;

  @override
  bool playDataUrl(String dataUrl, SpeakOptions opts) {
    final bytes = _extractWavBytes(dataUrl);
    if (bytes == null) return false;
    _stop();
    _onEnd = opts.onEnd;
    opts.onStart?.call();
    unawaited(_player.play(BytesSource(bytes)));
    return true;
  }

  @override
  bool speakWithPlatformTts(String text, SpeakOptions opts) {
    // Platform TTS not available — onEnd must still fire so the caller doesn't hang.
    opts.onStart?.call();
    opts.onEnd?.call();
    return false;
  }

  @override
  void stop() => _stop();

  void _stop() {
    _onEnd = null;
    unawaited(_player.stop());
  }

  /// Decodes `data:audio/wav;base64,<payload>` → raw bytes.
  Uint8List? _extractWavBytes(String dataUrl) {
    try {
      final comma = dataUrl.indexOf(',');
      if (comma < 0) return null;
      final payload = dataUrl.substring(comma + 1);
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _player.dispose();
  }
}
