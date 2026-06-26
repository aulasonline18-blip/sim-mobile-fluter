import 'student_learning_state.dart';

enum DecisionActionType {
  showCurrentLesson,
  advanceLayer,
  advanceItem,
  waitForLessonText,
  showCompletion,
  needsReinforcement,
  noSafeDecision,
}

enum DecisionConfidence { low, medium, high }

class DecisionResult {
  const DecisionResult({
    required this.actionType,
    required this.reason,
    required this.confidence,
    this.proposedItemIdx,
    this.proposedLayer,
    this.proposedMarker,
  });

  final DecisionActionType actionType;
  final String reason;
  final DecisionConfidence confidence;
  final int? proposedItemIdx;
  final LessonLayer? proposedLayer;
  final String? proposedMarker;
}

DecisionResult _noDecision(String reason) => DecisionResult(
  actionType: DecisionActionType.noSafeDecision,
  reason: reason,
  confidence: DecisionConfidence.low,
);

DecisionResult decideNextActionFromState(StudentLearningState? state) {
  try {
    if (state == null) return _noDecision('estado ausente');
    final curriculum = state.curriculum;
    if (curriculum == null || curriculum.items.isEmpty) {
      return _noDecision('sem curriculo valido');
    }

    final total = curriculum.items.length;
    final progress = state.progress;
    final current = state.current;
    final itemIdx = progress?.itemIdx ?? current?.itemIdx ?? 0;
    final layer = progress?.layer ?? current?.layer ?? LessonLayer.l1;

    if (itemIdx < 0) return _noDecision('itemIdx invalido');
    if (itemIdx >= total) {
      return const DecisionResult(
        actionType: DecisionActionType.showCompletion,
        reason: 'todos os itens do curriculo cobertos',
        confidence: DecisionConfidence.high,
      );
    }

    final completed = progress?.concluidos.toSet() ?? <String>{};
    final currentMarker = curriculum.items[itemIdx].marker.isNotEmpty
        ? curriculum.items[itemIdx].marker
        : current?.marker;

    if (currentMarker != null && completed.contains(currentMarker)) {
      final nextIdx = itemIdx + 1;
      if (nextIdx >= total) {
        return const DecisionResult(
          actionType: DecisionActionType.showCompletion,
          reason: 'ultimo item concluido',
          confidence: DecisionConfidence.high,
        );
      }
      return DecisionResult(
        actionType: DecisionActionType.advanceItem,
        reason: 'item atual ja em concluidos',
        confidence: DecisionConfidence.high,
        proposedItemIdx: nextIdx,
        proposedLayer: LessonLayer.l1,
        proposedMarker: curriculum.items[nextIdx].marker,
      );
    }

    final mastery = _masteryForMarker(state, currentMarker);
    if (mastery.mastered) {
      final nextIdx = itemIdx + 1;
      if (nextIdx >= total) {
        return const DecisionResult(
          actionType: DecisionActionType.showCompletion,
          reason: 'mastery confirmou dominio no ultimo item',
          confidence: DecisionConfidence.high,
        );
      }
      return DecisionResult(
        actionType: DecisionActionType.advanceItem,
        reason: 'mastery confirmou dominio -> proximo item',
        confidence: DecisionConfidence.high,
        proposedItemIdx: nextIdx,
        proposedLayer: LessonLayer.l1,
        proposedMarker: curriculum.items[nextIdx].marker,
      );
    }
    if (mastery.needsReinforcement) {
      return DecisionResult(
        actionType: DecisionActionType.needsReinforcement,
        reason: 'mastery indicou reforco necessario',
        confidence: DecisionConfidence.high,
        proposedItemIdx: itemIdx,
        proposedLayer: layer,
        proposedMarker: currentMarker,
      );
    }

    final lastForItem = state.attempts.reversed
        .cast<LessonAttempt?>()
        .firstWhere(
          (attempt) => attempt?.marker == currentMarker,
          orElse: () => null,
        );

    if (lastForItem != null && lastForItem.layer == layer) {
      if (layer == LessonLayer.l3) {
        if (!lastForItem.correct || lastForItem.sinal == DecisionSignal.three) {
          return DecisionResult(
            actionType: DecisionActionType.needsReinforcement,
            reason: 'L3 ainda nao consolidada -> refazer L3',
            confidence: DecisionConfidence.high,
            proposedItemIdx: itemIdx,
            proposedLayer: LessonLayer.l3,
            proposedMarker: currentMarker,
          );
        }
        final nextIdx = itemIdx + 1;
        if (nextIdx >= total) {
          return const DecisionResult(
            actionType: DecisionActionType.showCompletion,
            reason: 'L3 consolidada no ultimo item',
            confidence: DecisionConfidence.high,
          );
        }
        return DecisionResult(
          actionType: DecisionActionType.advanceItem,
          reason: 'L3 consolidada -> proximo item',
          confidence: DecisionConfidence.high,
          proposedItemIdx: nextIdx,
          proposedLayer: LessonLayer.l1,
          proposedMarker: curriculum.items[nextIdx].marker,
        );
      }

      if (layer == LessonLayer.l2) {
        if (!lastForItem.correct || lastForItem.sinal == DecisionSignal.three) {
          return DecisionResult(
            actionType: DecisionActionType.needsReinforcement,
            reason: 'L2 ainda fragil -> refazer L2',
            confidence: DecisionConfidence.high,
            proposedItemIdx: itemIdx,
            proposedLayer: LessonLayer.l2,
            proposedMarker: currentMarker,
          );
        }
        return DecisionResult(
          actionType: DecisionActionType.advanceLayer,
          reason: 'L2 consolidada -> propor L3',
          confidence: DecisionConfidence.high,
          proposedItemIdx: itemIdx,
          proposedLayer: LessonLayer.l3,
          proposedMarker: currentMarker,
        );
      }

      if (lastForItem.correct && lastForItem.sinal == DecisionSignal.one) {
        return DecisionResult(
          actionType: DecisionActionType.advanceLayer,
          reason: 'L1 dominada com certeza -> propor L3',
          confidence: DecisionConfidence.high,
          proposedItemIdx: itemIdx,
          proposedLayer: LessonLayer.l3,
          proposedMarker: currentMarker,
        );
      }

      return DecisionResult(
        actionType: DecisionActionType.advanceLayer,
        reason: 'L1 precisa de intermediacao -> propor L2',
        confidence: DecisionConfidence.high,
        proposedItemIdx: itemIdx,
        proposedLayer: LessonLayer.l2,
        proposedMarker: currentMarker,
      );
    }

    return DecisionResult(
      actionType: DecisionActionType.showCurrentLesson,
      reason: 'manter posicao corrente (sem evidencia para avancar)',
      confidence: DecisionConfidence.medium,
      proposedItemIdx: itemIdx,
      proposedLayer: layer,
      proposedMarker: currentMarker,
    );
  } catch (_) {
    return _noDecision('erro interno');
  }
}

class _MasteryDecisionSnapshot {
  const _MasteryDecisionSnapshot({
    required this.status,
    required this.needsReinforcement,
  });

  final String? status;
  final bool needsReinforcement;

  bool get mastered => status == 'mastered';
}

_MasteryDecisionSnapshot _masteryForMarker(
  StudentLearningState state,
  String? marker,
) {
  if (marker == null || marker.isEmpty) {
    return const _MasteryDecisionSnapshot(
      status: null,
      needsReinforcement: false,
    );
  }
  final truth = state.extra['truth'];
  if (truth is! Map) {
    return const _MasteryDecisionSnapshot(
      status: null,
      needsReinforcement: false,
    );
  }
  final consolidation = truth['item_consolidation_status'];
  final status = consolidation is Map
      ? consolidation[marker]?.toString()
      : null;
  var needsReinforcement = status == 'weak' || status == 'falseMastery';
  final evidence = truth['mastery_evidence'];
  if (evidence is List) {
    for (final item in evidence.reversed) {
      if (item is Map && item['marker_id']?.toString() == marker) {
        needsReinforcement = item['needs_reinforcement'] == true;
        break;
      }
    }
  }
  return _MasteryDecisionSnapshot(
    status: status,
    needsReinforcement: needsReinforcement,
  );
}
