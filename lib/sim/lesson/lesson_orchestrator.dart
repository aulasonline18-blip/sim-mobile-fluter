import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import 'lesson_event_bus.dart';
import 'lesson_material_cache.dart';
import 'lesson_models.dart';

class LessonOrchestrator {
  LessonOrchestrator({
    required this.t02Client,
    required this.cache,
    required this.bus,
  });

  final T02LessonClient t02Client;
  final LessonMaterialCache cache;
  final LessonEventBus bus;
  final Map<String, Future<CompleteLesson>> _textInflight = {};

  bool get isLessonBusy => _textInflight.isNotEmpty;

  CompleteLesson? peekCachedLesson(String key) => cache.peek(key);

  Future<CompleteLesson> prefetchCompleteLesson(
    CompleteLessonParams params, {
    String priority = 'background',
    bool forceRefresh = false,
  }) {
    final key = lessonKeyFor(params);
    final ready = cache.peek(key);
    if (ready != null && !forceRefresh) {
      return Future.value(ready);
    }
    final existing = _textInflight[key];
    if (existing != null && !forceRefresh) return existing;

    final future = _fetchText(params).then((lesson) {
      cache.put(key, lesson);
      bus.notify(key, lesson);
      if (_textInflight[key] != null) _textInflight.remove(key);
      return lesson;
    }).catchError((Object error) {
      if (_textInflight[key] != null) _textInflight.remove(key);
      throw error;
    });
    _textInflight[key] = future;
    return future;
  }

  Future<CompleteLesson> _fetchText(CompleteLessonParams params) async {
    final material = await t02Client.completeLesson(
      T02LessonRequest(
        lessonLocalId: params.lessonLocalId,
        item: params.item,
        lang: params.lang,
        academic: params.academic,
        layer: params.layer,
        mode: params.mode.name,
        errCount: params.errCount,
        history: params.history,
        marker: params.marker,
        profile: params.pedagogicalEnvelope,
      ),
    );
    final conteudo = LessonContent(
      explanation: material.explanation,
      question: material.question,
      options: material.options,
      correctAnswer: material.correctAnswer,
      whyCorrect: material.whyCorrect,
      whyWrong: material.whyWrong,
    );
    return CompleteLesson(
      conteudo: conteudo,
      imagem: null,
      audioText: conteudo.audioText,
    );
  }

  CompleteLesson seedCompleteLesson(
    CompleteLessonParams params,
    LessonContent conteudo,
  ) {
    final key = lessonKeyFor(params);
    final lesson = CompleteLesson(
      conteudo: conteudo,
      imagem: null,
      audioText: conteudo.audioText,
    );
    cache.put(key, lesson);
    bus.notify(key, lesson);
    return lesson;
  }
}

JsonMap preparedMaterialFromLesson({
  required CompleteLesson lesson,
  required int itemIdx,
  required String? marker,
  required LessonLayer layer,
}) {
  return {
    'text_status': 'ready',
    ...lesson.conteudo.toJson(),
    'generated_at': DateTime.now().toIso8601String(),
    'model': 'T02_content',
    'prompt_contract_version': 'T02_content.v3',
    'for_itemIdx': itemIdx,
    'for_marker': marker,
    'for_layer': layer.value,
  };
}
