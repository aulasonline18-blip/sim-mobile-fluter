import 'learning_decision_engine.dart';
import 'mastery_truth_engine.dart';
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
            mainAdvances: [inputProgress.mainAdvances + 1, proposed]
                .reduce((a, b) => a > b ? a : b),
            pctAvanco:
                totalItems == 0 ? 0 : ((proposed / totalItems) * 100).round(),
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

  final progressBeforeDecision =
      correct ? progress : progress.copyWith(erros: progress.erros + 1);
  final synth = state.copyWith(
    progress: progressBeforeDecision,
    attempts: [...state.attempts, attempt],
  );
  final decision = decideNextActionFromState(synth);
  final mastery = const MasteryTruthEngine().evaluateMarker(synth, item.marker);
  final withTruth =
      const MasteryTruthEngine().writeTruthToState(synth, mastery);
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
  final attemptEvent = StudentLearningEvent(
    type: 'ATTEMPT_RECORDED',
    ts: ts,
    payload: {
      'marker': item.marker,
      'itemIdx': idx,
      'layer': progress.layer.value,
      'letra': context.letra.name,
      'sinal': context.sinal.value,
      'correct': correct,
      'attempt': attempt.toJson(),
    },
  );
  final masteryEvent = StudentLearningEvent(
    type: 'MASTERY_EVALUATED',
    ts: ts,
    payload: mastery.toJson(),
  );
  final decisionEvent = StudentLearningEvent(
    type: 'NEXT_ACTION_DECIDED',
    ts: ts,
    payload: {
      'action_type': decision.actionType.name,
      'reason': decision.reason,
      'confidence': decision.confidence.name,
      'proposed_item_idx': decision.proposedItemIdx,
      'proposed_layer': decision.proposedLayer?.value,
      'proposed_marker': decision.proposedMarker,
      'marker': item.marker,
      'layer': progress.layer.value,
    },
  );
  final reviewQueueEvent = mastery.needsReview ||
          decision.actionType == DecisionActionType.advanceLayer
      ? StudentLearningEvent(
          type: 'REVIEW_QUEUE_PREPARED',
          ts: ts,
          payload: {
            'marker': item.marker,
            'itemIdx': idx,
            'layer': progress.layer.value,
            'signal': context.sinal.value,
            'kind': 'light',
            'reason': mastery.reason,
          },
        )
      : null;
  final recoveryRequiredEvent = mastery.needsReinforcement ||
          decision.actionType == DecisionActionType.needsReinforcement
      ? StudentLearningEvent(
          type: 'RECOVERY_REQUIRED',
          ts: ts,
          payload: {
            'marker': item.marker,
            'itemIdx': idx,
            'layer': progress.layer.value,
            'recoveryLayer': LessonLayer.l1.value,
            'signal': context.sinal.value,
            'kind': 'repair',
            'reason': decision.reason,
          },
        )
      : null;
  final auxRooms = _nextAuxRooms(
    withTruth.auxRooms,
    marker: item.marker,
    itemIdx: idx,
    layer: progress.layer,
    decision: decision,
    mastery: mastery,
    attempt: attempt,
  );

  return withTruth.copyWith(
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
      attemptEvent,
      masteryEvent,
      decisionEvent,
      if (reviewQueueEvent != null) reviewQueueEvent,
      if (recoveryRequiredEvent != null) recoveryRequiredEvent,
      event,
    ],
    auxRooms: auxRooms,
  );
}

JsonMap? _nextAuxRooms(
  JsonMap? current, {
  required String marker,
  required int itemIdx,
  required LessonLayer layer,
  required DecisionResult decision,
  required MasteryEvidence mastery,
  required LessonAttempt attempt,
}) {
  final next = JsonMap.from(current ?? const {});
  final reviewQueue = _jsonList(next['review_queue']);
  final recoveryQueue = _jsonList(next['recovery_queue']);
  final shouldReview = mastery.needsReview ||
      decision.actionType == DecisionActionType.advanceLayer;
  final shouldRecover = mastery.needsReinforcement ||
      decision.actionType == DecisionActionType.needsReinforcement;
  if (shouldReview) {
    _appendUniqueQueueItem(
      reviewQueue,
      marker: marker,
      itemIdx: itemIdx,
      layer: layer,
      reason: mastery.reason,
      attempt: attempt,
    );
    _appendPendingReview(
      next,
      marker: marker,
      itemIdx: itemIdx,
      layer: layer,
      attempt: attempt,
      reason: mastery.reason,
    );
  }
  if (shouldRecover) {
    _appendUniqueQueueItem(
      recoveryQueue,
      marker: marker,
      itemIdx: itemIdx,
      layer: LessonLayer.l1,
      reason: decision.reason,
      attempt: attempt,
    );
    _appendPendingRecovery(
      next,
      marker: marker,
      itemIdx: itemIdx,
      attempt: attempt,
      reason: decision.reason,
    );
  }
  next['review_queue'] = reviewQueue;
  next['recovery_queue'] = recoveryQueue;
  final review = JsonMap.from(
    next['review'] is Map ? next['review'] as Map : const {},
  );
  review['currentQueue'] =
      reviewQueue.map((entry) => entry['marker']).whereType<String>().toList();
  review['entries'] = reviewQueue;
  review['updatedAt'] = attempt.ts;
  next['review'] = review;
  final recovery = JsonMap.from(
    next['recovery'] is Map ? next['recovery'] as Map : const {},
  );
  recovery['currentQueue'] = recoveryQueue
      .map((entry) => entry['marker'])
      .whereType<String>()
      .toList();
  recovery['entries'] = recoveryQueue;
  recovery['updatedAt'] = attempt.ts;
  next['recovery'] = recovery;
  next['next_action'] = decision.actionType.name;
  next['reason'] = decision.reason;
  next['marker'] = marker;
  next['layer'] = layer.value;
  return next;
}

void _appendPendingReview(
  JsonMap auxRooms, {
  required String marker,
  required int itemIdx,
  required LessonLayer layer,
  required LessonAttempt attempt,
  required String reason,
}) {
  final pending = _jsonList(auxRooms['pendingMap']);
  final existingIndex = pending.indexWhere(
    (entry) =>
        entry['marker'] == marker &&
        entry['layer'] == layer.value &&
        entry['status'] == 'pending',
  );
  final entry = {
    'marker': marker,
    'itemIdx': itemIdx,
    'layer': layer.value,
    'signal': DecisionSignal.two.value,
    'reason': reason,
    'kind': 'light',
    'firstRegisteredAt': existingIndex >= 0
        ? pending[existingIndex]['firstRegisteredAt']
        : attempt.ts,
    'lastUpdatedAt': attempt.ts,
    'clearedAt': null,
    'status': 'pending',
  };
  if (existingIndex >= 0) {
    pending[existingIndex] = entry;
  } else {
    pending.add(entry);
  }
  auxRooms['pendingMap'] = pending;
}

void _appendPendingRecovery(
  JsonMap auxRooms, {
  required String marker,
  required int itemIdx,
  required LessonAttempt attempt,
  required String reason,
}) {
  final pending = _jsonList(auxRooms['pendingMap']);
  final existingIndex = pending.indexWhere(
    (entry) =>
        entry['marker'] == marker &&
        entry['layer'] == LessonLayer.l1.value &&
        entry['status'] == 'pending' &&
        (entry['signal'] as num?)?.toInt() == DecisionSignal.three.value,
  );
  final entry = {
    'marker': marker,
    'itemIdx': itemIdx,
    'layer': LessonLayer.l1.value,
    'originalLayer': attempt.layer.value,
    'signal': DecisionSignal.three.value,
    'reason': reason,
    'kind': 'repair',
    'firstRegisteredAt': existingIndex >= 0
        ? pending[existingIndex]['firstRegisteredAt']
        : attempt.ts,
    'lastUpdatedAt': attempt.ts,
    'clearedAt': null,
    'status': 'pending',
  };
  if (existingIndex >= 0) {
    pending[existingIndex] = entry;
  } else {
    pending.add(entry);
  }
  auxRooms['pendingMap'] = pending;
}

List<JsonMap> _jsonList(Object? value) {
  return (value is List ? value : const [])
      .whereType<Map>()
      .map((item) => JsonMap.from(item))
      .toList();
}

void _appendUniqueQueueItem(
  List<JsonMap> queue, {
  required String marker,
  required int itemIdx,
  required LessonLayer layer,
  required String reason,
  required LessonAttempt attempt,
}) {
  if (queue.any(
    (item) => item['marker'] == marker && item['layer'] == layer.value,
  )) {
    return;
  }
  queue.add({
    'marker': marker,
    'itemIdx': itemIdx,
    'layer': layer.value,
    'signals': [attempt.sinal.value],
    'signal': attempt.sinal.value,
    'kind': attempt.sinal == DecisionSignal.two ? 'light' : 'repair',
    'reason': reason,
    'attempt': attempt.toJson(),
    'ts': attempt.ts,
  });
}
