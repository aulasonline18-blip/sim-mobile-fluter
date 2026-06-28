import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/learning_decision_engine.dart';
import 'package:sim_mobile/sim/state/live_entry_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';
import 'package:sim_mobile/sim/state/student_lesson_executor.dart';

StudentLearningState _state({
  LessonLayer layer = LessonLayer.l1,
  List<LessonAttempt> attempts = const [],
}) {
  const items = [
    CurriculumItem(marker: 'M1', text: 'Item 1'),
    CurriculumItem(marker: 'M2', text: 'Item 2'),
  ];
  return StudentLearningState.empty(lessonLocalId: 'cyber-test').copyWith(
    curriculum: const StudentCurriculum(
      topic: 'Matematica',
      totalItems: 2,
      generatedAt: null,
      provisional: false,
      items: items,
    ),
    current: LessonCurrent(
      itemIdx: 0,
      marker: 'M1',
      layer: layer,
      amparoLvl: 0,
    ),
    progress: LessonProgress(
      itemIdx: 0,
      layer: layer,
      erros: 0,
      amparoLvl: 0,
      historia: const [],
      mainAdvances: 0,
      concluidos: const [],
      pendentesMarkers: const [],
      totalItems: 2,
      pctAvanco: 0,
    ),
    attempts: attempts,
  );
}

void main() {
  test('LearningDecisionEngine preserves L1 correct signal 1 -> L3', () {
    final state = _state(
      attempts: const [
        LessonAttempt(
          marker: 'M1',
          layer: LessonLayer.l1,
          letra: AnswerLetter.A,
          sinal: DecisionSignal.one,
          correct: true,
          ts: 1,
        ),
      ],
    );

    final decision = decideNextActionFromState(state);

    expect(decision.actionType, DecisionActionType.advanceLayer);
    expect(decision.proposedLayer, LessonLayer.l3);
  });

  test('LearningDecisionEngine uses mastery truth for reinforcement', () {
    final state = _state().copyWith(
      extra: const {
        'truth': {
          'item_consolidation_status': {'M1': 'falseMastery'},
          'mastery_evidence': [
            {
              'marker_id': 'M1',
              'status': 'falseMastery',
              'needs_reinforcement': true,
            },
          ],
        },
      },
    );

    final decision = decideNextActionFromState(state);

    expect(decision.actionType, DecisionActionType.needsReinforcement);
    expect(decision.proposedMarker, 'M1');
  });

  test('LearningDecisionEngine uses mastered truth to advance item', () {
    final state = _state().copyWith(
      extra: const {
        'truth': {
          'item_consolidation_status': {'M1': 'mastered'},
          'mastery_evidence': [
            {
              'marker_id': 'M1',
              'status': 'mastered',
              'needs_reinforcement': false,
            },
          ],
        },
      },
    );

    final decision = decideNextActionFromState(state);

    expect(decision.actionType, DecisionActionType.advanceItem);
    expect(decision.proposedItemIdx, 1);
    expect(decision.proposedMarker, 'M2');
  });

  test('LearningDecisionEngine prefers typed truth over legacy extra', () {
    final state = _state().copyWith(
      truth: const StudentMasteryTruth(
        itemConsolidationStatus: {'M1': 'mastered'},
        masteryEvidence: [
          {
            'marker_id': 'M1',
            'status': 'mastered',
            'needs_reinforcement': false,
          },
        ],
      ),
      extra: const {
        'truth': {
          'item_consolidation_status': {'M1': 'falseMastery'},
          'mastery_evidence': [
            {
              'marker_id': 'M1',
              'status': 'falseMastery',
              'needs_reinforcement': true,
            },
          ],
        },
      },
    );

    final decision = decideNextActionFromState(state);

    expect(decision.actionType, DecisionActionType.advanceItem);
    expect(decision.proposedMarker, 'M2');
  });

  test('StudentLessonExecutor applies answer without legacy fallback', () {
    final next = processAnswerWithEngine(
      _state(),
      const AnswerContext(
        letra: AnswerLetter.A,
        sinal: DecisionSignal.one,
        correctAnswer: AnswerLetter.A,
      ),
      now: 10,
    );

    expect(next.progress?.layer, LessonLayer.l3);
    expect(next.events.last.type, 'STUDENT_EXECUTOR_APPLIED');
  });

  test('LiveEntry does not regress after first lesson is ready', () {
    final service = StudentLearningStateService();
    updateLiveEntryState(
      service,
      'cyber-test',
      status: LiveEntryStatus.firstLessonReady,
    );

    final entry = updateLiveEntryState(
      service,
      'cyber-test',
      status: LiveEntryStatus.t02FirstLessonRunning,
    );

    expect(entry.status, LiveEntryStatus.firstLessonReady);
  });
}
