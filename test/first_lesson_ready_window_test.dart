import 'package:flutter_test/flutter_test.dart';
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
  int calls = 0;

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    calls += 1;
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
}
