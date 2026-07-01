import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'audio_core.dart';

/// Real audio adapter — plays WAV data URLs from the TTS endpoint.
/// Mirrors Web behaviour: single currentAudio instance, overwritten on each new speak().
class PlatformAudioAdapter implements AudioPlaybackAdapter {
  AudioPlayer? _player;
  StreamSubscription<void>? _completeSubscription;
  void Function()? _onEnd;

  AudioPlayer get _activePlayer {
    final existing = _player;
    if (existing != null) return existing;
    final created = AudioPlayer();
    _completeSubscription = created.onPlayerComplete.listen((_) {
      _onEnd?.call();
      _onEnd = null;
    });
    _player = created;
    return created;
  }

  @override
  bool playDataUrl(String dataUrl, SpeakOptions opts) {
    final bytes = _extractWavBytes(dataUrl);
    if (bytes == null) return false;
    _stop();
    _onEnd = opts.onEnd;
    opts.onStart?.call();
    unawaited(_activePlayer.play(BytesSource(bytes)));
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
    final player = _player;
    if (player != null) {
      unawaited(player.stop());
    }
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
    unawaited(_completeSubscription?.cancel());
    _player?.dispose();
  }
}
