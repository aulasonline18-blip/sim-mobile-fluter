import '../state/student_learning_state.dart';
import 'audio_core.dart';

class LessonMediaPosition {
  const LessonMediaPosition({
    required this.lessonLocalId,
    this.itemMarker,
    this.layer,
  });

  final String lessonLocalId;
  final String? itemMarker;
  final LessonLayer? layer;
}

class StudentLessonMediaService {
  StudentLessonMediaService({
    required this.audioCore,
    required this.readState,
    required this.writeState,
  });

  final AudioCore audioCore;
  final StudentLearningState Function(String lessonLocalId) readState;
  final StudentLearningState Function(StudentLearningState state) writeState;

  void prepareLessonAudioText(
    LessonMediaPosition position,
    List<String?> parts,
  ) {
    final text =
        parts.whereType<String>().where((p) => p.isNotEmpty).join('. ');
    if (text.isEmpty) return;
    audioCore.prepareText(text);
    _appendMediaEvent(position, 'AUDIO_READY', {
      'phase': 'ready',
      'source': 'tts-prepare',
      'hasAudioText': true,
    });
  }

  void markLessonAudioStarted(LessonMediaPosition position) {
    _appendMediaEvent(position, 'AUDIO_STARTED', {
      'phase': 'started',
      'source': 'tts-playback',
    });
  }

  void stopLessonAudio() {
    audioCore.stop();
  }

  Future<bool> playLessonAudioSequence(
    LessonMediaPosition position,
    List<String?> parts, {
    String? lang,
    String voice = 'Charon',
    void Function()? onEnd,
    void Function()? onStart,
  }) {
    final sequence = parts
        .whereType<String>()
        .where((part) => part.trim().isNotEmpty)
        .toList(growable: false);
    if (sequence.isEmpty) return Future.value(false);
    markLessonAudioStarted(position);
    return audioCore.speakSequence(
      sequence,
      SpeakOptions(
        lessonKey: [
          position.lessonLocalId,
          position.itemMarker ?? 'no-marker',
          position.layer?.value ?? 'L?',
        ].join(':'),
        lang: lang,
        voice: voice,
        onStart: onStart,
        onEnd: onEnd,
      ),
    );
  }

  void markLessonImageReady(
    LessonMediaPosition position, {
    String? cacheKey,
    String? imageUrl,
  }) {
    _appendMediaEvent(position, 'IMAGE_READY', {
      'phase': 'ready',
      'cacheKey': cacheKey,
      'imageUrlHead':
          imageUrl?.substring(0, imageUrl.length < 40 ? imageUrl.length : 40),
    });
  }

  void markLessonImageStarted(
    LessonMediaPosition position, {
    String? cacheKey,
  }) {
    _appendMediaEvent(position, 'IMAGE_STARTED', {
      'phase': 'started',
      'cacheKey': cacheKey,
    });
  }

  void markLessonImageFailed(
    LessonMediaPosition position, {
    String? error,
  }) {
    _appendMediaEvent(position, 'IMAGE_FAILED', {
      'phase': 'failed',
      'errorMessage': error,
    });
  }

  void _appendMediaEvent(
    LessonMediaPosition position,
    String type,
    JsonMap payload,
  ) {
    final state = readState(position.lessonLocalId);
    writeState(
      state.copyWith(
        events: [
          ...state.events,
          StudentLearningEvent(
            type: type,
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: {
              ...payload,
              'itemMarker': position.itemMarker,
              'layer': position.layer?.value,
            },
          ),
        ],
      ),
    );
  }
}
