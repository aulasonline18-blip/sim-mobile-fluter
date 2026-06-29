// MIRROR OF: src/sim/state/studentLessonExecutor.ts (Web, source of truth)
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
  final concluidosWithCurrent = marker != null && !concluidos.contains(marker)
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
            mainAdvances: [
              inputProgress.mainAdvances + 1,
              proposed,
            ].reduce((a, b) => a > b ? a : b),
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
          nextProgress: inputProgress.copyWith(layer: proposedLayer, erros: 0),
          applied: true,
        );
      }
      return ApplyDecisionResult(nextProgress: inputProgress, applied: false);
    case DecisionActionType.needsReinforcement:
      // F2.3: zera erros ao refazer (nao duplica concluido)
      return ApplyDecisionResult(
        nextProgress: inputProgress.copyWith(erros: 0),
        applied: true,
      );
    case DecisionActionType.showCurrentLesson:
    case DecisionActionType.waitForLessonText:
      return ApplyDecisionResult(nextProgress: inputProgress, applied: true);
    case DecisionActionType.noSafeDecision:
      return ApplyDecisionResult(nextProgress: inputProgress, applied: false);
  }
}

// D3: helper que monta STUDENT_EXECUTOR_ERROR
StudentLearningEvent _executorError(
  StudentLearningState state,
  String stage,
  int ts, [
  Map<String, Object?>? extra,
]) {
  return StudentLearningEvent(
    type: 'STUDENT_EXECUTOR_ERROR',
    ts: ts,
    payload: {
      'stage': stage,
      'lessonLocalId': state.lessonLocalId,
      'itemIdx': state.progress?.itemIdx,
      'layer': state.progress?.layer.value,
      ...?extra,
    },
  );
}

StudentLearningState processAnswerWithEngine(
  StudentLearningState state,
  AnswerContext context, {
  int? now,
}) {
  final ts = now ?? DateTime.now().millisecondsSinceEpoch;
  final curriculum = state.curriculum;
  final progress = state.progress;

  // D3 stage: no-active-lesson
  if (curriculum == null || progress == null) {
    return state.copyWith(
      events: [...state.events, _executorError(state, 'no-active-lesson', ts)],
    );
  }

  final idx = progress.itemIdx;

  // D3 stage: no-item
  if (idx < 0 || idx >= curriculum.items.length) {
    return state.copyWith(
      events: [
        ...state.events,
        _executorError(state, 'no-item', ts, {'idx': idx}),
      ],
    );
  }

  final item = curriculum.items[idx];
  final correct = context.letra == context.correctAnswer;
  final attempt = LessonAttempt(
    marker: item.marker,
    layer: progress.layer,
    letra: context.letra,
    sinal: context.sinal,
    correct: correct,
    ts: ts,
  );

  final newErros = correct ? progress.erros : progress.erros + 1;
  final newHistoria = (correct && context.sinal == DecisionSignal.one)
      ? [...progress.historia, item.marker]
      : progress.historia;

  final progressBeforeDecision = progress.copyWith(
    erros: newErros,
    historia: newHistoria,
  );
  final synth = state.copyWith(
    progress: progressBeforeDecision,
    attempts: [...state.attempts, attempt],
  );

  // D3 stage: decideNextActionFromState
  DecisionResult decision;
  try {
    decision = decideNextActionFromState(synth);
  } catch (e) {
    return state.copyWith(
      events: [
        ...state.events,
        _executorError(state, 'decideNextActionFromState', ts, {
          'error': e.toString(),
        }),
      ],
    );
  }

  // D3 stage: recordAttempt — apply decision
  ApplyDecisionResult applied;
  try {
    applied = applyStudentDecision(
      progressBeforeDecision,
      decision,
      itemIdx: idx,
      layer: progress.layer,
      totalItems: curriculum.items.length,
      marker: item.marker,
    );
  } catch (e) {
    return state.copyWith(
      events: [
        ...state.events,
        _executorError(state, 'recordAttempt', ts, {'error': e.toString()}),
      ],
    );
  }

  final decisionPayload = {
    'decision': decision.actionType.name,
    'appliedProgress': applied.nextProgress.toJson(),
    'ts': ts,
    'reason': decision.reason,
    'fromItemIdx': idx,
    'fromLayer': progress.layer.value,
    'toItemIdx': applied.nextProgress.itemIdx,
    'toLayer': applied.nextProgress.layer.value,
    'correct': correct,
    'sinal': context.sinal.value,
  };
  final decisionEvent = StudentLearningEvent(
    type: applied.applied
        ? 'STUDENT_DECISION_APPLIED'
        : 'STUDENT_DECISION_REJECTED',
    ts: ts,
    payload: decisionPayload,
  );
  final executorEvent = StudentLearningEvent(
    type: applied.applied
        ? 'STUDENT_EXECUTOR_APPLIED'
        : 'STUDENT_EXECUTOR_REJECTED',
    ts: ts,
    payload: decisionPayload,
  );

  const maxAttemptsCap = 300;
  const maxEventsCap = 500;
  final rawAttempts = [...state.attempts, attempt];
  final cappedAttempts = rawAttempts.length > maxAttemptsCap
      ? rawAttempts.sublist(rawAttempts.length - maxAttemptsCap)
      : rawAttempts;
  final rawEvents = [...state.events, decisionEvent, executorEvent];
  final cappedEvents = rawEvents.length > maxEventsCap
      ? rawEvents.sublist(rawEvents.length - maxEventsCap)
      : rawEvents;

  // D3 stage: upsertActive
  try {
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
      attempts: cappedAttempts,
      events: cappedEvents,
    );
  } catch (e) {
    return state.copyWith(
      events: [
        ...state.events,
        _executorError(state, 'upsertActive', ts, {'error': e.toString()}),
      ],
    );
  }
}
