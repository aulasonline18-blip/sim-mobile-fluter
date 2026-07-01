// MIRROR OF: src/cyber/lesson-orchestrator.ts (Web, source of truth)
import '../media/lesson_visual_pipeline.dart';
import '../media/lesson_paid_image_offer.dart';
import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import 'lesson_event_bus.dart';
import 'lesson_material_cache.dart';
import 'lesson_models.dart';
import 'lesson_pipeline_runtime.dart';

class LessonOrchestrator implements LessonPaidImageOrchestrator {
  LessonOrchestrator({
    required this.t02Client,
    required this.cache,
    required this.bus,
    required this._visualPipeline,
    this.onAudioTextReady,
  });

  final T02LessonClient t02Client;
  final LessonMaterialCache cache;
  final LessonEventBus bus;
  final LessonVisualPipeline _visualPipeline;
  void Function(CompleteLessonParams params, CompleteLesson lesson)?
  onAudioTextReady;
  final Map<String, Future<CompleteLesson>> _textInflight = {};
  final Map<String, _PaidPending> _paidPending = {};
  final Map<String, Future<String?>> _paidInflight = {};
  final Set<String> _declinedKeys = {};
  final ImageSequentialQueue _imageQueue = ImageSequentialQueue();
  final BackgroundTextSemaphore _bgText = BackgroundTextSemaphore();
  Future<void> _lastLessonFullyComplete = Future.value();

  bool get isLessonBusy => _textInflight.isNotEmpty;

  CompleteLesson? peekCachedLesson(String key) => cache.peek(key);

  void setAudioTextPreparer(
    void Function(CompleteLessonParams params, CompleteLesson lesson)? preparer,
  ) {
    onAudioTextReady = preparer;
  }

  Future<CompleteLesson> prefetchCompleteLesson(
    CompleteLessonParams params, {
    String priority = 'background',
    bool forceRefresh = false,
  }) {
    final key = lessonKeyFor(params);
    final ready = cache.peek(key);
    if (ready != null && !forceRefresh) {
      onAudioTextReady?.call(params, ready);
      return Future.value(ready);
    }
    final existing = _textInflight[key];
    if (existing != null && !forceRefresh) return existing;

    Future<CompleteLesson> fetchFn() => _fetchText(params);
    final queued = priority == 'active'
        ? fetchFn()
        : _bgText.run(() async {
            final gate = _lastLessonFullyComplete;
            await gate;
            return fetchFn();
          });

    final future = queued
        .then((lesson) {
          cache.put(key, lesson);
          bus.notify(key, lesson);
          onAudioTextReady?.call(params, lesson);
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
    _lastLessonFullyComplete = future.then((_) {}).catchError((_) {});
    return future;
  }

  void resetLessonSequentialGate() {
    _lastLessonFullyComplete = Future.value();
  }

  // D2.1: image pipeline — central funnel: software first, paid offer only.
  Future<void> _fetchImage(
    CompleteLessonParams params,
    CompleteLesson lesson,
  ) async {
    final key = lessonKeyFor(params);
    final vt = lesson.conteudo.visualTrigger;
    final trigger = LessonVisualTrigger.fromJson(vt);
    if (!trigger.needsImage || trigger.pedagogicalNeed == 'none') {
      return;
    }

    final result = await _visualPipeline.resolveVisual(
      trigger: trigger,
      lessonKey: key,
      stableLang: params.lang,
      allowPaidImages: true,
      acceptedOfferId: null,
    );
    if (result.hasImage) {
      _publishImage(key, lesson, result.displayUrl!);
      return;
    }
    if (result.source == 'skip_no_paid' || result.source == 'skip_no_offer') {
      _publishPaidImageOffer(
        key: key,
        params: params,
        trigger: trigger,
        source: result.source,
      );
    }
  }

  void _publishImage(String key, CompleteLesson lesson, String imageData) {
    final updated = CompleteLesson(
      conteudo: lesson.conteudo,
      imagem: imageData,
      audioText: lesson.audioText,
    );
    cache.put(key, updated);
    bus.clearPaidImageOffer(key);
    bus.notify(key, updated);
  }

  void _publishPaidImageOffer({
    required String key,
    required CompleteLessonParams params,
    required LessonVisualTrigger trigger,
    required String source,
  }) {
    if (_declinedKeys.contains(key) || _paidPending.containsKey(key)) return;
    final prompt = _visualPipeline.buildPromptForTrigger(
      topic: trigger.topic ?? params.item,
      trigger: trigger,
      lang: params.lang,
    );
    if (prompt.trim().isEmpty) return;
    final offerId = _stableOfferId(key, prompt);
    _paidPending[key] = _PaidPending(
      approvedPrompt: prompt,
      base:
          cache.peek(key) ??
          CompleteLesson(
            conteudo: LessonContent(
              explanation: '',
              question: '',
              options: const {
                AnswerLetter.A: '',
                AnswerLetter.B: '',
                AnswerLetter.C: '',
              },
              correctAnswer: AnswerLetter.A,
              visualTrigger: trigger.toVisualTriggerMap(),
            ),
            imagem: null,
            audioText: '',
          ),
      offerId: offerId,
    );
    bus.notifyPaidImageOffer(
      key,
      LessonPaidImageOffer(
        offerId: offerId,
        lessonKey: key,
        prompt: prompt,
        creditCost: 10,
        source: source,
      ),
    );
  }

  @override
  Future<void> acceptPaidImageOffer(String offerKey) async {
    final pending = _paidPending.remove(offerKey);
    if (pending == null) return;
    final existing = _paidInflight[offerKey];
    if (existing != null) {
      await existing;
      return;
    }
    final future = _imageQueue.run(() async {
      final image = await _visualPipeline.fetchPaidLessonImage(
        pending.approvedPrompt,
        offerKey,
        acceptedOfferId: pending.offerId,
        idempotencyKey: pending.offerId,
      );
      if (image != null && image.trim().isNotEmpty) {
        _publishImage(offerKey, pending.base, image);
      }
      return image;
    });
    _paidInflight[offerKey] = future;
    try {
      await future;
    } finally {
      _paidInflight.remove(offerKey);
    }
  }

  @override
  void declinePaidImageOffer(String offerKey) {
    _declinedKeys.add(offerKey);
    _paidPending.remove(offerKey);
    bus.clearPaidImageOffer(offerKey);
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
      visualTrigger: material.visualTrigger,
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
    onAudioTextReady?.call(params, lesson);
    return lesson;
  }
}

String _stableOfferId(String lessonKey, String prompt) {
  return 'img_offer_${_stableHash('$lessonKey|${prompt.trim()}')}';
}

String _stableHash(String input) {
  var hash = 5381;
  for (final unit in input.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return (hash & 0xffffffff).toRadixString(36);
}

class _PaidPending {
  const _PaidPending({
    required this.approvedPrompt,
    required this.base,
    required this.offerId,
  });

  final String approvedPrompt;
  final CompleteLesson base;
  final String offerId;
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
