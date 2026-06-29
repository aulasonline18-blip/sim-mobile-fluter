// MIRROR OF: src/cyber/lesson-orchestrator.ts (Web, source of truth)
import '../media/math_templates/math_templates.dart';
import '../media/s12_visual_pipeline.dart';
import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import 'lesson_event_bus.dart';
import 'lesson_material_cache.dart';
import 'lesson_models.dart';
import 'lesson_pipeline_runtime.dart';

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
  final ImageSequentialQueue _imageQueue = ImageSequentialQueue();
  final BackgroundTextSemaphore _bgText = BackgroundTextSemaphore();

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

    // Part III.4: route by priority — active runs immediately, background goes through semaphore
    Future<CompleteLesson> fetchFn() => _fetchText(params);
    final queued = priority == 'active' ? fetchFn() : _bgText.run(fetchFn);

    final future = queued
        .then((lesson) {
          cache.put(key, lesson);
          bus.notify(key, lesson);
          if (_textInflight[key] != null) _textInflight.remove(key);
          // Part III.6: dispatch image sequentially in background
          _imageQueue.run(() => _fetchImage(params, lesson));
          return lesson;
        })
        .catchError((Object error) {
          if (_textInflight[key] != null) _textInflight.remove(key);
          throw error;
        });
    _textInflight[key] = future;
    return future;
  }

  // D2.1: image pipeline — SVG math templates (free) + S12 software route.
  // Paid AI images handled by PaidImageService after offer accepted.
  Future<void> _fetchImage(
    CompleteLessonParams params,
    CompleteLesson lesson,
  ) async {
    final key = lessonKeyFor(params);
    final vt = lesson.conteudo.visualTrigger;

    // Caminho 1: math template (SVG puro, custo zero)
    final mathSvg = tryRenderMathTemplate(vt);
    if (mathSvg != null) {
      final updated = CompleteLesson(
        conteudo: lesson.conteudo,
        imagem: mathSvg,
        audioText: lesson.audioText,
      );
      cache.put(key, updated);
      bus.notify(key, updated);
      return;
    }

    // Caminho 2: S12 software route (SVG inline, custo zero)
    final decision = decideVisualGeneration(
      vt != null ? Map<String, dynamic>.from(vt) : null,
      const VisualDecisionContext(allowPaidImages: false),
    );
    if (decision.svg != null) {
      final updated = CompleteLesson(
        conteudo: lesson.conteudo,
        imagem: decision.svg,
        audioText: lesson.audioText,
      );
      cache.put(key, updated);
      bus.notify(key, updated);
    }
    // Se decision.generate == true e allowPaidImages==false → PaidImageService
    // emite oferta separada. Orchestrator não cobra crédito aqui.
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
        amparoLvl: params.amparoLvl,
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
    'for_layer': layer.name,
  };
}
