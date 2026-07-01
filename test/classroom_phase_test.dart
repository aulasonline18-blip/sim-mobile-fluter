import 'package:flutter_test/flutter_test.dart';
import 'helpers/fake_visual_pipeline.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_answer_progress_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_hydration_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_main_view_model.dart';
import 'package:sim_mobile/sim/classroom/lesson_material_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_position_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_session_engine.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/student_lesson_material_service.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/mastery_truth_engine.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';
import 'package:sim_mobile/sim/state/student_state_store_adapter.dart';

class FakeClassroomT02 implements T02LessonClient {
  int calls = 0;
  final requests = <T02LessonRequest>[];

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    calls += 1;
    requests.add(request);
    return T02LessonMaterial(
      explanation: 'Explicacao ${request.item} L${request.layer.value}',
      question: 'Pergunta ${request.marker ?? request.item}?',
      options: const {
        AnswerLetter.A: 'Alternativa A',
        AnswerLetter.B: 'Alternativa B',
        AnswerLetter.C: 'Alternativa C',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'A esta correta.',
      whyWrong: null,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'fake-classroom',
    );
  }

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) =>
      completeLesson(request);

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) =>
      completeLesson(request);
}

StudentLearningState _classroomState() {
  const items = [
    CurriculumItem(marker: 'M1', text: 'Item 1'),
    CurriculumItem(marker: 'M2', text: 'Item 2'),
  ];
  return StudentLearningState.empty(lessonLocalId: 'cyber-class').copyWith(
    profile: const StudentProfile(
      objetivo: 'Aprender regra de tres',
      stableLang: 'pt-BR',
      nivel: 'base',
    ),
    curriculum: const StudentCurriculum(
      topic: 'Aprender regra de tres',
      totalItems: 2,
      generatedAt: null,
      provisional: false,
      items: items,
    ),
    current: const LessonCurrent(
      itemIdx: 0,
      marker: 'M1',
      layer: LessonLayer.l1,
      amparoLvl: 0,
    ),
    progress: const LessonProgress(
      itemIdx: 0,
      layer: LessonLayer.l1,
      erros: 0,
      amparoLvl: 0,
      historia: [],
      mainAdvances: 0,
      concluidos: [],
      pendentesMarkers: [],
      totalItems: 2,
      pctAvanco: 0,
    ),
  );
}

LessonRuntimeEngine _runtime(
  StudentLearningStateService stateService,
  FakeClassroomT02 t02, {
  StudentStateStore? store,
}) {
  final orchestrator = LessonOrchestrator(
    t02Client: t02,
    cache: LessonMaterialCache(),
    bus: LessonEventBus(),
    visualPipeline: fakeVisualPipeline(),
  );
  late DopamineReadyWindowEngine readyWindow;
  late StudentLessonMaterialService materialService;
  readyWindow = DopamineReadyWindowEngine(
    service: stateService,
    orchestrator: orchestrator,
  );
  materialService = StudentLessonMaterialService(
    stateService: stateService,
    orchestrator: orchestrator,
    readyWindowEngine: readyWindow,
  );
  final materialController = LessonMaterialController(
    stateService: stateService,
    materialService: materialService,
  );
  return LessonRuntimeEngine(
    stateService: stateService,
    sessionEngine: LessonSessionEngine(service: stateService),
    hydrationEngine: LessonHydrationEngine(materialService: materialService),
    positionEngine: LessonPositionEngine(),
    materialController: materialController,
    answerController: LessonAnswerProgressController(
      stateService: stateService,
      materialService: materialService,
      materialController: materialController,
      store: store,
    ),
  );
}

void main() {
  test(
    'LessonRuntimeEngine opens classroom and loads first material',
    () async {
      final service = StudentLearningStateService(
        seed: {'cyber-class': _classroomState()},
      );
      final t02 = FakeClassroomT02();
      final runtime = _runtime(service, t02);

      final snap = await runtime.open(lessonLocalId: 'cyber-class');

      expect(snap.hasCurriculum, isTrue);
      expect(snap.phase.type, ClassroomPhaseType.lendo);
      expect(snap.conteudo?.question, 'Pergunta M1?');
      expect(t02.calls, greaterThanOrEqualTo(1));
    },
  );

  test('Classroom answer A with signal 1 advances from L1 to L3', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-class': _classroomState()},
    );
    final t02 = FakeClassroomT02();
    final runtime = _runtime(service, t02);
    await runtime.open(lessonLocalId: 'cyber-class');

    runtime.select(AnswerLetter.A);
    await runtime.signal(DecisionSignal.one);
    var snap = runtime.snapshot();

    expect(snap.phase.type, ClassroomPhaseType.concluido);
    expect(snap.history, hasLength(1));
    expect(service.read('cyber-class')?.progress?.layer, LessonLayer.l3);

    await runtime.advance();
    snap = runtime.snapshot();

    expect(snap.phase.type, ClassroomPhaseType.lendo);
    expect(snap.itemMarker, 'M1');
    expect(service.read('cyber-class')?.current?.layer, LessonLayer.l3);
  });

  test(
    'answer signal writes false mastery truth and canonical event',
    () async {
      final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
      store.writeState(
        _classroomState().copyWith(
          attempts: const [
            LessonAttempt(
              marker: 'M1',
              layer: LessonLayer.l1,
              letra: AnswerLetter.B,
              sinal: DecisionSignal.one,
              correct: false,
              ts: 1,
            ),
          ],
        ),
      );
      final service = StudentStateStoreAdapter(store);
      final t02 = FakeClassroomT02();
      final runtime = _runtime(service, t02, store: store);
      await runtime.open(lessonLocalId: 'cyber-class');

      runtime.select(AnswerLetter.B);
      await runtime.signal(DecisionSignal.one);

      final state = store.readState('cyber-class');
      final truth = state.extra['truth'] as Map;
      final status = truth['item_consolidation_status'] as Map;
      expect(status['M1'], MasteryStatus.falseMastery.name);
      final eventTypes = store
          .getEventLog('cyber-class')
          .map((event) => event.type);
      expect(eventTypes, contains('MASTERY_EVALUATED'));
      expect(eventTypes, contains('WEAKNESS_REGISTERED'));
      expect(eventTypes, contains('REINFORCEMENT_REQUIRED'));
    },
  );

  test(
    'answer signal writes mastered truth after three correct attempts',
    () async {
      final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
      store.writeState(
        _classroomState().copyWith(
          attempts: const [
            LessonAttempt(
              marker: 'M1',
              layer: LessonLayer.l1,
              letra: AnswerLetter.A,
              sinal: DecisionSignal.one,
              correct: true,
              ts: 1,
            ),
            LessonAttempt(
              marker: 'M1',
              layer: LessonLayer.l1,
              letra: AnswerLetter.A,
              sinal: DecisionSignal.one,
              correct: true,
              ts: 2,
            ),
          ],
        ),
      );
      final service = StudentStateStoreAdapter(store);
      final t02 = FakeClassroomT02();
      final runtime = _runtime(service, t02, store: store);
      await runtime.open(lessonLocalId: 'cyber-class');

      runtime.select(AnswerLetter.A);
      await runtime.signal(DecisionSignal.one);

      final state = store.readState('cyber-class');
      final truth = state.extra['truth'] as Map;
      final status = truth['item_consolidation_status'] as Map;
      expect(status['M1'], MasteryStatus.mastered.name);
      final eventTypes = store
          .getEventLog('cyber-class')
          .map((event) => event.type);
      expect(eventTypes, contains('NEXT_ACTION_DECIDED'));
      expect(eventTypes, contains('ITEM_MASTERED'));
      expect(eventTypes, contains('ITEM_ADVANCED'));
    },
  );

  test('LessonMainViewModel locks after completion and labels next layer', () {
    final vm = buildLessonMainViewModel(
      baseItems: const [PlannedItem(marker: 'M1', text: 'Item 1')],
      mainAdvances: 0,
      isReviewAtivo: false,
      itemAtivo: const PlannedItem(marker: 'M1', text: 'Item 1'),
      itemIdx: 0,
      layer: LessonLayer.l1,
      phase: const ClassroomPhase.completed(
        message: 'ok',
        wasCorrect: true,
        signal: DecisionSignal.one,
      ),
      conteudo: null,
      items: const [PlannedItem(marker: 'M1', text: 'Item 1')],
    );

    expect(vm.locked, isTrue);
    expect(vm.nextLabel, 'aula_layer_label_3');
  });
}
