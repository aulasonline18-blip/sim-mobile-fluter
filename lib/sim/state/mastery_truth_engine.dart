import 'student_learning_state.dart';

enum MasteryStatus {
  notStarted,
  learning,
  consolidating,
  mastered,
  weak,
  reviewNeeded,
  falseMastery,
}

class MasteryEvidence {
  const MasteryEvidence({
    required this.marker,
    required this.status,
    required this.reason,
    required this.score,
    required this.consecutiveCorrect,
    required this.consecutiveWrong,
    required this.attemptCount,
    required this.needsReview,
    required this.needsReinforcement,
  });

  final String marker;
  final MasteryStatus status;
  final String reason;
  final int score;
  final int consecutiveCorrect;
  final int consecutiveWrong;
  final int attemptCount;
  final bool needsReview;
  final bool needsReinforcement;

  JsonMap toJson() => {
    'marker_id': marker,
    'status': status.name,
    'reason': reason,
    'score': score,
    'consecutive_correct': consecutiveCorrect,
    'consecutive_wrong': consecutiveWrong,
    'attempt_count': attemptCount,
    'needs_review': needsReview,
    'needs_reinforcement': needsReinforcement,
  };
}

class MasteryTruthEngine {
  const MasteryTruthEngine();

  MasteryEvidence evaluateMarker(
    StudentLearningState state,
    String marker, {
    bool reviewed = false,
    bool recovered = false,
  }) {
    final attempts =
        state.attempts.where((attempt) => attempt.marker == marker).toList()
          ..sort((a, b) => a.ts.compareTo(b.ts));

    if (attempts.isEmpty) {
      return MasteryEvidence(
        marker: marker,
        status: MasteryStatus.notStarted,
        reason: 'sem tentativa registrada',
        score: 0,
        consecutiveCorrect: 0,
        consecutiveWrong: 0,
        attemptCount: 0,
        needsReview: false,
        needsReinforcement: false,
      );
    }

    final consecutiveCorrect = _consecutive(attempts, correct: true);
    final consecutiveWrong = _consecutive(attempts, correct: false);
    final score = attempts.fold<int>(0, (total, attempt) {
      if (attempt.correct) {
        return total +
            switch (attempt.sinal) {
              DecisionSignal.one => 1,
              DecisionSignal.two => 2,
              DecisionSignal.three => 3,
            };
      }
      return total -
          switch (attempt.sinal) {
            DecisionSignal.one => 3,
            DecisionSignal.two => 2,
            DecisionSignal.three => 1,
          };
    });
    final last = attempts.last;
    final hadWrong = attempts.any((attempt) => !attempt.correct);
    final hadCorrect = attempts.any((attempt) => attempt.correct);

    if (!last.correct && last.sinal == DecisionSignal.one) {
      return MasteryEvidence(
        marker: marker,
        status: MasteryStatus.falseMastery,
        reason: 'erro com sinal facil indica falsa maestria',
        score: score,
        consecutiveCorrect: consecutiveCorrect,
        consecutiveWrong: consecutiveWrong,
        attemptCount: attempts.length,
        needsReview: true,
        needsReinforcement: true,
      );
    }

    if (consecutiveWrong >= 2) {
      return MasteryEvidence(
        marker: marker,
        status: MasteryStatus.weak,
        reason: 'erro repetido duas vezes',
        score: score,
        consecutiveCorrect: consecutiveCorrect,
        consecutiveWrong: consecutiveWrong,
        attemptCount: attempts.length,
        needsReview: false,
        needsReinforcement: true,
      );
    }

    if ((reviewed || recovered) && last.correct) {
      return MasteryEvidence(
        marker: marker,
        status: MasteryStatus.mastered,
        reason: reviewed
            ? 'item revisado e acertado'
            : 'item recuperado e acertado',
        score: score,
        consecutiveCorrect: consecutiveCorrect,
        consecutiveWrong: consecutiveWrong,
        attemptCount: attempts.length,
        needsReview: false,
        needsReinforcement: false,
      );
    }

    if (consecutiveCorrect >= 3) {
      return MasteryEvidence(
        marker: marker,
        status: MasteryStatus.mastered,
        reason: 'tres acertos consecutivos',
        score: score,
        consecutiveCorrect: consecutiveCorrect,
        consecutiveWrong: consecutiveWrong,
        attemptCount: attempts.length,
        needsReview: false,
        needsReinforcement: false,
      );
    }

    if (consecutiveCorrect >= 2 &&
        attempts.reversed
            .take(2)
            .every(
              (attempt) =>
                  attempt.correct && attempt.sinal == DecisionSignal.three,
            )) {
      return MasteryEvidence(
        marker: marker,
        status: MasteryStatus.consolidating,
        reason:
            'dois acertos difíceis consecutivos consolidam, mas nao dominam',
        score: score,
        consecutiveCorrect: consecutiveCorrect,
        consecutiveWrong: consecutiveWrong,
        attemptCount: attempts.length,
        needsReview: true,
        needsReinforcement: false,
      );
    }

    if (hadWrong && hadCorrect && last.correct) {
      return MasteryEvidence(
        marker: marker,
        status: MasteryStatus.consolidating,
        reason: 'houve erro e depois acerto',
        score: score,
        consecutiveCorrect: consecutiveCorrect,
        consecutiveWrong: consecutiveWrong,
        attemptCount: attempts.length,
        needsReview: true,
        needsReinforcement: false,
      );
    }

    if (hadWrong && !last.correct) {
      return MasteryEvidence(
        marker: marker,
        status: MasteryStatus.weak,
        reason: 'erro atual ainda nao reparado',
        score: score,
        consecutiveCorrect: consecutiveCorrect,
        consecutiveWrong: consecutiveWrong,
        attemptCount: attempts.length,
        needsReview: false,
        needsReinforcement: true,
      );
    }

    if (last.correct) {
      return MasteryEvidence(
        marker: marker,
        status: MasteryStatus.learning,
        reason: 'um acerto isolado nao prova dominio',
        score: score,
        consecutiveCorrect: consecutiveCorrect,
        consecutiveWrong: consecutiveWrong,
        attemptCount: attempts.length,
        needsReview: true,
        needsReinforcement: false,
      );
    }

    return MasteryEvidence(
      marker: marker,
      status: MasteryStatus.reviewNeeded,
      reason: 'evidencia insuficiente',
      score: score,
      consecutiveCorrect: consecutiveCorrect,
      consecutiveWrong: consecutiveWrong,
      attemptCount: attempts.length,
      needsReview: true,
      needsReinforcement: false,
    );
  }

  StudentLearningState writeTruthToState(
    StudentLearningState state,
    MasteryEvidence evidence,
  ) {
    final truth = JsonMap.from(
      state.extra['truth'] is Map ? state.extra['truth'] as Map : const {},
    );
    final consolidation = JsonMap.from(
      truth['item_consolidation_status'] is Map
          ? truth['item_consolidation_status'] as Map
          : const {},
    );
    consolidation[evidence.marker] = evidence.status.name;
    final falseFlags = _stringList(truth['false_mastery_flags']);
    final retestFlags = _stringList(truth['needs_retest_flags']);
    final masteryEvidence = [
      ...(truth['mastery_evidence'] is List
          ? truth['mastery_evidence'] as List
          : const []),
      evidence.toJson(),
    ];
    if (evidence.status == MasteryStatus.falseMastery &&
        !falseFlags.contains(evidence.marker)) {
      falseFlags.add(evidence.marker);
    }
    if (evidence.needsReview && !retestFlags.contains(evidence.marker)) {
      retestFlags.add(evidence.marker);
    }
    return state.copyWith(
      extra: {
        ...state.extra,
        'truth': {
          ...truth,
          'mastery_evidence': masteryEvidence,
          'false_mastery_flags': falseFlags,
          'needs_retest_flags': retestFlags,
          'item_consolidation_status': consolidation,
        },
      },
    );
  }

  int _consecutive(List<LessonAttempt> attempts, {required bool correct}) {
    var count = 0;
    for (final attempt in attempts.reversed) {
      if (attempt.correct != correct) break;
      count += 1;
    }
    return count;
  }

  List<String> _stringList(Object? value) {
    return (value is List ? value : const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
}
