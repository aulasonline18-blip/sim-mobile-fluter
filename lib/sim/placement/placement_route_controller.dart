import '../experience/student_experience_store.dart';
import '../experience/student_experience_types.dart';
import '../state/student_learning_state_service.dart';
import 'placement_blocks.dart';
import 'placement_payload.dart';
import 'placement_screens.dart';
import 'placement_state.dart';
import 'placement_store.dart';
import 'placement_t02_caller.dart';

enum PlacementLocalStage { choice, intro, running, result, redirectToAula }

class PlacementRouteController {
  PlacementRouteController({
    required this.lessonLocalId,
    required this.stateService,
    required this.store,
    required this.t02Caller,
    required this.enabled,
  }) {
    final initial = store.readPlacement();
    blocks = initial.blocks;
    answers = initial.answers;
    result = initial.result;
    index = _resumePlacementIndex(initial);
    stage = switch (initial.status) {
      PlacementStatus.running => PlacementLocalStage.running,
      PlacementStatus.done when initial.result != null => PlacementLocalStage.result,
      _ => enabled ? PlacementLocalStage.choice : PlacementLocalStage.redirectToAula,
    };
  }

  final String lessonLocalId;
  final StudentLearningStateService stateService;
  final PlacementStore store;
  final PlacementT02Caller t02Caller;
  final bool enabled;

  late PlacementLocalStage stage;
  List<PlacementBlock> blocks = const [];
  List<PlacementAnswer> answers = const [];
  int index = 0;
  PlacementResult? result;
  bool starting = false;

  String? get destination {
    return stage == PlacementLocalStage.redirectToAula ? '/cyber/aula' : null;
  }

  PlacementChoiceScreenModel choiceScreen() => const PlacementChoiceScreenModel();

  PlacementIntroScreenModel introScreen() => const PlacementIntroScreenModel();

  PlacementQuestionScreenModel? questionScreen() {
    if (index < 0 || index >= blocks.length) return null;
    final block = blocks[index];
    return PlacementQuestionScreenModel(
      questionOfKey: 'placement_question_of',
      prompt: block.prompt,
      choiceLabels: block.choices.map((choice) => choice.label).toList(),
    );
  }

  PlacementResultScreenModel? resultScreen() {
    final current = result;
    return current == null
        ? null
        : PlacementResultScreenModel(startMarker: current.startMarker);
  }

  void skip() {
    store.resetPlacement();
    store.writePlacement(
      PlacementStoreState(
        pretestStatus: PlacementStatus.skipped,
        startMarker: null,
        pretestFinishedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    publishStudentExperienceEvent(
      stateService,
      lessonLocalId,
      StudentExperienceEventType.placementStartFromZeroClicked,
      {'route': '/cyber/aula'},
    );
    stage = PlacementLocalStage.redirectToAula;
  }

  void chooseStart() {
    store.writePlacement(
      PlacementStoreState(
        pretestStatus: PlacementStatus.intro,
        pretestStartedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    stage = PlacementLocalStage.intro;
  }

  Future<void> startTest() async {
    if (starting) return;
    starting = true;
    try {
      final context = buildPlacementContext(stateService.read(lessonLocalId));
      if (context == null) {
        blocks = const [];
      } else {
        final t02 = await t02Caller.callPlacementT02(context);
        blocks = t02?.blocks.isNotEmpty == true
            ? t02!.blocks
            : createPretestBlocks(context.curriculumItems);
        final source = t02?.blocks.isNotEmpty == true ? 't02' : 'fallback_limited';
        answers = [];
        index = 0;
        result = null;
        store.writePlacement(
          PlacementStoreState(
            pretestStatus: PlacementStatus.running,
            pretestBlocks: blocks,
            pretestAnswers: answers,
            pretestResult: null,
            startMarker: null,
            pretestIndex: 0,
            pretestSource: source,
            pretestLimited: source == 'fallback_limited',
            pretestStartedAt: DateTime.now().millisecondsSinceEpoch,
          ),
        );
      }
      stage = PlacementLocalStage.running;
    } finally {
      starting = false;
    }
  }

  void answer(String choiceId) {
    if (index < 0 || index >= blocks.length) return;
    final block = blocks[index];
    final choice = block.choices
        .where((candidate) => candidate.id == choiceId)
        .firstOrNull;
    if (choice == null) return;
    final next = PlacementAnswer(
      blockId: block.id,
      marker: block.marker,
      choiceId: choice.id,
      correct: choice.correct,
      answeredAt: DateTime.now().millisecondsSinceEpoch,
    );
    answers = [...answers, next];
    if (index + 1 < blocks.length) {
      index += 1;
      store.writePlacement(
        PlacementStoreState(
          pretestStatus: PlacementStatus.running,
          pretestAnswers: answers,
          pretestIndex: index,
        ),
      );
      return;
    }

    store.writePlacement(
      const PlacementStoreState(pretestStatus: PlacementStatus.scoring),
    );
    result = scorePlacement(blocks, answers);
    store.writePlacement(
      PlacementStoreState(
        pretestStatus: PlacementStatus.done,
        pretestAnswers: answers,
        pretestResult: result,
        startMarker: result?.startMarker,
        pretestIndex: index,
        pretestFinishedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    stage = PlacementLocalStage.result;
  }

  void continueToAula() {
    publishStudentExperienceEvent(
      stateService,
      lessonLocalId,
      StudentExperienceEventType.placementContinueToAula,
      {'route': '/cyber/aula'},
    );
    stage = PlacementLocalStage.redirectToAula;
  }

  int _resumePlacementIndex(PlacementState initial) {
    final blocksCount = initial.blocks.length;
    final raw = initial.index;
    final byAnswers = initial.answers.length;
    final value = raw.isFinite ? raw : byAnswers;
    final max = blocksCount - 1;
    if (max < 0) return 0;
    return value.clamp(0, max);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
