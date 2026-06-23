import 'student_learning_state.dart';

typedef StudentStateMutator = StudentLearningState Function(
  StudentLearningState state,
);

class StudentLearningStateService {
  StudentLearningStateService({Map<String, StudentLearningState>? seed})
      : _states = Map.of(seed ?? const {});

  final Map<String, StudentLearningState> _states;

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
}
