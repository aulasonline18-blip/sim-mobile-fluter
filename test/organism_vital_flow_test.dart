import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/classroom/classroom_models.dart';
import 'package:sim_mobile/sim/classroom/lesson_answer_progress_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_hydration_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_material_controller.dart';
import 'package:sim_mobile/sim/classroom/lesson_position_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_runtime_engine.dart';
import 'package:sim_mobile/sim/classroom/lesson_session_engine.dart';
import 'package:sim_mobile/sim/experience/student_experience_engine.dart';
import 'package:sim_mobile/sim/experience/student_experience_t00_adapter.dart';
import 'package:sim_mobile/sim/experience/student_experience_t02_adapter.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/student_lesson_material_service.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

class VitalT00Client implements T00BootstrapClient {
  final requests = <T00BootstrapRequest>[];

  @override
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request) async* {
    requests.add(request);
    yield const T00BootstrapChunk(
      type: 't00_profile',
      payload: {
        'profile': 'Aluno visual, precisa de exemplos curtos.',
        'ficha_for_next': {
          'guidance_for_T02': 'Use exemplos concretos e pergunta curta.',
          'student_profile_internal': {'pace': 'fast-path'},
        },
      },
    );
    yield const T00BootstrapChunk(
      type: 't00_item_partial',
      payload: {
        'item': {
          'order': 1,
          'marker': 'M1',
          'title': 'Frações equivalentes',
          'microitem_for_teacher': 'Reconhecer frações equivalentes simples',
        },
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 10));
    yield const T00BootstrapChunk(
      type: 't00_item_partial',
      payload: {
        'item': {
          'order': 2,
          'marker': 'M2',
          'title': 'Comparação de frações',
          'microitem_for_teacher': 'Comparar frações com denominadores iguais',
        },
      },
    );
    yield const T00BootstrapChunk(
      type: 't00_final',
      payload: {
        'curriculum': [
          {
            'order': 1,
            'marker': 'M1',
            'title': 'Frações equivalentes',
            'microitem_for_teacher': 'Reconhecer frações equivalentes simples',
          },
          {
            'order': 2,
            'marker': 'M2',
            'title': 'Comparação de frações',
            'microitem_for_teacher':
                'Comparar frações com denominadores iguais',
          },
        ],
      },
    );
  }
}

class VitalT02Client implements T02LessonClient {
  final requests = <T02LessonRequest>[];

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    requests.add(request);
    return T02LessonMaterial(
      explanation:
          'Aula ${request.marker} L${request.layer.value}: ${request.item}.',
      question: 'Qual alternativa mostra equivalencia?',
      options: const {
        AnswerLetter.A: '2/4',
        AnswerLetter.B: '2/5',
        AnswerLetter.C: '3/5',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: '2/4 representa a mesma metade que 1/2.',
      whyWrong: const {'B': 'muda a proporcao', 'C': 'tambem muda a proporcao'},
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'vital-fake-t02',
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

class VitalHarness {
  VitalHarness()
    : service = StudentLearningStateService(),
      t00 = VitalT00Client(),
      t02 = VitalT02Client() {
    orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: LessonMaterialCache(maxLessons: 3),
      bus: LessonEventBus(),
    );
    readyWindow = DopamineReadyWindowEngine(
      service: service,
      orchestrator: orchestrator,
    );
    materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: readyWindow,
    );
    final materialController = LessonMaterialController(
      stateService: service,
      materialService: materialService,
    );
    experience = StudentExperienceEngine(
      service: service,
      t00: StudentExperienceT00Adapter(service: service, client: t00),
      t02: StudentExperienceT02Adapter(
        service: service,
        materialService: materialService,
      ),
      placement: const SettledPlacementReader(settled: true),
    );
    runtime = LessonRuntimeEngine(
      stateService: service,
      sessionEngine: LessonSessionEngine(service: service),
      hydrationEngine: LessonHydrationEngine(materialService: materialService),
      positionEngine: LessonPositionEngine(),
      materialController: materialController,
      answerController: LessonAnswerProgressController(
        stateService: service,
        materialService: materialService,
        materialController: materialController,
      ),
    );
  }

  final StudentLearningStateService service;
  final VitalT00Client t00;
  final VitalT02Client t02;
  late final LessonOrchestrator orchestrator;
  late final DopamineReadyWindowEngine readyWindow;
  late final StudentLessonMaterialService materialService;
  late final StudentExperienceEngine experience;
  late final LessonRuntimeEngine runtime;
}

void main() {
  test(
    'fluxo vital: objetivo -> T00 -> T02 -> aula -> A/B/C -> 1/2/3 -> motor -> janela',
    () async {
      final h = VitalHarness();
      const lessonLocalId = 'vital-flow-1';

      final result = await h.experience.prepareStudentExperienceEntry(
        const StudentExperienceArgs(
          academic: 'fundamental',
          idioma: 'pt-BR',
          lessonLocalId: lessonLocalId,
          onboarding: {
            'objetivo': 'Aprender frações equivalentes',
            'free_text': 'Aprender frações equivalentes',
            'stable_lang': 'pt-BR',
            'academic_level': 'fundamental',
            'preferred_name': 'Ana',
          },
        ),
      );

      expect(result.destination, '/cyber/aula');
      expect(h.t00.requests, hasLength(1), reason: 'T00 precisa ser chamado');
      expect(h.t02.requests, isNotEmpty, reason: 'T02 precisa ser chamado');

      final firstT02 = h.t02.requests.first;
      expect(firstT02.item, 'Reconhecer frações equivalentes simples');
      expect(firstT02.marker, 'M1');
      expect(firstT02.layer, LessonLayer.l1);
      expect(firstT02.lang, 'pt-BR');
      expect(firstT02.academic, 'fundamental');
      expect(firstT02.profile['stable_lang'], 'pt-BR');
      expect(firstT02.profile['academic_level'], 'fundamental');
      expect(firstT02.profile['preferred_name'], 'Ana');

      var state = h.service.read(lessonLocalId);
      expect(state?.curriculum?.items.first.marker, 'M1');
      expect(state?.currentLessonMaterial?['text_status'], 'ready');
      expect(state?.readyLessonMaterials, isNotEmpty);
      expect(state?.current?.marker, 'M1');

      await Future<void>.delayed(const Duration(milliseconds: 30));
      state = h.service.read(lessonLocalId);
      expect(
        state?.events.map((event) => event.type),
        contains('BACKGROUND_READY_WINDOW_STARTED'),
      );
      expect(
        state?.events.map((event) => event.type),
        contains('DOPAMINE_WINDOW_REQUESTED'),
      );
      expect(
        h.t02.requests.where((request) => request.layer == LessonLayer.l2),
        isNotEmpty,
        reason: 'slot B deve ser preparado em background',
      );
      expect(
        h.t02.requests.where((request) => request.layer == LessonLayer.l3),
        isNotEmpty,
        reason: 'slot C deve ser preparado em background',
      );

      final snap = await h.runtime.open(lessonLocalId: lessonLocalId);
      expect(snap.hasCurriculum, isTrue);
      expect(snap.phase.type, ClassroomPhaseType.lendo);
      expect(snap.conteudo?.question, isNotEmpty);
      expect(snap.conteudo?.options.keys, contains(AnswerLetter.A));
      expect(
        h.service.read(lessonLocalId)?.currentLessonMaterial?['text_status'],
        'ready',
        reason: 'aula textual deve estar pronta sem depender de imagem/audio',
      );

      h.runtime.select(AnswerLetter.A);
      expect(h.runtime.snapshot().phase.letter, AnswerLetter.A);
      await h.runtime.signal(DecisionSignal.one);

      state = h.service.read(lessonLocalId);
      expect(state?.attempts, hasLength(1));
      final attempt = state!.attempts.single;
      expect(attempt.marker, 'M1');
      expect(attempt.letra, AnswerLetter.A);
      expect(attempt.sinal, DecisionSignal.one);
      expect(attempt.correct, isTrue);

      final eventTypes = state.events.map((event) => event.type).toList();
      expect(eventTypes, contains('ANSWER_SUBMITTED'));
      expect(eventTypes, contains('STUDENT_DECISION_APPLIED'));
      expect(eventTypes, contains('STUDENT_EXECUTOR_APPLIED'));
      expect(eventTypes, contains('NEXT_ACTION_DECIDED'));
      final executorDecision = state.events.firstWhere(
        (event) => event.type == 'STUDENT_DECISION_APPLIED',
      );
      expect(executorDecision.payload['decision'], 'advanceLayer');
      expect(
        state.extra['next_action'],
        isA<Map>().having((value) => value['action'], 'action', isNotEmpty),
      );
      expect(
        state.queuedActions.where(
          (job) => job['type'] == 'PREPARE_READY_WINDOW',
        ),
        isNotEmpty,
        reason: 'janela A/B/C deve ser solicitada apos tentativa',
      );
    },
  );
}
