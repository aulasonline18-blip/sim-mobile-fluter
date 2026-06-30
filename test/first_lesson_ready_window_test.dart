import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/experience/student_experience_engine.dart';
import 'package:sim_mobile/sim/experience/student_experience_t00_adapter.dart';
import 'package:sim_mobile/sim/experience/student_experience_t02_adapter.dart';
import 'package:sim_mobile/sim/experience/student_experience_types.dart';
import 'package:sim_mobile/sim/lesson/dopamine_ready_window_engine.dart';
import 'package:sim_mobile/sim/lesson/lesson_event_bus.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/lesson/lesson_orchestrator.dart';
import 'package:sim_mobile/sim/lesson/student_lesson_material_service.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/live_entry_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

class FakeT02Client implements T02LessonClient {
  FakeT02Client({this.visualTrigger});

  final JsonMap? visualTrigger;
  int calls = 0;
  final requests = <T02LessonRequest>[];

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    calls += 1;
    requests.add(request);
    return T02LessonMaterial(
      explanation: 'Explicacao de ${request.item}',
      question: 'Pergunta?',
      options: const {
        AnswerLetter.A: 'A certa',
        AnswerLetter.B: 'B errada',
        AnswerLetter.C: 'C errada',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'Porque sim.',
      whyWrong: null,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'fake-t02',
      visualTrigger: visualTrigger,
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

class AuditT00Client implements T00BootstrapClient {
  AuditT00Client({required this.releaseFinal});

  final Completer<void> releaseFinal;
  final requests = <T00BootstrapRequest>[];

  @override
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request) async* {
    requests.add(request);
    yield const T00BootstrapChunk(
      type: 't00_item_partial',
      payload: {
        'item': {
          'order': 1,
          'marker': 'M1',
          'title': 'Frações',
          'microitem_for_teacher': 'Entender metade e um quarto',
        },
      },
    );
    await releaseFinal.future;
    yield const T00BootstrapChunk(
      type: 't00_final',
      payload: {
        'curriculum': [
          {
            'order': 1,
            'marker': 'M1',
            'title': 'Frações',
            'microitem_for_teacher': 'Entender metade e um quarto',
          },
        ],
      },
    );
  }
}

class AuditT02Client implements T02LessonClient {
  final requests = <T02LessonRequest>[];
  final l2 = Completer<T02LessonMaterial>();
  final l3 = Completer<T02LessonMaterial>();

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) {
    requests.add(request);
    return switch (request.layer) {
      LessonLayer.l1 => Future.value(_material(request)),
      LessonLayer.l2 => l2.future,
      LessonLayer.l3 => l3.future,
    };
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

  T02LessonMaterial _material(T02LessonRequest request) => T02LessonMaterial(
    explanation: 'Explicacao ${request.layer.name}',
    question: 'Pergunta ${request.layer.name}?',
    options: const {
      AnswerLetter.A: 'A certa',
      AnswerLetter.B: 'B errada',
      AnswerLetter.C: 'C errada',
    },
    correctAnswer: AnswerLetter.A,
    whyCorrect: 'Porque sim.',
    whyWrong: const {'B': 'nao', 'C': 'nao'},
    generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
    source: 'audit-t02',
  );
}

StudentLearningState _stateWithCurriculum() {
  const items = [
    CurriculumItem(marker: 'M1', text: 'Item 1'),
    CurriculumItem(marker: 'M2', text: 'Item 2'),
  ];
  return StudentLearningState.empty(lessonLocalId: 'cyber-ready').copyWith(
    profile: const StudentProfile(
      objetivo: 'Objetivo',
      stableLang: 'pt',
      academicLevel: 'fundamental',
    ),
    curriculum: const StudentCurriculum(
      topic: 'Objetivo',
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

void main() {
  test('LessonMaterialCache keeps only three living lessons', () {
    final cache = LessonMaterialCache(maxLessons: 3);
    for (var i = 0; i < 4; i++) {
      cache.put(
        'k$i',
        CompleteLesson(
          conteudo: LessonContent(
            explanation: 'E$i',
            question: 'Q',
            options: const {
              AnswerLetter.A: 'A',
              AnswerLetter.B: 'B',
              AnswerLetter.C: 'C',
            },
            correctAnswer: AnswerLetter.A,
          ),
          imagem: null,
          audioText: 'E$i. Q',
        ),
      );
    }

    expect(cache.peek('k0'), isNull);
    expect(cache.peek('k1'), isNotNull);
    expect(cache.peek('k3'), isNotNull);
  });

  test(
    'LessonOrchestrator carries T02 visual_trigger into free SVG image',
    () async {
      final trigger = <String, dynamic>{
        'needs_image': true,
        'pedagogical_need': 'clarify_spatial',
        'render_strategy': 'software',
        'svg_payload':
            '<svg viewBox="0 0 10 10"><rect width="10" height="10"/></svg>',
      };
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(visualTrigger: trigger),
        cache: cache,
        bus: bus,
      );
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-visual',
        item: 'Plano cartesiano',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      );
      final key = lessonKeyFor(params);
      final updates = <CompleteLesson>[];
      final unsubscribe = bus.subscribe(key, updates.add);
      addTearDown(unsubscribe);

      final textLesson = await orchestrator.prefetchCompleteLesson(
        params,
        priority: 'active',
      );
      await Future<void>.delayed(Duration.zero);

      expect(textLesson.conteudo.visualTrigger, trigger);
      expect(updates.first.conteudo.visualTrigger, trigger);
      final rendered = updates.last.imagem ?? cache.peek(key)?.imagem;
      expect(rendered, startsWith('data:image/svg+xml;utf8,'));
      expect(rendered, contains('%3Csvg'));
    },
  );

  test(
    'LessonOrchestrator renders math_template from visual_trigger',
    () async {
      final trigger = <String, dynamic>{
        'needs_image': true,
        'pedagogical_need': 'important',
        'render_strategy': 'software',
        'topic': 'função linear',
        'math_template': {
          'name': 'linear_function',
          'params': {
            'a': 2,
            'b': 1,
            'x_min': -3,
            'x_max': 3,
            'labels': {'title': 'y = 2x + 1'},
          },
        },
      };
      final cache = LessonMaterialCache();
      final bus = LessonEventBus();
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(visualTrigger: trigger),
        cache: cache,
        bus: bus,
      );
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-math-template',
        item: 'Função linear',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      );
      final key = lessonKeyFor(params);
      final updates = <CompleteLesson>[];
      final unsubscribe = bus.subscribe(key, updates.add);
      addTearDown(unsubscribe);

      await orchestrator.prefetchCompleteLesson(params, priority: 'active');
      await Future<void>.delayed(Duration.zero);

      final rendered = updates.last.imagem ?? cache.peek(key)?.imagem;
      expect(rendered, startsWith('data:image/svg+xml;utf8,'));
      expect(Uri.decodeComponent(rendered!), contains('y = 2'));
    },
  );

  test('review and recovery requests preserve visual_trigger', () async {
    final trigger = <String, dynamic>{
      'needs_image': true,
      'pedagogical_need': 'important',
      'render_strategy': 'software',
      'svg_payload':
          '<svg viewBox="0 0 10 10"><line x1="1" y1="1" x2="9" y2="9"/></svg>',
    };
    final t02 = FakeT02Client(visualTrigger: trigger);
    final orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    );

    final review = await orchestrator.prefetchCompleteLesson(
      const CompleteLessonParams(
        lessonLocalId: 'cyber-review',
        item: 'Revisão de função',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l2,
        mode: LessonMode.reforco,
        marker: 'M1',
      ),
      priority: 'active',
    );
    final recovery = await orchestrator.prefetchCompleteLesson(
      const CompleteLessonParams(
        lessonLocalId: 'cyber-recovery',
        item: 'Recuperação de função',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.amparo,
        amparoLvl: 1,
        marker: 'M1',
      ),
      priority: 'active',
    );

    expect(t02.requests.map((request) => request.mode), [
      LessonMode.reforco.name,
      LessonMode.amparo.name,
    ]);
    expect(review.conteudo.visualTrigger, trigger);
    expect(recovery.conteudo.visualTrigger, trigger);
  });

  test(
    'background prefetch does not create paid image without student action',
    () async {
      final trigger = <String, dynamic>{
        'needs_image': true,
        'pedagogical_need': 'important',
        'render_strategy': 'ai',
        'topic': 'coração humano realista',
        'image_prompt': 'foto realista de um coração humano',
      };
      final cache = LessonMaterialCache();
      final orchestrator = LessonOrchestrator(
        t02Client: FakeT02Client(visualTrigger: trigger),
        cache: cache,
        bus: LessonEventBus(),
      );
      const params = CompleteLessonParams(
        lessonLocalId: 'cyber-paid-bg',
        item: 'Sistema circulatório',
        lang: 'pt-BR',
        academic: 'fundamental',
        layer: LessonLayer.l1,
        mode: LessonMode.session,
        marker: 'M1',
      );
      final key = lessonKeyFor(params);

      final lesson = await orchestrator.prefetchCompleteLesson(
        params,
        priority: 'background',
      );
      await Future<void>.delayed(Duration.zero);

      expect(lesson.conteudo.visualTrigger, trigger);
      expect(cache.peek(key)?.imagem, isNull);
    },
  );

  test('DopamineReadyWindowEngine prepares A/B/C slots from state', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-ready': _stateWithCurriculum()},
    );
    final t02 = FakeT02Client();
    final orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    );
    final engine = DopamineReadyWindowEngine(
      service: service,
      orchestrator: orchestrator,
    );

    final result = await engine.runDopamineReadyWindowFromStudentState(
      lessonLocalId: 'cyber-ready',
      source: 'test',
      maxSlots: 3,
    );

    expect(result, [true, true, true]);
    expect(t02.calls, 3);
    expect(service.read('cyber-ready')?.readyLessonMaterials.length, 3);
  });

  test('StudentExperienceT02Adapter prepares first minimum lesson', () async {
    final service = StudentLearningStateService(
      seed: {'cyber-ready': _stateWithCurriculum()},
    );
    final t02 = FakeT02Client();
    final orchestrator = LessonOrchestrator(
      t02Client: t02,
      cache: LessonMaterialCache(),
      bus: LessonEventBus(),
    );
    final readyWindow = DopamineReadyWindowEngine(
      service: service,
      orchestrator: orchestrator,
    );
    final materialService = StudentLessonMaterialService(
      stateService: service,
      orchestrator: orchestrator,
      readyWindowEngine: readyWindow,
    );
    final adapter = StudentExperienceT02Adapter(
      service: service,
      materialService: materialService,
    );
    final first = FirstCurriculumItem(
      curriculum: service.read('cyber-ready')!.curriculum!,
      item: service.read('cyber-ready')!.curriculum!.items.first,
      itemIndex: 0,
      marker: 'M1',
    );

    await adapter.prepareFirstMinimumLesson(
      args: const StudentExperienceArgs(
        academic: 'fundamental',
        idioma: 'pt-BR',
        lessonLocalId: 'cyber-ready',
        onboarding: {'objetivo': 'Objetivo'},
      ),
      first: first,
    );

    final state = service.read('cyber-ready');
    expect(state?.current?.marker, 'M1');
    expect(
      readLiveEntryState(service, 'cyber-ready').status,
      LiveEntryStatus.firstLessonReady,
    );
    expect(state?.readyLessonMaterials.values.first['text_status'], 'ready');
    expect(
      state?.events.map((event) => event.type),
      contains('LESSON_TEXT_READY'),
    );
  });

  test(
    'Teste 1: onboarding abre primeira aula no primeiro parcial e prepara B/C em background',
    () async {
      final service = StudentLearningStateService();
      final releaseFinal = Completer<void>();
      final t00 = AuditT00Client(releaseFinal: releaseFinal);
      final t02 = AuditT02Client();
      final orchestrator = LessonOrchestrator(
        t02Client: t02,
        cache: LessonMaterialCache(),
        bus: LessonEventBus(),
      );
      final readyWindow = DopamineReadyWindowEngine(
        service: service,
        orchestrator: orchestrator,
      );
      final materialService = StudentLessonMaterialService(
        stateService: service,
        orchestrator: orchestrator,
        readyWindowEngine: readyWindow,
      );
      final engine = StudentExperienceEngine(
        service: service,
        t00: StudentExperienceT00Adapter(service: service, client: t00),
        t02: StudentExperienceT02Adapter(
          service: service,
          materialService: materialService,
        ),
        placement: const SettledPlacementReader(settled: true),
      );

      final result = await engine.prepareStudentExperienceEntry(
        const StudentExperienceArgs(
          academic: 'fundamental',
          idioma: 'pt-BR',
          lessonLocalId: 'cyber-audit-1',
          onboarding: {
            'objetivo': 'Aprender frações',
            'stable_lang': 'pt-BR',
            'academic_level': 'fundamental',
            'preferred_name': 'Ana',
            'student_profile_internal': {'pace': 'visual'},
          },
        ),
      );

      expect(result.destination, '/cyber/aula');
      expect(t00.requests, hasLength(1));
      expect(t02.requests, isNotEmpty);
      final firstRequest = t02.requests.first;
      expect(firstRequest.item, 'Entender metade e um quarto');
      expect(firstRequest.marker, 'M1');
      expect(firstRequest.layer, LessonLayer.l1);
      expect(firstRequest.lang, 'pt-BR');
      expect(firstRequest.academic, 'fundamental');
      expect(firstRequest.profile['stable_lang'], 'pt-BR');
      expect(firstRequest.profile['academic_level'], 'fundamental');
      expect(firstRequest.profile['student_profile_internal'], {
        'pace': 'visual',
      });

      final openedState = service.read('cyber-audit-1');
      final openedProgressEvents = openedState?.events
          .where((event) => event.type == 'PROGRESS_UPDATED')
          .map((event) => event.payload['event'])
          .toList();
      expect(openedState?.curriculum?.items, hasLength(1));
      expect(openedState?.currentLessonMaterial?['text_status'], 'ready');
      expect(openedState?.current?.marker, 'M1');
      expect(
        openedProgressEvents,
        isNot(contains('t00FinalCurriculumReceived')),
      );
      expect(openedProgressEvents, contains('t00FirstItemReceived'));
      expect(
        openedState?.events.map((event) => event.type),
        contains('BACKGROUND_READY_WINDOW_STARTED'),
      );

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        t02.requests.where((request) => request.layer == LessonLayer.l2),
        hasLength(1),
      );

      t02.l2.complete(t02._material(t02.requests.last));
      await Future<void>.delayed(Duration.zero);
      expect(
        t02.requests.where((request) => request.layer == LessonLayer.l3),
        hasLength(1),
      );
      t02.l3.complete(t02._material(t02.requests.last));
      await Future<void>.delayed(Duration.zero);

      final beforeFinal = service.read('cyber-audit-1');
      final beforeFinalProgressEvents = beforeFinal?.events
          .where((event) => event.type == 'PROGRESS_UPDATED')
          .map((event) => event.payload['event'])
          .toList();
      expect(
        beforeFinalProgressEvents,
        isNot(contains('t00FinalCurriculumReceived')),
      );
      expect(
        beforeFinal?.readyLessonMaterials.keys,
        containsAll(['M1::L1::l1', 'M1::L2::l2', 'M1::L3::l3']),
      );

      releaseFinal.complete();
    },
  );
}
