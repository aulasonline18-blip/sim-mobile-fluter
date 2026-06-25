import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'audio_core.dart';

class AudioplayersPlaybackAdapter implements AudioPlaybackAdapter {
  AudioplayersPlaybackAdapter({AudioPlayer? player})
      : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  StreamSubscription<void>? _completeSub;

  @override
  bool playDataUrl(String dataUrl, SpeakOptions opts) {
    final bytes = _decodeDataUrl(dataUrl);
    if (bytes == null || bytes.isEmpty) return false;
    unawaited(_completeSub?.cancel());
    _completeSub = _player.onPlayerComplete.listen((_) => opts.onEnd?.call());
    unawaited(_player.stop());
    unawaited(
      _player.play(BytesSource(bytes)).then((_) {
        opts.onStart?.call();
      }).catchError((_) {
        opts.onEnd?.call();
      }),
    );
    return true;
  }

  @override
  bool speakWithPlatformTts(String text, SpeakOptions opts) {
    opts.onEnd?.call();
    return false;
  }

  @override
  void stop() {
    unawaited(_player.stop());
  }

  Future<void> dispose() async {
    await _completeSub?.cancel();
    await _player.dispose();
  }
}

Uint8List? _decodeDataUrl(String dataUrl) {
  final comma = dataUrl.indexOf(',');
  if (!dataUrl.startsWith('data:') || comma < 0) return null;
  final meta = dataUrl.substring(0, comma).toLowerCase();
  if (!meta.contains(';base64')) return null;
  try {
    return base64Decode(dataUrl.substring(comma + 1));
  } catch (_) {
    return null;
  }
}
