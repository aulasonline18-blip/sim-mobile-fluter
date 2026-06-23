import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/learning_decision_engine.dart';
import 'package:sim_mobile/sim/state/mastery_truth_engine.dart';
import 'package:sim_mobile/sim/state/student_learning_governor.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

StudentLearningState _seedState() {
  const items = [
    CurriculumItem(marker: 'M1', text: 'Frações equivalentes'),
    CurriculumItem(marker: 'M2', text: 'Comparar frações'),
  ];
  return StudentLearningState.empty(lessonLocalId: 'lesson-1', now: 1).copyWith(
    curriculum: const StudentCurriculum(
      topic: 'Frações',
      totalItems: 2,
      generatedAt: 1,
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
  StudentLearningGovernor governor(StudentStateStore store) {
    store.writeState(_seedState());
    return StudentLearningGovernor(store: store);
  }

  test(
    'governor registra resposta, verdade e proxima acao em eventos canonicos',
    () {
      var ids = 0;
      final store = StudentStateStore(
        local: MemoryStudentStateLocalStorage(),
        now: () => 100 + ids,
        idFactory: () => 'evt-${ids++}',
      );
      final result = governor(store).submitAnswer(
        lessonLocalId: 'lesson-1',
        selected: AnswerLetter.A,
        correctAnswer: AnswerLetter.A,
        signal: DecisionSignal.one,
      );

      expect(result.answerEvent.type, 'ANSWER_SUBMITTED');
      expect(result.masteryEvent.type, 'MASTERY_EVALUATED');
      expect(result.decisionEvent.type, 'NEXT_ACTION_DECIDED');
      expect(result.mastery.status, MasteryStatus.learning);
      expect(
        result.nextAction.actionType,
        DecisionActionType.showCurrentLesson,
      );
      expect(store.getEventLog('lesson-1').map((event) => event.type), [
        'ANSWER_SUBMITTED',
        'MASTERY_EVALUATED',
        'NEXT_ACTION_DECIDED',
      ]);
    },
  );

  test('governor impede falsa maestria de virar avanco silencioso', () {
    var ids = 0;
    final store = StudentStateStore(
      local: MemoryStudentStateLocalStorage(),
      now: () => 200 + ids,
      idFactory: () => 'evt-${ids++}',
    );
    final result = governor(store).submitAnswer(
      lessonLocalId: 'lesson-1',
      selected: AnswerLetter.B,
      correctAnswer: AnswerLetter.A,
      signal: DecisionSignal.one,
    );

    expect(result.mastery.status, MasteryStatus.falseMastery);
    expect(result.state.progress?.itemIdx, 0);
    expect(result.state.progress?.layer, isNot(LessonLayer.l3));
    final truth = result.state.extra['truth'] as Map;
    expect(truth['false_mastery_flags'], contains('M1'));
  });

  test('governor acumula evidencias ate dominio real', () {
    var ids = 0;
    final store = StudentStateStore(
      local: MemoryStudentStateLocalStorage(),
      now: () => 300 + ids,
      idFactory: () => 'evt-${ids++}',
    );
    final gov = governor(store);

    gov.submitAnswer(
      lessonLocalId: 'lesson-1',
      selected: AnswerLetter.A,
      correctAnswer: AnswerLetter.A,
      signal: DecisionSignal.three,
    );
    gov.submitAnswer(
      lessonLocalId: 'lesson-1',
      selected: AnswerLetter.A,
      correctAnswer: AnswerLetter.A,
      signal: DecisionSignal.three,
    );
    final result = gov.submitAnswer(
      lessonLocalId: 'lesson-1',
      selected: AnswerLetter.A,
      correctAnswer: AnswerLetter.A,
      signal: DecisionSignal.three,
    );

    expect(result.mastery.status, MasteryStatus.mastered);
    expect(result.state.extra['truth'], isA<Map>());
    expect(store.getEventLog('lesson-1').length, 9);
  });
}
