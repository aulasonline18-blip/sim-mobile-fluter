// MIRROR OF: src/sim/state/studentLearningStateService.ts (Web, source of truth)
import 'dart:async';

import 'student_learning_state.dart';

typedef StudentStateMutator = StudentLearningState Function(
  StudentLearningState state,
);

// Resumo de aula para o drawer lateral (espelha CyberLessonSummary do Web)
class CyberLessonSummary {
  const CyberLessonSummary({
    required this.lessonLocalId,
    required this.tema,
    required this.idioma,
    required this.nivel,
    required this.totalItens,
    required this.itemIdx,
    required this.layer,
    required this.concluidos,
    required this.finalizada,
    required this.deleted,
    this.lessonCloudId,
    this.createdAt,
    this.updatedAt,
    this.markerAtual,
  });

  final String lessonLocalId;
  final String? lessonCloudId;
  final String tema;
  final String idioma;
  final String nivel;
  final int totalItens;
  final int itemIdx;
  final int layer;
  final int concluidos;
  final bool finalizada;
  final bool deleted;
  final String? markerAtual;
  final int? createdAt;
  final int? updatedAt;

  JsonMap toJson() => {
        'lessonLocalId': lessonLocalId,
        'lessonCloudId': lessonCloudId,
        'tema': tema,
        'idioma': idioma,
        'nivel': nivel,
        'totalItens': totalItens,
        'itemIdx': itemIdx,
        'layer': layer,
        'concluidos': concluidos,
        'finalizada': finalizada,
        'deleted': deleted,
        'markerAtual': markerAtual,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };
}

CyberLessonSummary? buildCyberLessonSummary(StudentLearningState state) {
  final profile = state.profile;
  final curriculum = state.curriculum;
  final progress = state.progress;
  final current = state.current;
  final items = curriculum?.items ?? const <CurriculumItem>[];
  final rawIdx = progress?.itemIdx ?? current?.itemIdx ?? 0;
  final itemIdx = rawIdx < 0 ? 0 : rawIdx;
  final deleted = state.extra['deletedAt'] != null ||
      (state.extra['syncInfo'] is Map &&
          (state.extra['syncInfo'] as Map)['deletedAt'] != null);
  final concluidosCount = [
    progress?.mainAdvances ?? 0,
    progress?.concluidos.length ?? 0,
  ].reduce((a, b) => a > b ? a : b);
  return CyberLessonSummary(
    lessonLocalId: state.lessonLocalId,
    lessonCloudId: state.lessonCloudId,
    tema: profile.objetivo ?? curriculum?.topic ?? 'Aula SIM',
    idioma: profile.language ?? profile.stableLang ?? '',
    nivel: profile.nivel ?? profile.academicLevel ?? 'incerto',
    totalItens: items.length > (progress?.totalItems ?? 0)
        ? items.length
        : progress?.totalItems ?? 0,
    itemIdx: itemIdx,
    layer: progress?.layer.value ?? current?.layer.value ?? 1,
    concluidos: concluidosCount,
    finalizada: state.extra['finalizada'] == true,
    markerAtual: current?.marker ??
        (itemIdx >= 0 && itemIdx < items.length
            ? items[itemIdx].marker
            : null),
    deleted: deleted,
    createdAt: state.createdAt > 0 ? state.createdAt : null,
    updatedAt: state.updatedAt > 0 ? state.updatedAt : null,
  );
}

class StudentLearningStateService {
  StudentLearningStateService({Map<String, StudentLearningState>? seed})
      : _states = Map.of(seed ?? const {});

  final Map<String, StudentLearningState> _states;
  final List<void Function(String)> _writeListeners = [];

  final Map<String, JsonMap> _onboardingDrafts = {};

  // F1.4: throttle de shadow decision por id (250ms)
  final Map<String, Timer> _shadowThrottle = {};
  void Function(String lessonLocalId)? _shadowDecisionRunner;

  void setShadowDecisionRunner(void Function(String) runner) {
    _shadowDecisionRunner = runner;
  }

  // I.8: subscribe to state writes.
  void Function() subscribe(void Function(String lessonLocalId) cb) {
    _writeListeners.add(cb);
    return () => _writeListeners.remove(cb);
  }

  // F1.3: filtra tombstone + F1.4: throttle shadow decision
  void _notifyWrite(String lessonLocalId) {
    final state = _states[lessonLocalId];
    if (state != null) {
      if (state.extra['deletedAt'] != null) return;
      if (state.extra['syncInfo'] is Map &&
          (state.extra['syncInfo'] as Map)['deletedAt'] != null) return;
    }

    _shadowThrottle[lessonLocalId]?.cancel();
    _shadowThrottle[lessonLocalId] = Timer(
      const Duration(milliseconds: 250),
      () {
        _shadowThrottle.remove(lessonLocalId);
        _shadowDecisionRunner?.call(lessonLocalId);
      },
    );

    for (final cb in List.of(_writeListeners)) {
      try {
        cb(lessonLocalId);
      } catch (_) {}
    }
  }

  StudentLearningState? read(String lessonLocalId) => _states[lessonLocalId];

  List<String> listLessonIds() => _states.keys.toList(growable: false);

  StudentLearningState ensure({
    required String lessonLocalId,
    String? userId,
  }) {
    return _states.putIfAbsent(
      lessonLocalId,
      () => StudentLearningState.empty(
        lessonLocalId: lessonLocalId,
        userId: userId,
      ),
    );
  }

  StudentLearningState write(StudentLearningState state) {
    _states[state.lessonLocalId] = state.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _notifyWrite(state.lessonLocalId);
    return _states[state.lessonLocalId]!;
  }

  StudentLearningState mutate(
    String lessonLocalId,
    StudentStateMutator mutator,
  ) {
    final current = ensure(lessonLocalId: lessonLocalId);
    return write(mutator(current));
  }

  StudentLearningState appendEvent(
    String lessonLocalId,
    StudentLearningEvent event, {
    int maxEvents = 500,
  }) {
    return mutate(lessonLocalId, (state) {
      final nextEvents = [...state.events, event];
      final trimmed = nextEvents.length > maxEvents
          ? nextEvents.sublist(nextEvents.length - maxEvents)
          : nextEvents;
      return state.copyWith(events: trimmed);
    });
  }

  StudentLearningState appendAttempt(
    String lessonLocalId,
    LessonAttempt attempt, {
    int maxAttempts = 300,
  }) {
    return mutate(lessonLocalId, (state) {
      final nextAttempts = [...state.attempts, attempt];
      final trimmed = nextAttempts.length > maxAttempts
          ? nextAttempts.sublist(nextAttempts.length - maxAttempts)
          : nextAttempts;
      return state.copyWith(attempts: trimmed);
    });
  }

  // F1.1 — funções portadas do Web

  void upsertOnboardingDraft(String draftId, JsonMap draft) {
    _onboardingDrafts[draftId] = {
      ...(_onboardingDrafts[draftId] ?? const {}),
      ...draft,
    };
  }

  StudentLearningState commitOnboarding(
    String lessonLocalId,
    String draftId,
  ) {
    final draft = _onboardingDrafts[draftId] ?? const {};
    return mutate(lessonLocalId, (state) {
      return state.copyWith(
        profile: state.profile.copyWith(
          objetivo: draft['objetivo'] as String? ?? state.profile.objetivo,
          language: draft['language'] as String? ?? state.profile.language,
          stableLang: draft['stableLang'] as String? ??
              draft['language'] as String? ??
              state.profile.stableLang,
          nivel: draft['nivel'] as String? ?? state.profile.nivel,
          academicLevel:
              draft['academicLevel'] as String? ?? state.profile.academicLevel,
          preferredName:
              draft['preferredName'] as String? ?? state.profile.preferredName,
          targetTopic:
              draft['targetTopic'] as String? ?? state.profile.targetTopic,
        ),
      );
    });
  }

  static String deriveLessonLocalId(String objetivo, String idioma) {
    final normalized =
        '${objetivo.trim().toLowerCase()}:${idioma.trim().toLowerCase()}';
    var hash = 5381;
    for (final unit in normalized.codeUnits) {
      hash = ((hash << 5) + hash) ^ unit;
      hash &= 0x7fffffff;
    }
    return 'sim-${hash.toRadixString(16).padLeft(8, '0')}';
  }

  static List<LessonAttempt> mergeAttempts(
    List<LessonAttempt> existing,
    List<LessonAttempt> incoming,
  ) {
    final byKey = <String, LessonAttempt>{};
    for (final attempt in [...existing, ...incoming]) {
      byKey.putIfAbsent(_attemptMergeKey(attempt), () => attempt);
    }
    return byKey.values.toList()..sort((a, b) => a.ts.compareTo(b.ts));
  }

  static String _attemptMergeKey(LessonAttempt a) =>
      '${a.marker}|${a.layer.value}|${a.letra.name}|${a.sinal.value}|${a.correct}|${a.ts}';

  static List<LessonAttempt> toMirroredAttempts(LessonProgress progress) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return progress.concluidos
        .map(
          (marker) => LessonAttempt(
            marker: marker,
            layer: LessonLayer.l3,
            letra: AnswerLetter.A,
            sinal: DecisionSignal.one,
            correct: true,
            ts: ts,
          ),
        )
        .toList();
  }

  static int progressRank(LessonProgress? progress) {
    if (progress == null) return 0;
    return progress.mainAdvances * 100000 +
        progress.itemIdx * 1000 +
        progress.layer.value * 100;
  }

  static int compareRank(
    StudentLearningState a,
    StudentLearningState b,
  ) {
    final diff = progressRank(a.progress) - progressRank(b.progress);
    if (diff != 0) return diff;
    return a.updatedAt - b.updatedAt;
  }

  static List<String> unionStrings(List<String> a, List<String> b) {
    final seen = <String>{};
    final result = <String>[];
    for (final s in [...a, ...b]) {
      if (seen.add(s)) result.add(s);
    }
    return result;
  }

  static JsonMap mergeDefinedRecords(JsonMap a, JsonMap b) {
    final result = JsonMap.of(a);
    for (final entry in b.entries) {
      if (entry.value != null) result.putIfAbsent(entry.key, () => entry.value);
    }
    return result;
  }

  List<CyberLessonSummary> buildAllSummaries() {
    return listLessonIds()
        .map(read)
        .whereType<StudentLearningState>()
        .map(buildCyberLessonSummary)
        .whereType<CyberLessonSummary>()
        .toList();
  }
}
