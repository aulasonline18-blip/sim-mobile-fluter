import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/placement/placement_blocks.dart';
import 'package:sim_mobile/sim/placement/placement_payload.dart';
import 'package:sim_mobile/sim/placement/placement_route_controller.dart';
import 'package:sim_mobile/sim/placement/placement_state.dart';
import 'package:sim_mobile/sim/placement/placement_store.dart';
import 'package:sim_mobile/sim/placement/placement_t02_caller.dart';
import 'package:sim_mobile/sim/placement/student_placement_service.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

class FakePlacementT02 implements T02LessonClient {
  int placementCalls = 0;

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) async {
    placementCalls += 1;
    return T02LessonMaterial(
      explanation: 'Diagnostico',
      question: 'Qual alternativa mostra dominio?',
      options: const {
        AnswerLetter.A: 'Domino',
        AnswerLetter.B: 'Ainda nao',
        AnswerLetter.C: 'Nao sei',
      },
      correctAnswer: AnswerLetter.A,
      whyCorrect: 'A indica dominio.',
      whyWrong: null,
      generatedAt: DateTime.fromMillisecondsSinceEpoch(1),
      source: 'fake-placement',
    );
  }

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) =>
      placement(request);

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) =>
      placement(request);

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) =>
      placement(request);
}

StudentLearningState _placementState() {
  const items = [
    CurriculumItem(marker: 'M1', text: 'Base'),
    CurriculumItem(marker: 'M2', text: 'Intermediario'),
    CurriculumItem(marker: 'M3', text: 'Avancado'),
  ];
  return StudentLearningState.empty(lessonLocalId: 'cyber-placement').copyWith(
    profile: const StudentProfile(
      objetivo: 'Aprender algebra',
      stableLang: 'pt-BR',
      academicLevel: 'fundamental',
    ),
    curriculum: const StudentCurriculum(
      topic: 'Aprender algebra',
      totalItems: 3,
      generatedAt: null,
      provisional: false,
      items: items,
    ),
  );
}

void main() {
  test('scorePlacement starts at first failed marker', () {
    final blocks = createPretestBlocks(_placementState().curriculum!.items);
    final result = scorePlacement(
      blocks,
      [
        PlacementAnswer(
          blockId: blocks[0].id,
          marker: 'M1',
          choiceId: blocks[0].choices.first.id,
          correct: true,
          answeredAt: 1,
        ),
        PlacementAnswer(
          blockId: blocks[1].id,
          marker: 'M2',
          choiceId: blocks[1].choices.last.id,
          correct: false,
          answeredAt: 2,
        ),
      ],
      now: 3,
    );

    expect(result?.startMarker, 'M2');
    expect(result?.masteredMarkers, ['M1']);
    expect(result?.failedMarkers, ['M2']);
  });

  test('StudentPlacementService writes placement and mirrors legacy fields', () {
    final stateService = StudentLearningStateService(
      seed: {'cyber-placement': _placementState()},
    );
    final service = StudentPlacementService(
      stateService: stateService,
      lessonLocalId: 'cyber-placement',
    );
    final blocks = createPretestBlocks(_placementState().curriculum!.items);
    service.update(
      PlacementState.empty().copyWith(
        status: PlacementStatus.running,
        blocks: blocks,
        index: 1,
        source: 'fallback_limited',
        limited: true,
      ),
    );

    final state = stateService.read('cyber-placement')!;
    expect(service.read().status, PlacementStatus.running);
    expect(state.placement?['status'], 'running');
    expect(state.profile.extra['pretest_status'], 'running');
  });

  test('PlacementT02Caller returns one diagnostic block when enabled', () async {
    final t02 = FakePlacementT02();
    final caller = PlacementT02Caller(t02Client: t02, enabled: true);
    final context = buildPlacementContext(_placementState())!;

    final result = await caller.callPlacementT02(context);

    expect(t02.placementCalls, 1);
    expect(result?.blocks, hasLength(1));
    expect(result?.blocks.first.marker, 'M1');
  });

  test('PlacementRouteController runs choice intro question result flow', () async {
    final stateService = StudentLearningStateService(
      seed: {'cyber-placement': _placementState()},
    );
    final placementService = StudentPlacementService(
      stateService: stateService,
      lessonLocalId: 'cyber-placement',
    );
    final controller = PlacementRouteController(
      lessonLocalId: 'cyber-placement',
      stateService: stateService,
      store: PlacementStore(placementService),
      t02Caller: PlacementT02Caller(
        t02Client: FakePlacementT02(),
        enabled: true,
      ),
      enabled: true,
    );

    expect(controller.stage, PlacementLocalStage.choice);
    controller.chooseStart();
    expect(controller.stage, PlacementLocalStage.intro);
    await controller.startTest();
    expect(controller.stage, PlacementLocalStage.running);
    final firstChoice = controller.blocks.first.choices.first.id;
    controller.answer(firstChoice);

    expect(controller.stage, PlacementLocalStage.result);
    expect(placementService.read().status, PlacementStatus.done);
    controller.continueToAula();
    expect(controller.destination, '/cyber/aula');
  });
}
