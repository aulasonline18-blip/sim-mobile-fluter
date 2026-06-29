import 'dart:async';

import 'student_learning_state.dart';
import 'student_learning_state_service.dart';
import 'student_state_store.dart';

/// Adapter que exp?e StudentStateStore com a interface de
/// StudentLearningStateService.
///
/// Permite migrar gradualmente os m?dulos existentes sem alterar suas
/// assinaturas enquanto o StudentStateStore passa a ser a fonte can?nica.
class StudentStateStoreAdapter implements StudentLearningStateService {
  StudentStateStoreAdapter(this._store, {this.onWrite});

  final StudentStateStore _store;
  void Function(String lessonLocalId)? onWrite;
  final List<void Function(String)> _writeListeners = [];
  final Set<String> _knownLessonIds = {};
  final Map<String, JsonMap> _onboardingDrafts = {};
  final Map<String, Timer> _shadowThrottle = {};
  void Function(String lessonLocalId)? _shadowDecisionRunner;

  @override
  void Function() subscribe(void Function(String lessonLocalId) cb) {
    _writeListeners.add(cb);
    return () => _writeListeners.remove(cb);
  }

  @override
  void setShadowDecisionRunner(void Function(String lessonLocalId) runner) {
    _shadowDecisionRunner = runner;
  }

  void _notifyWrite(String lessonLocalId) {
    final state = _store.readState(lessonLocalId);
    if (_isDeleted(state)) return;

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

  @override
  StudentLearningState? read(String lessonLocalId) {
    _knownLessonIds.add(lessonLocalId);
    final state = _store.readState(lessonLocalId);
    if (_isCompatiblyEmpty(state)) return null;
    return state;
  }

  @override
  List<String> listLessonIds() {
    return _knownLessonIds.toList(growable: false);
  }

  @override
  StudentLearningState ensure({required String lessonLocalId, String? userId}) {
    _knownLessonIds.add(lessonLocalId);
    final state = _store.readState(lessonLocalId);
    if (userId == null || state.userId == userId) return state;
    return _store.writeState(state.copyWith(userId: userId));
  }

  @override
  StudentLearningState write(StudentLearningState state) {
    _knownLessonIds.add(state.lessonLocalId);
    final saved = _store.writeState(state);
    onWrite?.call(saved.lessonLocalId);
    _notifyWrite(saved.lessonLocalId);
    return saved;
  }

  @override
  StudentLearningState mutate(
    String lessonLocalId,
    StudentStateMutator mutator,
  ) {
    _knownLessonIds.add(lessonLocalId);
    final saved = _store.patchState(lessonLocalId, mutator);
    _notifyWrite(lessonLocalId);
    return saved;
  }

  @override
  StudentLearningState appendEvent(
    String lessonLocalId,
    StudentLearningEvent event, {
    int maxEvents = 500,
  }) {
    _store.appendEvent(
      lessonLocalId: lessonLocalId,
      type: event.type,
      payload: event.payload,
      source: 'legacy-adapter',
      userId: _store.readState(lessonLocalId).userId,
    );
    return _trimLegacyEventsIfNeeded(lessonLocalId, maxEvents);
  }

  @override
  StudentLearningState appendAttempt(
    String lessonLocalId,
    LessonAttempt attempt, {
    int maxAttempts = 300,
  }) {
    return _store.patchState(lessonLocalId, (state) {
      final nextAttempts = [...state.attempts, attempt];
      final trimmed = nextAttempts.length > maxAttempts
          ? nextAttempts.sublist(nextAttempts.length - maxAttempts)
          : nextAttempts;
      return state.copyWith(attempts: trimmed);
    });
  }

  @override
  void upsertOnboardingDraft(String draftId, JsonMap draft) {
    _onboardingDrafts[draftId] = {
      ...(_onboardingDrafts[draftId] ?? const {}),
      ...draft,
    };
  }

  @override
  StudentLearningState commitOnboarding(String lessonLocalId, String draftId) {
    final draft = _onboardingDrafts[draftId] ?? const {};
    return mutate(lessonLocalId, (state) {
      return state.copyWith(
        profile: state.profile.copyWith(
          objetivo: draft['objetivo'] as String? ?? state.profile.objetivo,
          language: draft['language'] as String? ?? state.profile.language,
          stableLang:
              draft['stableLang'] as String? ??
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

  @override
  List<CyberLessonSummary> buildAllSummaries() {
    return listLessonIds()
        .map(read)
        .whereType<StudentLearningState>()
        .map(buildCyberLessonSummary)
        .whereType<CyberLessonSummary>()
        .toList();
  }

  bool _isDeleted(StudentLearningState state) {
    if (state.extra['deletedAt'] != null) return true;
    final syncInfo = state.extra['syncInfo'];
    return syncInfo is Map && syncInfo['deletedAt'] != null;
  }

  bool _isCompatiblyEmpty(StudentLearningState state) {
    return state.createdAt == state.updatedAt &&
        state.curriculum == null &&
        state.progress == null &&
        state.events.isEmpty &&
        state.attempts.isEmpty;
  }

  StudentLearningState _trimLegacyEventsIfNeeded(
    String lessonLocalId,
    int maxEvents,
  ) {
    final state = _store.readState(lessonLocalId);
    if (state.events.length <= maxEvents) return state;
    return _store.writeState(
      state.copyWith(
        events: state.events.sublist(state.events.length - maxEvents),
      ),
    );
  }
}
