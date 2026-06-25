import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/learning_decision_engine.dart';
import 'package:sim_mobile/sim/state/live_entry_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';
import 'package:sim_mobile/sim/state/student_lesson_executor.dart';

StudentLearningState _state({
  LessonLayer layer = LessonLayer.l1,
  List<LessonAttempt> attempts = const [],
  JsonMap extra = const {},
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
    extra: extra,
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

  test('LearningDecisionEngine opens support only after 3 recent aggravants',
      () {
    const twoAggravants = [
      LessonAttempt(
        marker: 'M1',
        layer: LessonLayer.l1,
        letra: AnswerLetter.A,
        sinal: DecisionSignal.three,
        correct: true,
        ts: 1,
      ),
      LessonAttempt(
        marker: 'M1',
        layer: LessonLayer.l1,
        letra: AnswerLetter.B,
        sinal: DecisionSignal.one,
        correct: false,
        ts: 2,
      ),
    ];

    expect(
      decideNextActionFromState(_state(attempts: twoAggravants)).actionType,
      isNot(DecisionActionType.sendToSupport),
    );

    final decision = decideNextActionFromState(
      _state(
        attempts: const [
          ...twoAggravants,
          LessonAttempt(
            marker: 'M2',
            layer: LessonLayer.l1,
            letra: AnswerLetter.C,
            sinal: DecisionSignal.one,
            correct: false,
            ts: 3,
          ),
        ],
      ),
    );

    expect(decision.actionType, DecisionActionType.sendToSupport);
  });

  test('LearningDecisionEngine does not loop support after max attempts', () {
    final decision = decideNextActionFromState(
      _state(
        attempts: const [
          LessonAttempt(
            marker: 'M1',
            layer: LessonLayer.l1,
            letra: AnswerLetter.A,
            sinal: DecisionSignal.three,
            correct: true,
            ts: 1,
          ),
          LessonAttempt(
            marker: 'M1',
            layer: LessonLayer.l1,
            letra: AnswerLetter.B,
            sinal: DecisionSignal.three,
            correct: true,
            ts: 2,
          ),
          LessonAttempt(
            marker: 'M1',
            layer: LessonLayer.l1,
            letra: AnswerLetter.C,
            sinal: DecisionSignal.one,
            correct: false,
            ts: 3,
          ),
        ],
        extra: const {
          'support': {'support_attempt_count': 2},
        },
      ),
    );

    expect(decision.actionType, isNot(DecisionActionType.sendToSupport));
  });

  test('StudentLessonExecutor records support state when engine requests it',
      () {
    final next = processAnswerWithEngine(
      _state(
        attempts: const [
          LessonAttempt(
            marker: 'M1',
            layer: LessonLayer.l1,
            letra: AnswerLetter.A,
            sinal: DecisionSignal.three,
            correct: true,
            ts: 1,
          ),
          LessonAttempt(
            marker: 'M1',
            layer: LessonLayer.l1,
            letra: AnswerLetter.B,
            sinal: DecisionSignal.one,
            correct: false,
            ts: 2,
          ),
        ],
      ),
      const AnswerContext(
        letra: AnswerLetter.C,
        sinal: DecisionSignal.three,
        correctAnswer: AnswerLetter.A,
      ),
      now: 3,
    );

    final support = next.extra['support'] as Map;
    expect(support['active'], true);
    expect(support['support_attempt_count'], 1);
    expect(support['return_snapshot'], isA<Map>());
    expect(
        next.events.map((event) => event.type), contains('SUPPORT_TRIGGERED'));
    expect(next.events.map((event) => event.type), contains('SUPPORT_STARTED'));
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
