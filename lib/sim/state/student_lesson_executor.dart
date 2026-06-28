import 'learning_decision_engine.dart';
import 'student_learning_state.dart';

class StudentLessonView {
  const StudentLessonView({
    required this.itemIdx,
    required this.layer,
    required this.erros,
    required this.historia,
    required this.mainAdvances,
    required this.item,
    required this.totalItems,
    required this.ended,
  });

  final int itemIdx;
  final LessonLayer layer;
  final int erros;
  final List<String> historia;
  final int mainAdvances;
  final CurriculumItem? item;
  final int totalItems;
  final bool ended;
}

class AnswerContext {
  const AnswerContext({
    required this.letra,
    required this.sinal,
    required this.correctAnswer,
  });

  final AnswerLetter letra;
  final DecisionSignal sinal;
  final AnswerLetter correctAnswer;
}

class ApplyDecisionResult {
  const ApplyDecisionResult({
    required this.nextProgress,
    required this.applied,
  });

  final LessonProgress nextProgress;
  final bool applied;
}

StudentLessonView? activeLessonView(StudentLearningState state) {
  final curriculum = state.curriculum;
  final progress = state.progress;
  if (curriculum == null || progress == null) return null;
  final idx = progress.itemIdx;
  final total = curriculum.items.length;
  return StudentLessonView(
    itemIdx: idx,
    layer: progress.layer,
    erros: progress.erros,
    historia: progress.historia,
    mainAdvances: progress.mainAdvances,
    item: idx >= 0 && idx < total ? curriculum.items[idx] : null,
    totalItems: total,
    ended: total > 0 && idx >= total,
  );
}

ApplyDecisionResult applyStudentDecision(
  LessonProgress inputProgress,
  DecisionResult decision, {
  required int itemIdx,
  required LessonLayer layer,
  required int totalItems,
  String? marker,
}) {
  final concluidos = inputProgress.concluidos;
  final concluidosWithCurrent =
      marker != null && !concluidos.contains(marker)
          ? [...concluidos, marker]
          : concluidos;

  switch (decision.actionType) {
    case DecisionActionType.showCompletion:
      return ApplyDecisionResult(
        nextProgress: inputProgress.copyWith(
          itemIdx: totalItems,
          layer: LessonLayer.l1,
          erros: 0,
          concluidos: concluidosWithCurrent,
          mainAdvances: totalItems,
          pctAvanco: 100,
        ),
        applied: true,
      );
    case DecisionActionType.advanceItem:
      final proposed = decision.proposedItemIdx;
      if (proposed != null && proposed > itemIdx) {
        return ApplyDecisionResult(
          nextProgress: inputProgress.copyWith(
            itemIdx: proposed,
            layer: LessonLayer.l1,
            erros: 0,
            concluidos: concluidosWithCurrent,
            mainAdvances: [inputProgress.mainAdvances + 1, proposed]
                .reduce((a, b) => a > b ? a : b),
            pctAvanco: totalItems == 0
                ? 0
                : ((proposed / totalItems) * 100).round(),
          ),
          applied: true,
        );
      }
      return ApplyDecisionResult(nextProgress: inputProgress, applied: false);
    case DecisionActionType.advanceLayer:
      final proposedLayer = decision.proposedLayer;
      if (proposedLayer != null) {
        return ApplyDecisionResult(
          nextProgress: inputProgress.copyWith(
            layer: proposedLayer,
            erros: 0,
          ),
          applied: true,
        );
      }
      return ApplyDecisionResult(nextProgress: inputProgress, applied: false);
    case DecisionActionType.showCurrentLesson:
    case DecisionActionType.needsReinforcement:
    case DecisionActionType.waitForLessonText:
      return ApplyDecisionResult(nextProgress: inputProgress, applied: true);
    case DecisionActionType.noSafeDecision:
      return ApplyDecisionResult(nextProgress: inputProgress, applied: false);
  }
}

StudentLearningState processAnswerWithEngine(
  StudentLearningState state,
  AnswerContext context, {
  int? now,
}) {
  final curriculum = state.curriculum;
  final progress = state.progress;
  if (curriculum == null || progress == null) return state;
  final idx = progress.itemIdx;
  if (idx < 0 || idx >= curriculum.items.length) return state;

  final item = curriculum.items[idx];
  final correct = context.letra == context.correctAnswer;
  final ts = now ?? DateTime.now().millisecondsSinceEpoch;
  final attempt = LessonAttempt(
    marker: item.marker,
    layer: progress.layer,
    letra: context.letra,
    sinal: context.sinal,
    correct: correct,
    ts: ts,
  );

  final newErros = correct ? progress.erros : progress.erros + 1;

  final progressBeforeDecision = correct
      ? progress
      : progress.copyWith(erros: newErros);
  final synth = state.copyWith(
    progress: progressBeforeDecision,
    attempts: [...state.attempts, attempt],
  );
  final decision = decideNextActionFromState(synth);
  final applied = applyStudentDecision(
    progressBeforeDecision,
    decision,
    itemIdx: idx,
    layer: progress.layer,
    totalItems: curriculum.items.length,
    marker: item.marker,
  );

  final event = StudentLearningEvent(
    type: applied.applied
        ? 'STUDENT_EXECUTOR_APPLIED'
        : 'STUDENT_EXECUTOR_REJECTED',
    ts: ts,
    payload: {
      'action': decision.actionType.name,
      'reason': decision.reason,
      'fromItemIdx': idx,
      'fromLayer': progress.layer.value,
      'toItemIdx': applied.nextProgress.itemIdx,
      'toLayer': applied.nextProgress.layer.value,
      'correct': correct,
      'sinal': context.sinal.value,
    },
  );

  return state.copyWith(
    updatedAt: ts,
    progress: applied.nextProgress,
    current: LessonCurrent(
      itemIdx: applied.nextProgress.itemIdx,
      marker: applied.nextProgress.itemIdx < curriculum.items.length
          ? curriculum.items[applied.nextProgress.itemIdx].marker
          : null,
      layer: applied.nextProgress.layer,
      amparoLvl: applied.nextProgress.amparoLvl,
    ),
    attempts: [...state.attempts, attempt],
    events: [
      ...state.events,
      event,
    ],
  );
}
