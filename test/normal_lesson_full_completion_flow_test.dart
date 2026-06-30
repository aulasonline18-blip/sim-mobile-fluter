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

class FullFlowT00Client implements T00BootstrapClient {
  final requests = <T00BootstrapRequest>[];

  @override
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request) async* {
    requests.add(request);
    yield const T00BootstrapChunk(
      type: 't00_profile',
      payload: {
        'profile': 'Aluno direto, com exemplos progressivos.',
        'ficha_for_next': {
          'guidance_for_T02': 'Aula curta, pergunta objetiva e tres opcoes.',
          'student_profile_internal': {'pace': 'normal-completion'},
        },
      },
    );
    for (final item in _curriculumItems) {
      yield T00BootstrapChunk(
        type: 't00_item_partial',
        payload: {'item': item},
      );
    }
    yield const T00BootstrapChunk(
      type: 't00_final',
      payload: {'curriculum': _curriculumItems},
    );
  }
}

class FullFlowT02Client implements T02LessonClient {
  final requests = <T02LessonRequest>[];

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    requests.add(request);
    return T02LessonMaterial(
      explanation:
          'Texto ${request.marker} ${request.layer.value}: ${request.item}.',
      question: 'Qual alternativa resolve ${request.marker}?',
      options: const {
        AnswerLetter.A: 'Resposta correta',
        AnswerLetter.B: 'Distrator proximo',
        AnswerLetter.C: 'Distrator distante',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'A alternativa A segue a explicacao.',
      whyWrong: const {'B': 'confunde o passo', 'C': 'troca a regra'},
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'normal-flow-fake-t02',
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

class FullFlowHarness {
  FullFlowHarness({Map<String, StudentLearningState>? seed})
    : service = StudentLearningStateService(seed: seed),
      t00 = FullFlowT00Client(),
      t02 = FullFlowT02Client() {
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
    materialController = LessonMaterialController(
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
  final FullFlowT00Client t00;
  final FullFlowT02Client t02;
  late final LessonOrchestrator orchestrator;
  late final DopamineReadyWindowEngine readyWindow;
  late final StudentLessonMaterialService materialService;
  late final LessonMaterialController materialController;
  late final StudentExperienceEngine experience;
  late final LessonRuntimeEngine runtime;
}

const _curriculumItems = [
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
    'microitem_for_teacher': 'Comparar frações com denominadores iguais',
  },
  {
    'order': 3,
    'marker': 'M3',
    'title': 'Soma de frações',
    'microitem_for_teacher': 'Somar frações com denominadores iguais',
  },
];

const _expectedPath = [
  (marker: 'M1', layer: LessonLayer.l1, signal: DecisionSignal.two),
  (marker: 'M1', layer: LessonLayer.l2, signal: DecisionSignal.two),
  (marker: 'M1', layer: LessonLayer.l3, signal: DecisionSignal.one),
  (marker: 'M2', layer: LessonLayer.l1, signal: DecisionSignal.two),
  (marker: 'M2', layer: LessonLayer.l2, signal: DecisionSignal.two),
  (marker: 'M2', layer: LessonLayer.l3, signal: DecisionSignal.one),
  (marker: 'M3', layer: LessonLayer.l1, signal: DecisionSignal.two),
  (marker: 'M3', layer: LessonLayer.l2, signal: DecisionSignal.two),
  (marker: 'M3', layer: LessonLayer.l3, signal: DecisionSignal.one),
];

void main() {
  test(
    'normal_lesson_full_completion_flow_test: login valido -> T00/T02 -> 3 itens x 3 layers -> conclusao com persistencia',
    () async {
      const lessonLocalId = 'normal-full-completion';
      var h = FullFlowHarness();

      final result = await h.experience.prepareStudentExperienceEntry(
        const StudentExperienceArgs(
          academic: 'fundamental',
          idioma: 'pt-BR',
          lessonLocalId: lessonLocalId,
          onboarding: {
            'objetivo': 'Aprender frações no fluxo normal',
            'free_text': 'Aprender frações no fluxo normal',
            'stable_lang': 'pt-BR',
            'academic_level': 'fundamental',
            'preferred_name': 'Ana',
          },
        ),
      );

      expect(result.destination, '/cyber/aula');
      await _waitUntil(
        () => h.service.read(lessonLocalId)?.curriculum?.items.length == 3,
      );
      expect(h.t00.requests, hasLength(1), reason: 'T00 deve ser chamado');
      expect(
        h.t00.requests.single.onboarding['stable_lang'],
        'pt-BR',
        reason: 'idioma escolhido deve governar o fluxo',
      );
      expect(h.t02.requests, isNotEmpty, reason: 'T02 deve preparar aula');

      var snap = await h.runtime.open(
        lessonLocalId: lessonLocalId,
        authReady: true,
        authed: true,
      );
      expect(snap.authReady, isTrue);
      expect(snap.authed, isTrue);
      expect(snap.hasCurriculum, isTrue);
      expect(snap.phase.type, ClassroomPhaseType.lendo);

      var totalRequests = h.t02.requests.length;
      var restoredOnce = false;

      for (var index = 0; index < _expectedPath.length; index++) {
        final step = _expectedPath[index];
        snap = h.runtime.snapshot();
        expect(snap.phase.type, ClassroomPhaseType.lendo);
        expect(snap.itemMarker, step.marker);
        expect(snap.conteudo?.explanation, isNotEmpty);
        expect(snap.conteudo?.question, isNotEmpty);
        expect(snap.conteudo?.options.keys, containsAll(AnswerLetter.values));
        expect(snap.imagem, isNull, reason: 'imagem nao deve bloquear texto');
        expect(
          h.service.read(lessonLocalId)?.audio.status,
          anyOf('idle', 'ready'),
          reason: 'audio nao deve bloquear a aula',
        );

        h.runtime.select(AnswerLetter.A);
        expect(h.runtime.snapshot().phase.letter, AnswerLetter.A);
        await h.runtime.signal(step.signal);

        var state = h.service.read(lessonLocalId)!;
        expect(state.attempts, hasLength(index + 1));
        expect(state.attempts.last.marker, step.marker);
        expect(state.attempts.last.layer, step.layer);
        expect(state.attempts.last.letra, AnswerLetter.A);
        expect(state.attempts.last.sinal, step.signal);
        expect(state.attempts.last.correct, isTrue);
        expect(
          state.events.map((event) => event.type),
          containsAll([
            'ANSWER_SUBMITTED',
            'STUDENT_DECISION_APPLIED',
            'STUDENT_EXECUTOR_APPLIED',
            'NEXT_ACTION_DECIDED',
          ]),
        );

        await h.runtime.advance();

        if (index == 3 && !restoredOnce) {
          final persisted = StudentLearningState.fromJson(
            h.service.read(lessonLocalId)!.toJson(),
          );
          expect(persisted.attempts, hasLength(4));
          expect(persisted.progress?.itemIdx, 1);
          expect(persisted.progress?.layer, LessonLayer.l2);

          totalRequests += h.t02.requests.length;
          h = FullFlowHarness(seed: {lessonLocalId: persisted});
          snap = await h.runtime.open(
            lessonLocalId: lessonLocalId,
            authReady: true,
            authed: true,
          );
          expect(snap.phase.type, ClassroomPhaseType.lendo);
          expect(snap.itemMarker, 'M2');
          expect(h.service.read(lessonLocalId)?.attempts, hasLength(4));
          restoredOnce = true;
        }
      }

      snap = h.runtime.snapshot();
      expect(snap.phase.type, ClassroomPhaseType.fim);
      expect(snap.isDone, isTrue);

      final finalState = h.service.read(lessonLocalId)!;
      expect(finalState.curriculum?.items, hasLength(3));
      expect(finalState.progress?.itemIdx, 3);
      expect(finalState.progress?.layer, LessonLayer.l1);
      expect(finalState.progress?.mainAdvances, greaterThanOrEqualTo(3));
      expect(finalState.progress?.pctAvanco, 100);
      expect(finalState.progress?.concluidos, containsAll(['M1', 'M2', 'M3']));
      expect(finalState.attempts, hasLength(9));
      expect(
        finalState.events.map((event) => event.type),
        contains('FINAL_COMPLETION_ALLOWED'),
      );
      expect(
        restoredOnce,
        isTrue,
        reason: 'estado deve sobreviver a reabertura',
      );
      expect(
        totalRequests + h.t02.requests.length,
        greaterThanOrEqualTo(9),
        reason: 'T02 deve ser chamado para aulas/layers do caminho normal',
      );
    },
  );
}

Future<void> _waitUntil(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  if (condition()) return;
  fail('condicao esperada nao ocorreu antes do timeout');
}
