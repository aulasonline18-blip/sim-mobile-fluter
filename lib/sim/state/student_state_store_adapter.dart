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

  @override
  void Function() subscribe(void Function(String lessonLocalId) cb) {
    _writeListeners.add(cb);
    return () => _writeListeners.remove(cb);
  }

  void _notifyWrite(String lessonLocalId) {
    for (final cb in List.of(_writeListeners)) {
      try {
        cb(lessonLocalId);
      } catch (_) {}
    }
  }

  @override
  StudentLearningState? read(String lessonLocalId) {
    final state = _store.readState(lessonLocalId);
    if (_isCompatiblyEmpty(state)) return null;
    return state;
  }

  @override
  List<String> listLessonIds() {
    // O ?ndice local entra na fase de sync/listagem. Por enquanto, manter
    // compatibilidade com chamadas que toleram lista vazia.
    return const [];
  }

  @override
  StudentLearningState ensure({required String lessonLocalId, String? userId}) {
    final state = _store.readState(lessonLocalId);
    if (userId == null || state.userId == userId) return state;
    return _store.writeState(state.copyWith(userId: userId));
  }

  @override
  StudentLearningState write(StudentLearningState state) {
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
