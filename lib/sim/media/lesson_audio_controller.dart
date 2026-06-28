import 'package:flutter/foundation.dart';
import '../lesson/lesson_models.dart';
import '../state/student_learning_state.dart';
import 'audio_preference.dart';
import 'student_lesson_media_service.dart';

class LessonAudioController {
  LessonAudioController({
    required this.lessonLocalId,
    required this.mediaService,
    required this.preference,
  });

  final String lessonLocalId;
  final StudentLessonMediaService mediaService;
  final AudioPreference preference;

  /// Reactive speaking state — UI can listen via ValueListenableBuilder.
  final ValueNotifier<bool> falandoNotifier = ValueNotifier(false);

  bool get falando => falandoNotifier.value;
  set falando(bool v) => falandoNotifier.value = v;

  Future<bool> playConteudo(
    LessonContent? conteudo,
    String? itemMarker,
    LessonLayer layer, {
    String? language,
  }) async {
    if (conteudo == null) return false;
    if (!preference.getAudioEnabled()) return false;
    final parts = [
      conteudo.explanation,
      conteudo.question,
      if ((conteudo.options[AnswerLetter.A] ?? '').isNotEmpty)
        'A: ${conteudo.options[AnswerLetter.A]}',
      if ((conteudo.options[AnswerLetter.B] ?? '').isNotEmpty)
        'B: ${conteudo.options[AnswerLetter.B]}',
      if ((conteudo.options[AnswerLetter.C] ?? '').isNotEmpty)
        'C: ${conteudo.options[AnswerLetter.C]}',
    ];
    falando = false;
    final started = await mediaService.playLessonAudioSequence(
      LessonMediaPosition(
        lessonLocalId: lessonLocalId,
        itemMarker: itemMarker,
        layer: layer,
      ),
      parts,
      onStart: () => falando = true,
      onEnd: () => falando = false,
      language: language,
    );
    if (!started) falando = false;
    return started;
  }

  Future<void> ouvirAula(
    LessonContent? conteudo,
    String? itemMarker,
    LessonLayer layer, {
    String? language,
  }) async {
    if (falando) {
      pararAudio();
      return;
    }
    await playConteudo(conteudo, itemMarker, layer, language: language);
  }

  Future<bool> autoSpeakLesson(
    LessonContent? conteudo,
    String? itemMarker,
    LessonLayer layer, {
    String? language,
  }) {
    if (falando) return Future.value(false);
    return playConteudo(conteudo, itemMarker, layer, language: language);
  }

  void pararAudio() {
    mediaService.stopLessonAudio();
    falando = false;
  }
}
