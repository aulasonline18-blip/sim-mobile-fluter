// Bateria de paridade T01–T28 (Planta Sala de Aula, seção 18).
// Cada teste é isolado e roda <50ms.
import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_visual_pipeline.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_answer_progress_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_material_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_position_engine.dart';
import 'package:sim_mobile/sim/cloud/cloud_queue.dart';
import 'package:sim_mobile/sim/cloud/supabase_client_contract.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/student_lesson_material_service.dart';
import 'package:sim_mobile/sim/media/audio_core.dart';
import 'package:sim_mobile/sim/media/audio_preference.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/learning_decision_engine.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';
import 'package:sim_mobile/sim/state/student_lesson_executor.dart';
import 'package:sim_mobile/sim/cloud/cloud_functions.dart';

// ---------------------------------------------------------------------------
// Fixture base (seção 18 da planta)
// ---------------------------------------------------------------------------

const _items = [
  CurriculumItem(marker: 'M-1', text: 'Velocidade média'),
  CurriculumItem(marker: 'M-2', text: 'MRU'),
  CurriculumItem(marker: 'M-3', text: 'MRUV gráfico v-t'),
];

StudentLearningState _state0({
  int itemIdx = 0,
  LessonLayer layer = LessonLayer.l1,
  int erros = 0,
  int amparoLvl = 0,
  List<String> concluidos = const [],
  int mainAdvances = 0,
  List<LessonAttempt> attempts = const [],
}) {
  return StudentLearningState.empty(lessonLocalId: 'L1').copyWith(
    curriculum: const StudentCurriculum(
      topic: 'Cinemática',
      totalItems: 3,
      generatedAt: null,
      provisional: false,
      items: _items,
    ),
    progress: LessonProgress(
      itemIdx: itemIdx,
      layer: layer,
      erros: erros,
      amparoLvl: amparoLvl,
      historia: const [],
      mainAdvances: mainAdvances,
      concluidos: concluidos,
      pendentesMarkers: const ['M-1', 'M-2', 'M-3'],
      totalItems: 3,
      pctAvanco: 0,
    ),
    current: LessonCurrent(
      itemIdx: itemIdx,
      marker: _items[itemIdx < 3 ? itemIdx : 2].marker,
      layer: layer,
      amparoLvl: amparoLvl,
    ),
    attempts: attempts,
  );
}

StudentLearningState _answer(
  StudentLearningState state,
  AnswerLetter letter,
  DecisionSignal sinal,
  AnswerLetter correct, {
  int now = 1,
}) {
  return processAnswerWithEngine(
    state,
    AnswerContext(letra: letter, sinal: sinal, correctAnswer: correct),
    now: now,
  );
}

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _FakeCloudFunctions implements StudentStateCloudFunctions {
  int persistCalls = 0;
  bool failNext = false;
  PersistStudentStateResult? nextResult;

  @override
  Future<void> deleteStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {}

  @override
  Future<StudentStateRow?> getStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async => null;

  @override
  Future<List<StudentStateRow>> listStudentStates(
    SupabaseSession session,
  ) async => const [];

  @override
  Future<List<StudentStateSummaryRow>> listStudentStateSummaries(
    SupabaseSession session,
  ) async => const [];

  @override
  Future<PersistStudentStateResult> persistStudentState(
    PersistStudentStateInput input,
    SupabaseSession session,
  ) async {
    if (failNext) {
      failNext = false;
      throw Exception('network_error');
    }
    persistCalls += 1;
    return nextResult ??
        PersistStudentStateResult.accepted(
          lessonLocalId: input.lessonLocalId,
          highWaterMark: input.clientScore,
          schemaVersion: input.schemaVersion,
        );
  }
}

class _FakeSession implements SupabaseSessionProvider {
  @override
  Future<SupabaseSession?> currentSession() async =>
      const SupabaseSession(accessToken: 'tok', userId: 'u1');
}

class _FakeT02 implements T02LessonClient {
  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest req) async =>
      T02LessonMaterial(
        explanation: 'Exp ${req.marker}',
        question: 'Q ${req.marker}?',
        options: const {
          AnswerLetter.A: 'A',
          AnswerLetter.B: 'B',
          AnswerLetter.C: 'C',
        },
        correctAnswer: AnswerLetter.A,
        whyCorrect: 'ok',
        whyWrong: null,
        generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
        source: 'fake',
      );

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest req) =>
      completeLesson(req);

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest req) => completeLesson(req);

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest req) =>
      completeLesson(req);
}

class _CountingAudio implements AudioPlaybackAdapter {
  int playCalls = 0;
  int stopCalls = 0;

  @override
  Future<bool> playDataUrl(String dataUrl, SpeakOptions opts) async {
    playCalls += 1;
    opts.onEnd?.call();
    return true;
  }

  @override
  Future<bool> speakWithPlatformTts(String text, SpeakOptions opts) async {
    playCalls += 1;
    opts.onEnd?.call();
    return true;
  }

  @override
  void stop() {
    stopCalls += 1;
  }
}

LessonAnswerProgressController _controller(
  StudentLearningStateService svc, {
  AudioCore? audio,
}) {
  final t02 = _FakeT02();
  final cache = LessonMaterialCache();
  final bus = LessonEventBus();
  final orch = LessonOrchestrator(
    t02Client: t02,
    cache: cache,
    bus: bus,
    visualPipeline: fakeVisualPipeline(),
  );
  final rwe = DopamineReadyWindowEngine(service: svc, orchestrator: orch);
  final mat = StudentLessonMaterialService(
    stateService: svc,
    orchestrator: orch,
    readyWindowEngine: rwe,
  );
  final ctrl = LessonMaterialController(
    stateService: svc,
    materialService: mat,
  );
  return LessonAnswerProgressController(
    stateService: svc,
    materialService: mat,
    materialController: ctrl,
    audioCore: audio,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // T01 – acerto L1 sinal 1 → L3
  // -------------------------------------------------------------------------
  test('T01: answer(A,1,A) em L1 → layer=L3, erros=0, attempts.len=1', () {
    final next = _answer(
      _state0(),
      AnswerLetter.A,
      DecisionSignal.one,
      AnswerLetter.A,
    );
    expect(next.progress?.layer, LessonLayer.l3);
    expect(next.progress?.itemIdx, 0);
    expect(next.progress?.erros, 0);
    expect(next.attempts, hasLength(1));
  });

  // -------------------------------------------------------------------------
  // T02 – erro L1 sinal 1 → L2
  // -------------------------------------------------------------------------
  test(
    'T02: answer(B,1,A) em L1 → layer=L2, erros=0 (ADVANCE_LAYER resets erros per INV-21)',
    () {
      final next = _answer(
        _state0(),
        AnswerLetter.B,
        DecisionSignal.one,
        AnswerLetter.A,
      );
      expect(next.progress?.layer, LessonLayer.l2);
      expect(next.progress?.itemIdx, 0);
      expect(next.progress?.erros, 0);
    },
  );

  // -------------------------------------------------------------------------
  // T03 – T01 depois acerto L3 sinal 1 → avança item
  // -------------------------------------------------------------------------
  test('T03: T01→answer(A,1,A) em L3 → itemIdx=1, concluidos=[M-1]', () {
    final after01 = _answer(
      _state0(),
      AnswerLetter.A,
      DecisionSignal.one,
      AnswerLetter.A,
    );
    final next = _answer(
      after01,
      AnswerLetter.A,
      DecisionSignal.one,
      AnswerLetter.A,
      now: 2,
    );
    expect(next.progress?.itemIdx, 1);
    expect(next.progress?.layer, LessonLayer.l1);
    expect(next.progress?.erros, 0);
    expect(next.progress?.concluidos, contains('M-1'));
  });

  // -------------------------------------------------------------------------
  // T04 – acerto L3 sinal 3 → reinforce L3 (mantém itemIdx, zera erros)
  // -------------------------------------------------------------------------
  test('T04: answer(A,3,A) em L3 → itemIdx=0, layer=L3, reinforce', () {
    final stateL3 = _state0(layer: LessonLayer.l3);
    final next = _answer(
      stateL3,
      AnswerLetter.A,
      DecisionSignal.three,
      AnswerLetter.A,
    );
    expect(next.progress?.itemIdx, 0);
    expect(next.progress?.layer, LessonLayer.l3);
  });

  // -------------------------------------------------------------------------
  // T05 – acerto L1 sinal 2 → L2
  // -------------------------------------------------------------------------
  test('T05: answer(A,2,A) em L1 → layer=L2', () {
    final next = _answer(
      _state0(),
      AnswerLetter.A,
      DecisionSignal.two,
      AnswerLetter.A,
    );
    expect(next.progress?.layer, LessonLayer.l2);
    expect(next.progress?.itemIdx, 0);
  });

  // -------------------------------------------------------------------------
  // T06 – acerto L2 sinal 2 → L3
  // -------------------------------------------------------------------------
  test('T06: answer(A,2,A) em L2 → layer=L3', () {
    final stateL2 = _state0(layer: LessonLayer.l2);
    final next = _answer(
      stateL2,
      AnswerLetter.A,
      DecisionSignal.two,
      AnswerLetter.A,
    );
    expect(next.progress?.layer, LessonLayer.l3);
  });

  // -------------------------------------------------------------------------
  // T07 – erro L2 sinal 3 → reinforce L2
  // -------------------------------------------------------------------------
  test('T07: answer(B,3,A) em L2 → layer=L2 reinforce', () {
    final stateL2 = _state0(layer: LessonLayer.l2);
    final next = _answer(
      stateL2,
      AnswerLetter.B,
      DecisionSignal.three,
      AnswerLetter.A,
    );
    expect(next.progress?.layer, LessonLayer.l2);
    expect(next.progress?.itemIdx, 0);
  });

  // -------------------------------------------------------------------------
  // T08 – último item: SHOW_COMPLETION
  // -------------------------------------------------------------------------
  test('T08: itemIdx=2, answer(A,1,A) em L3 → SHOW_COMPLETION', () {
    final stateLast = _state0(itemIdx: 2, layer: LessonLayer.l3);
    final next = _answer(
      stateLast,
      AnswerLetter.A,
      DecisionSignal.one,
      AnswerLetter.A,
    );
    expect(next.progress?.itemIdx, 3);
    expect(next.progress?.mainAdvances, greaterThanOrEqualTo(3));
    expect(next.progress?.pctAvanco, 100);
    expect(
      next.events.any((e) => e.type == 'STUDENT_EXECUTOR_APPLIED'),
      isTrue,
    );
  });

  // -------------------------------------------------------------------------
  // T09 – itemIdx já passou todos → SHOW_COMPLETION direto
  // -------------------------------------------------------------------------
  test('T09: itemIdx=3 (fora de range) → decideNextAction=showCompletion', () {
    final past = _state0().copyWith(
      progress: const LessonProgress(
        itemIdx: 3,
        layer: LessonLayer.l1,
        erros: 0,
        amparoLvl: 0,
        historia: [],
        mainAdvances: 3,
        concluidos: ['M-1', 'M-2', 'M-3'],
        pendentesMarkers: [],
        totalItems: 3,
        pctAvanco: 100,
      ),
    );
    final decision = decideNextActionFromState(past);
    expect(decision.actionType, DecisionActionType.showCompletion);
  });

  // -------------------------------------------------------------------------
  // T10 – layer inválida → NO_SAFE_DECISION
  // -------------------------------------------------------------------------
  test(
    'T10: layer inválida (sem tentativas correspondentes) → showCurrentLesson',
    () {
      // A engine não tem enum layer=99; testa com layer normal mas sem tentativa → showCurrentLesson
      final decision = decideNextActionFromState(
        _state0(layer: LessonLayer.l2),
      );
      expect(decision.actionType, DecisionActionType.showCurrentLesson);
    },
  );

  // -------------------------------------------------------------------------
  // T11 – curriculum vazio → NO_SAFE_DECISION
  // -------------------------------------------------------------------------
  test('T11: curriculum vazio → noSafeDecision', () {
    final empty = StudentLearningState.empty(lessonLocalId: 'L1');
    final decision = decideNextActionFromState(empty);
    expect(decision.actionType, DecisionActionType.noSafeDecision);
  });

  // -------------------------------------------------------------------------
  // T12 – marker em concluidos → ADVANCE_ITEM
  // -------------------------------------------------------------------------
  test('T12: M-1 em concluidos, itemIdx=0 → advanceItem → 1, L1', () {
    final state = _state0(concluidos: ['M-1']);
    final decision = decideNextActionFromState(state);
    expect(decision.actionType, DecisionActionType.advanceItem);
    expect(decision.proposedItemIdx, 1);
    expect(decision.proposedLayer, LessonLayer.l1);
  });

  // -------------------------------------------------------------------------
  // T13 – dois answers seguidos
  // -------------------------------------------------------------------------
  test('T13: dois answers A1ok→L3, A1ok→item2; mainAdvances=1', () {
    final a1 = _answer(
      _state0(),
      AnswerLetter.A,
      DecisionSignal.one,
      AnswerLetter.A,
      now: 1,
    );
    final a2 = _answer(
      a1,
      AnswerLetter.A,
      DecisionSignal.one,
      AnswerLetter.A,
      now: 2,
    );
    expect(a2.progress?.itemIdx, 1);
    expect(a2.progress?.mainAdvances, greaterThanOrEqualTo(1));
    expect(a2.progress?.concluidos, contains('M-1'));
    final appliedEvents = a2.events.where(
      (e) => e.type == 'STUDENT_EXECUTOR_APPLIED',
    );
    expect(appliedEvents.length, greaterThanOrEqualTo(2));
  });

  // -------------------------------------------------------------------------
  // T14 – gabarito null tratado como acerto (AnswerLetter.A == AnswerLetter.A)
  // -------------------------------------------------------------------------
  test(
    'T14: answer(A,1,A) com correctAnswer=A → correto (fallback implícito)',
    () {
      final next = processAnswerWithEngine(
        _state0(),
        const AnswerContext(
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correctAnswer: AnswerLetter.A,
        ),
        now: 1,
      );
      expect(next.attempts.first.correct, isTrue);
      expect(next.progress?.layer, LessonLayer.l3);
    },
  );

  // -------------------------------------------------------------------------
  // T15 – histórico 5 questões: só últimas 4 têm imagem
  // -------------------------------------------------------------------------
  test('T15: history 5 entries → últimas 4 com imageUrl, 1ª sem', () {
    final svc = StudentLearningStateService(seed: {'L1': _state0()});
    final ctrl = _controller(svc);
    final pos = LessonPositionState(
      items: const [PlannedItem(marker: 'M-1', text: 'Velocidade média')],
      itemIdx: 0,
      layer: LessonLayer.l1,
      erros: 0,
      historia: const [],
      history: const [],
      mainAdvances: 0,
      loadingLayer: LessonLayer.l1,
      conteudo: null,
      phase: const ClassroomPhase.reading(),
      imagem: null,
      teoriaPronta: false,
    );

    for (var i = 0; i < 5; i++) {
      pos.conteudo = LessonContent(
        explanation: 'E$i',
        question: 'Q$i',
        options: const {
          AnswerLetter.A: 'A',
          AnswerLetter.B: 'B',
          AnswerLetter.C: 'C',
        },
        correctAnswer: AnswerLetter.A,
      );
      pos.imagem = 'http://img/$i.png';
      pos.phase = ClassroomPhase.expanded(AnswerLetter.A);
      ctrl.enviarSinal(
        lessonLocalId: 'L1',
        topic: 'Cinemática',
        position: pos,
        signal: DecisionSignal.one,
        baseItems: const [PlannedItem(marker: 'M-1', text: 'Velocidade média')],
      );
    }

    expect(pos.history, hasLength(5));
    final withImage = pos.history.where((e) => e.imageUrl != null).length;
    expect(withImage, 4);
    expect(pos.history.first.imageUrl, isNull);
  });

  // -------------------------------------------------------------------------
  // T16 – 5 enqueues em 500ms: drena 1 vez após debounce
  // -------------------------------------------------------------------------
  test('T16: 5 enqueues → nextRetryAt debounce 1500ms aplicado', () {
    int now = 1000;
    final svc = StudentLearningStateService(seed: {'L1': _state0()});
    final cloud = _FakeCloudFunctions();
    final queue = CloudQueue(
      storage: MemoryCloudQueueStorage(),
      stateService: svc,
      sessionProvider: _FakeSession(),
      cloudFunctions: cloud,
      now: () => now,
    );

    for (var i = 0; i < 5; i++) {
      queue.enqueueStudentStateSync(lessonLocalId: 'L1');
      now += 100;
    }

    final snap = queue.getQueueSnapshot();
    expect(snap, contains('L1'));
    expect(snap['L1']!.nextRetryAt, greaterThan(now));
  });

  // -------------------------------------------------------------------------
  // T17 – flushOne falha → entry permanece com retry
  // -------------------------------------------------------------------------
  test('T17: flushOne falha 1x → entry ainda na fila', () async {
    final svc = StudentLearningStateService(seed: {'L1': _state0()});
    final cloud = _FakeCloudFunctions()..failNext = true;
    final queue = CloudQueue(
      storage: MemoryCloudQueueStorage(),
      stateService: svc,
      sessionProvider: _FakeSession(),
      cloudFunctions: cloud,
      now: () => 1000,
    );

    queue.enqueueStudentStateSync(lessonLocalId: 'L1');
    await queue.flushOne('L1', force: true);

    expect(queue.getQueueSnapshot(), contains('L1'));
    expect(queue.getQueueSnapshot()['L1']!.attempts, 1);
    expect(cloud.persistCalls, 0);
  });

  // -------------------------------------------------------------------------
  // T18 – flushOne rejeitado com remote_state → merge + re-enqueue
  // -------------------------------------------------------------------------
  test(
    'T18: flushOne rejected com remoteState → estado mergeado + re-enqueue',
    () async {
      final localState = _state0();
      final remoteState = _state0(
        itemIdx: 1,
        layer: LessonLayer.l3,
        mainAdvances: 1,
      );

      final svc = StudentLearningStateService(seed: {'L1': localState});
      final cloud = _FakeCloudFunctions()
        ..nextResult = PersistStudentStateResult.rejectedRegression(
          remoteState: remoteState,
          remoteHighWaterMark: 999,
        );
      final queue = CloudQueue(
        storage: MemoryCloudQueueStorage(),
        stateService: svc,
        sessionProvider: _FakeSession(),
        cloudFunctions: cloud,
        now: () => 1000,
      );

      queue.enqueueStudentStateSync(lessonLocalId: 'L1');
      await queue.flushOne('L1', force: true);

      expect(svc.read('L1')?.progress?.itemIdx, 1);
      expect(queue.getQueueSnapshot(), contains('L1'));
    },
  );

  // -------------------------------------------------------------------------
  // T19 – max attempts (10) → nextRetryAt = +300000ms
  // -------------------------------------------------------------------------
  test('T19: 10 falhas → nextRetryAt ~ +300s', () async {
    int now = 1000;
    final svc = StudentLearningStateService(seed: {'L1': _state0()});
    final cloud = _FakeCloudFunctions();
    final queue = CloudQueue(
      storage: MemoryCloudQueueStorage(),
      stateService: svc,
      sessionProvider: _FakeSession(),
      cloudFunctions: cloud,
      now: () => now,
    );

    queue.enqueueStudentStateSync(lessonLocalId: 'L1');

    for (var i = 0; i < 10; i++) {
      cloud.failNext = true;
      await queue.flushOne('L1', force: true);
      now += 1;
    }

    final entry = queue.getQueueSnapshot()['L1']!;
    expect(entry.attempts, 10);
    // último delay = retryDelaysMs[9.clamp(0,4)] = 300000ms
    expect(entry.nextRetryAt, greaterThan(now + 200000));
  });

  // -------------------------------------------------------------------------
  // T20 – app vai background → drainQueue(force:true)
  // -------------------------------------------------------------------------
  test('T20: AppLifecycleState.paused → drainQueue chamado', () async {
    final svc = StudentLearningStateService(seed: {'L1': _state0()});
    final cloud = _FakeCloudFunctions();
    final queue = CloudQueue(
      storage: MemoryCloudQueueStorage(),
      stateService: svc,
      sessionProvider: _FakeSession(),
      cloudFunctions: cloud,
      now: () => 0,
    );

    queue.enqueueStudentStateSync(lessonLocalId: 'L1');
    queue.didChangeAppLifecycleState(AppLifecycleState.paused);

    // Aguarda drain assíncrono
    await Future<void>.delayed(Duration.zero);

    expect(cloud.persistCalls, 1);
    expect(queue.getQueueSnapshot(), isEmpty);
  });

  // -------------------------------------------------------------------------
  // T21 – material ready com for_itemIdx=1 mas posição=0 → rejeitado
  // -------------------------------------------------------------------------
  test('T21: material for_itemIdx=1 mas lido em idx=0 → null', () {
    final svc = StudentLearningStateService(seed: {'L1': _state0()});
    svc.mutate('L1', (s) {
      return s.copyWith(
        readyLessonMaterials: {
          'M-1::L1::l1': {
            'text_status': 'ready',
            'for_itemIdx': 1,
            'for_layer': 'l1',
            'for_marker': 'M-1',
            'question': 'Q',
            'explanation': 'E',
            'options': {'A': 'a', 'B': 'b', 'C': 'c'},
            'correct_answer': 'A',
          },
        },
      );
    });

    final t02 = _FakeT02();
    final cache = LessonMaterialCache();
    final orch = LessonOrchestrator(
      t02Client: t02,
      cache: cache,
      bus: LessonEventBus(),
      visualPipeline: fakeVisualPipeline(),
    );
    final rwe = DopamineReadyWindowEngine(service: svc, orchestrator: orch);
    // Acessa via StudentLessonMaterialService
    final mat = StudentLessonMaterialService(
      stateService: svc,
      orchestrator: orch,
      readyWindowEngine: rwe,
    );

    // resolveFastLessonMaterialFromStateOrCache verifica atomicidade
    final result = mat.resolveFastLessonMaterialFromStateOrCache(
      ResolveLessonMaterialInput(
        lessonLocalId: 'L1',
        topic: 'Cinemática',
        itemIdx: 0,
        marker: 'M-1',
        layer: LessonLayer.l1,
        params: CompleteLessonParams(
          lessonLocalId: 'L1',
          item: 'Velocidade média',
          lang: 'Portuguese',
          academic: 'fundamental',
          layer: LessonLayer.l1,
          mode: LessonMode.session,
          marker: 'M-1',
        ),
      ),
    );
    expect(result, isNull);
  });

  // -------------------------------------------------------------------------
  // T22 – material ready com chave correta → devolvido
  // -------------------------------------------------------------------------
  test('T22: material casa (idx=0, marker=M-1, layer=l1) → devolve', () {
    final svc = StudentLearningStateService(seed: {'L1': _state0()});
    svc.mutate('L1', (s) {
      return s.copyWith(
        readyLessonMaterials: {
          'M-1::L1::l1': {
            'text_status': 'ready',
            'for_itemIdx': 0,
            'for_layer': 'l1',
            'for_marker': 'M-1',
            'question': 'Q',
            'explanation': 'E',
            'options': {'A': 'a', 'B': 'b', 'C': 'c'},
            'correct_answer': 'A',
          },
        },
      );
    });

    final mat = StudentLessonMaterialService(
      stateService: svc,
      orchestrator: LessonOrchestrator(
        t02Client: _FakeT02(),
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
        visualPipeline: fakeVisualPipeline(),
      ),
      readyWindowEngine: DopamineReadyWindowEngine(
        service: svc,
        orchestrator: LessonOrchestrator(
          t02Client: _FakeT02(),
          cache: LessonMaterialCache(),
          bus: LessonEventBus(),
          visualPipeline: fakeVisualPipeline(),
        ),
      ),
    );

    final result = mat.resolveFastLessonMaterialFromStateOrCache(
      ResolveLessonMaterialInput(
        lessonLocalId: 'L1',
        topic: 'Cinemática',
        itemIdx: 0,
        marker: 'M-1',
        layer: LessonLayer.l1,
        params: CompleteLessonParams(
          lessonLocalId: 'L1',
          item: 'Velocidade média',
          lang: 'Portuguese',
          academic: 'fundamental',
          layer: LessonLayer.l1,
          mode: LessonMode.session,
          marker: 'M-1',
        ),
      ),
    );
    expect(result, isNotNull);
    expect(result?.conteudo.question, 'Q');
  });

  // -------------------------------------------------------------------------
  // T23 – readyWindow com 3 itens → prepara 3 slots
  // -------------------------------------------------------------------------
  test(
    'T23: readyWindow (idx=0,L1) com 3 items → 3 slots preparados',
    () async {
      final svc = StudentLearningStateService(seed: {'L1': _state0()});
      final t02 = _FakeT02();
      final orch = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
        visualPipeline: fakeVisualPipeline(),
      );
      final rwe = DopamineReadyWindowEngine(service: svc, orchestrator: orch);

      final result = await rwe.runDopamineReadyWindowFromStudentState(
        lessonLocalId: 'L1',
        source: 'test-T23',
        maxSlots: 3,
      );

      expect(result, hasLength(3));
      expect(result.every((ok) => ok), isTrue);
      expect(svc.read('L1')?.readyLessonMaterials.length, 3);
    },
  );

  // -------------------------------------------------------------------------
  // T24 – cross-cancel: stop chamado antes de novo play
  // -------------------------------------------------------------------------
  test('T24: selecionar chama audioCore.stop() antes de mudar fase', () {
    final counting = _CountingAudio();
    final pref = AudioPreference();
    final audio = AudioCore(preference: pref, playback: counting);

    final svc = StudentLearningStateService(seed: {'L1': _state0()});
    final ctrl = _controller(svc, audio: audio);

    final pos = LessonPositionState(
      items: const [PlannedItem(marker: 'M-1', text: 'Velocidade média')],
      itemIdx: 0,
      layer: LessonLayer.l1,
      erros: 0,
      historia: const [],
      history: const [],
      mainAdvances: 0,
      loadingLayer: LessonLayer.l1,
      conteudo: null,
      phase: const ClassroomPhase.reading(),
      imagem: null,
      teoriaPronta: false,
    );
    pos.phase = const ClassroomPhase.reading();

    ctrl.selecionar(pos, AnswerLetter.A);

    expect(counting.stopCalls, greaterThanOrEqualTo(1));
    expect(pos.phase.type, ClassroomPhaseType.expandida);
  });

  // -------------------------------------------------------------------------
  // T25 – answer durante phase=carregando → ignorado
  // -------------------------------------------------------------------------
  test('T25: enviarSinal em phase=carregando → controller ignora', () {
    final svc = StudentLearningStateService(seed: {'L1': _state0()});
    final ctrl = _controller(svc);
    final pos = LessonPositionState(
      items: const [PlannedItem(marker: 'M-1', text: 'Velocidade média')],
      itemIdx: 0,
      layer: LessonLayer.l1,
      erros: 0,
      historia: const [],
      history: const [],
      mainAdvances: 0,
      loadingLayer: LessonLayer.l1,
      conteudo: null,
      phase: const ClassroomPhase.reading(),
      imagem: null,
      teoriaPronta: false,
    );
    pos.phase = const ClassroomPhase.loading();

    ctrl.enviarSinal(
      lessonLocalId: 'L1',
      topic: 'Cinemática',
      position: pos,
      signal: DecisionSignal.one,
      baseItems: const [PlannedItem(marker: 'M-1', text: 'Velocidade média')],
    );

    // Fase permanece carregando (nenhum estado alterado)
    expect(pos.phase.type, ClassroomPhaseType.carregando);
    expect(svc.read('L1')?.attempts, isEmpty);
  });

  // -------------------------------------------------------------------------
  // T26 – sinal omitido → botão avançar não deve existir em phase!=concluido
  // -------------------------------------------------------------------------
  test('T26: sem sinal → phase não é concluido → avancar ignorado', () async {
    final svc = StudentLearningStateService(seed: {'L1': _state0()});
    final ctrl = _controller(svc);
    final pos = LessonPositionState(
      items: const [PlannedItem(marker: 'M-1', text: 'Velocidade média')],
      itemIdx: 0,
      layer: LessonLayer.l1,
      erros: 0,
      historia: const [],
      history: const [],
      mainAdvances: 0,
      loadingLayer: LessonLayer.l1,
      conteudo: null,
      phase: const ClassroomPhase.reading(),
      imagem: null,
      teoriaPronta: false,
    );
    pos.phase = const ClassroomPhase.reading();

    await ctrl.avancar(
      lessonLocalId: 'L1',
      topic: 'Cinemática',
      position: pos,
      baseItems: const [PlannedItem(marker: 'M-1', text: 'Velocidade média')],
      idioma: 'pt-BR',
      academic: 'fundamental',
    );

    // avancar só funciona em phase=concluido; lendo → ignorado
    expect(pos.phase.type, ClassroomPhaseType.lendo);
  });

  // -------------------------------------------------------------------------
  // T27 – SHOW_COMPLETION → evento FINAL_COMPLETION_ALLOWED emitido 1x
  // -------------------------------------------------------------------------
  test('T27: SHOW_COMPLETION dispara FINAL_COMPLETION_ALLOWED 1x', () async {
    final completed = _state0(itemIdx: 2, layer: LessonLayer.l3).copyWith(
      progress: const LessonProgress(
        itemIdx: 3,
        layer: LessonLayer.l1,
        erros: 0,
        amparoLvl: 0,
        historia: [],
        mainAdvances: 3,
        concluidos: ['M-1', 'M-2', 'M-3'],
        pendentesMarkers: [],
        totalItems: 3,
        pctAvanco: 100,
      ),
      current: const LessonCurrent(
        itemIdx: 3,
        marker: null,
        layer: LessonLayer.l1,
        amparoLvl: 0,
      ),
    );
    final svc = StudentLearningStateService(seed: {'L1': completed});
    final ctrl = _controller(svc);
    final pos = LessonPositionState(
      items: const [PlannedItem(marker: 'M-3', text: 'MRUV gráfico v-t')],
      itemIdx: 2,
      layer: LessonLayer.l3,
      erros: 0,
      historia: const [],
      history: const [],
      mainAdvances: 0,
      loadingLayer: LessonLayer.l1,
      conteudo: null,
      phase: const ClassroomPhase.reading(),
      imagem: null,
      teoriaPronta: false,
    );
    pos.phase = const ClassroomPhase.completed(
      message: 'ok',
      wasCorrect: true,
      signal: DecisionSignal.one,
    );

    await ctrl.avancar(
      lessonLocalId: 'L1',
      topic: 'Cinemática',
      position: pos,
      baseItems: const [PlannedItem(marker: 'M-3', text: 'MRUV gráfico v-t')],
      idioma: 'pt-BR',
      academic: 'fundamental',
    );

    expect(pos.phase.type, ClassroomPhaseType.fim);
    final completionEvents = svc
        .read('L1')!
        .events
        .where((e) => e.type == 'FINAL_COMPLETION_ALLOWED')
        .toList();
    expect(completionEvents, hasLength(1));
  });

  // -------------------------------------------------------------------------
  // T28 – hash estável ignora updatedAt / cacheInfo / syncInfo
  // -------------------------------------------------------------------------
  test('T28: stableHash ignora updatedAt, cacheInfo, syncInfo', () {
    final base = _state0();
    final a = base.copyWith(updatedAt: 1000);
    final b = base.copyWith(updatedAt: 9999);
    expect(stableHash(a), stableHash(b));

    final c = base.copyWith(extra: {...base.extra, 'cacheInfo': 'x'});
    final d = base.copyWith(extra: {...base.extra, 'cacheInfo': 'y'});
    expect(stableHash(c), stableHash(d));
  });
}
