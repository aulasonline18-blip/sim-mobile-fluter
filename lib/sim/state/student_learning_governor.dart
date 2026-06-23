import 'learning_decision_engine.dart';
import 'mastery_truth_engine.dart';
import 'student_learning_state.dart';
import 'student_lesson_executor.dart';
import 'student_state_store.dart';

class GovernedAnswerResult {
  const GovernedAnswerResult({
    required this.state,
    required this.mastery,
    required this.nextAction,
    required this.answerEvent,
    required this.masteryEvent,
    required this.decisionEvent,
  });

  final StudentLearningState state;
  final MasteryEvidence mastery;
  final DecisionResult nextAction;
  final CanonicalLearningEvent answerEvent;
  final CanonicalLearningEvent masteryEvent;
  final CanonicalLearningEvent decisionEvent;
}

class StudentLearningGovernor {
  StudentLearningGovernor({
    required this.store,
    this.truthEngine = const MasteryTruthEngine(),
  });

  final StudentStateStore store;
  final MasteryTruthEngine truthEngine;

  GovernedAnswerResult submitAnswer({
    required String lessonLocalId,
    required AnswerLetter selected,
    required AnswerLetter correctAnswer,
    required DecisionSignal signal,
    String source = 'student-learning-governor',
  }) {
    final before = store.readState(lessonLocalId);
    final view = activeLessonView(before);
    if (view == null || view.item == null || view.ended) {
      throw StateError('Nao ha aula ativa para registrar resposta.');
    }

    final correct = selected == correctAnswer;
    final attempt = LessonAttempt(
      marker: view.item!.marker,
      layer: view.layer,
      letra: selected,
      sinal: signal,
      correct: correct,
      ts: store.now(),
    );
    final answerEvent = store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: 'ANSWER_SUBMITTED',
      source: source,
      payload: {
        'marker': view.item!.marker,
        'itemIdx': view.itemIdx,
        'layer': view.layer.value,
        'selected_answer': selected.name,
        'correct_answer': correctAnswer.name,
        'is_correct': correct,
        'confidence_signal': signal.value,
        'attempt': attempt.toJson(),
      },
      mutate: (state, event) => processAnswerWithEngine(
        state,
        AnswerContext(
          letra: selected,
          sinal: signal,
          correctAnswer: correctAnswer,
        ),
        now: attempt.ts,
      ),
    );

    final answered = store.readState(lessonLocalId);
    final mastery = truthEngine.evaluateMarker(answered, view.item!.marker);
    final masteryEvent = store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: 'MASTERY_EVALUATED',
      source: source,
      payload: mastery.toJson(),
      mutate: (state, _) => truthEngine.writeTruthToState(state, mastery),
    );

    final nextAction = decideNextActionFromState(
      store.readState(lessonLocalId),
    );
    final decisionEvent = store.appendEvent(
      lessonLocalId: lessonLocalId,
      type: 'NEXT_ACTION_DECIDED',
      source: source,
      payload: {
        'action_type': nextAction.actionType.name,
        'reason': nextAction.reason,
        'confidence': nextAction.confidence.name,
        'proposed_item_idx': nextAction.proposedItemIdx,
        'proposed_layer': nextAction.proposedLayer?.value,
        'proposed_marker': nextAction.proposedMarker,
      },
    );

    return GovernedAnswerResult(
      state: store.readState(lessonLocalId),
      mastery: mastery,
      nextAction: nextAction,
      answerEvent: answerEvent,
      masteryEvent: masteryEvent,
      decisionEvent: decisionEvent,
    );
  }
}
