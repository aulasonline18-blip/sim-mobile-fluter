// MIRROR OF: src/sim/lesson/studentLessonMaterialService.ts (Web, source of truth)
import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'dopamine_ready_window_engine.dart';
import 'lesson_models.dart';
import 'lesson_orchestrator.dart';

enum LessonMaterialSource {
  studentState,
  studentStateAfterWait,
  memoryCacheFromMotor,
}

class ResolveLessonMaterialInput {
  const ResolveLessonMaterialInput({
    required this.lessonLocalId,
    required this.topic,
    required this.itemIdx,
    required this.marker,
    required this.layer,
    required this.params,
    this.waitBeforeOrderMs = 2000,
    this.waitAfterOrderMs = 12000,
  });

  final String lessonLocalId;
  final String? topic;
  final int itemIdx;
  final String? marker;
  final LessonLayer layer;
  final CompleteLessonParams params;
  final int waitBeforeOrderMs;
  final int waitAfterOrderMs;
}

class ResolveLessonMaterialResult {
  const ResolveLessonMaterialResult({
    required this.conteudo,
    required this.imagem,
    required this.source,
    required this.waitedMs,
  });

  final LessonContent conteudo;
  final String? imagem;
  final LessonMaterialSource source;
  final int waitedMs;
}

class StudentLessonMaterialService {
  StudentLessonMaterialService({
    required this.stateService,
    required this.orchestrator,
    required this.readyWindowEngine,
  });

  final StudentLearningStateService stateService;
  final LessonOrchestrator orchestrator;
  final DopamineReadyWindowEngine readyWindowEngine;

  ResolveLessonMaterialResult? resolveFastLessonMaterialFromStateOrCache(
    ResolveLessonMaterialInput input,
  ) {
    final fromState = _readReadyFromStudentState(input);
    if (fromState != null) {
      return ResolveLessonMaterialResult(
        conteudo: fromState,
        imagem: null,
        source: LessonMaterialSource.studentState,
        waitedMs: 0,
      );
    }
    final cached = orchestrator.peekCachedLesson(lessonKeyFor(input.params));
    if (cached == null) return null;
    _mirrorCurrentLessonMaterial(input, cached);
    return ResolveLessonMaterialResult(
      conteudo: cached.conteudo,
      imagem: cached.imagem,
      source: LessonMaterialSource.memoryCacheFromMotor,
      waitedMs: 0,
    );
  }

  Future<ResolveLessonMaterialResult?> resolveLessonMaterialFromStateOrEngine(
    ResolveLessonMaterialInput input,
  ) async {
    final startedAt = DateTime.now().millisecondsSinceEpoch;
    final fast = resolveFastLessonMaterialFromStateOrCache(input);
    if (fast != null) return fast;

    _enqueueLearningJob(input);
    await readyWindowEngine.runDopamineReadyWindowFromStudentState(
      lessonLocalId: input.lessonLocalId,
      source: 'StudentLessonMaterialService',
      maxSlots: 1,
      itemIdx: input.itemIdx,
      layer: input.layer,
      marker: input.marker,
      topic: input.topic,
    );

    final after = resolveFastLessonMaterialFromStateOrCache(input);
    if (after == null) return null;
    final waitedMs = DateTime.now().millisecondsSinceEpoch - startedAt;
    _appendLessonTextReady(
      input,
      after.conteudo,
      LessonMaterialSource.studentStateAfterWait,
      waitedMs,
    );
    return ResolveLessonMaterialResult(
      conteudo: after.conteudo,
      imagem: after.imagem,
      source: LessonMaterialSource.studentStateAfterWait,
      waitedMs: waitedMs,
    );
  }

  void _appendLessonTextReady(
    ResolveLessonMaterialInput input,
    LessonContent content,
    LessonMaterialSource source,
    int waitedMs,
  ) {
    stateService.appendEvent(
      input.lessonLocalId,
      StudentLearningEvent(
        type: 'LESSON_TEXT_READY',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'lessonLocalId': input.lessonLocalId,
          'itemIdx': input.itemIdx,
          'marker': input.marker,
          'layer': input.layer.value,
          'mode': input.params.mode.name,
          'source': source.name,
          'waitedMs': waitedMs,
          'question': content.question,
        },
      ),
    );
  }

  void maintainLessonReadyWindow({
    required String lessonLocalId,
    required String? topic,
    required int itemIdx,
    required LessonLayer layer,
    required List<DopamineWindowItem> items,
    required String source,
    String priority = 'background',
    String? reason,
  }) {
    stateService.mutate(lessonLocalId, (state) {
      final jobs = [...state.queuedActions];
      jobs.add({
        'job_id': '${source}_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'PREPARE_READY_WINDOW',
        'status': 'queued',
        'idempotency_key': '$source:$lessonLocalId:$itemIdx:L${layer.value}',
        'priority': priority,
        'source': source,
        'payload': {
          'maxSlots': 3,
          'reason': reason ?? 'lesson_window_visible',
          'itemIdx': itemIdx,
          'layer': layer.value,
          'marker': items.length > itemIdx ? items[itemIdx].marker : null,
          'topic': topic,
        },
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'started_at': null,
        'finished_at': null,
        'error': null,
      });
      return state.copyWith(queuedActions: jobs);
    });
  }

  LessonContent? _readReadyFromStudentState(ResolveLessonMaterialInput input) {
    final state = stateService.read(input.lessonLocalId);
    final key = preparedLessonMaterialKey(
      input.itemIdx,
      input.marker,
      input.layer,
    );
    final material = state?.readyLessonMaterials[key];
    if (material == null || material['text_status'] != 'ready') return null;
    if (material['for_itemIdx'] != input.itemIdx) return null;
    if (material['for_layer'] != input.layer.name) return null;
    if ((material['for_marker'] as String?) != input.marker) return null;
    final options = material['options'];
    if (options is! Map) return null;
    final correct = AnswerLetter.values.firstWhere(
      (letter) => letter.name == material['correct_answer'],
      orElse: () => AnswerLetter.A,
    );
    return LessonContent(
      explanation: (material['explanation'] ?? '').toString(),
      question: (material['question'] ?? '').toString(),
      options: {
        AnswerLetter.A: (options['A'] ?? '').toString(),
        AnswerLetter.B: (options['B'] ?? '').toString(),
        AnswerLetter.C: (options['C'] ?? '').toString(),
      },
      correctAnswer: correct,
      whyCorrect: material['why_correct'] as String?,
      whyWrong: material['why_wrong'],
      visualTrigger: material['visual_trigger'] is Map
          ? JsonMap.from(material['visual_trigger'] as Map)
          : null,
    );
  }

  void _mirrorCurrentLessonMaterial(
    ResolveLessonMaterialInput input,
    CompleteLesson lesson,
  ) {
    stateService.mutate(input.lessonLocalId, (state) {
      return state.copyWith(
        currentLessonMaterial: preparedMaterialFromLesson(
          lesson: lesson,
          itemIdx: input.itemIdx,
          marker: input.marker,
          layer: input.layer,
        ),
      );
    });
  }

  void _enqueueLearningJob(ResolveLessonMaterialInput input) {
    stateService.mutate(input.lessonLocalId, (state) {
      return state.copyWith(
        queuedActions: [
          ...state.queuedActions,
          {
            'job_id':
                'lesson_material_${DateTime.now().millisecondsSinceEpoch}',
            'type': 'PREPARE_READY_WINDOW',
            'status': 'queued',
            'idempotency_key':
                'lesson-material:${input.lessonLocalId}:${input.itemIdx}:L${input.layer.value}:${input.marker ?? "no-marker"}',
            'priority': 'active',
            'source': 'StudentLessonMaterialService',
            'payload': {
              'maxSlots': 1,
              'reason': 'lesson_material_missing',
              'itemIdx': input.itemIdx,
              'layer': input.layer.value,
              'marker': input.marker,
              'topic': input.topic,
            },
            'created_at': DateTime.now().millisecondsSinceEpoch,
            'started_at': null,
            'finished_at': null,
            'error': null,
          },
        ],
      );
    });
  }
}
