import 'dart:async';

import 'student_learning_state.dart';
import 'student_learning_state_persistence.dart';

typedef StudentStateMutator = StudentLearningState Function(
    StudentLearningState state);

class StudentLearningStateService {
  StudentLearningStateService({
    Map<String, StudentLearningState>? seed,
    StudentLearningStatePersistence? persistence,
  })  : _states = Map.of(seed ?? const {}),
        _persistence = persistence;

  static Future<StudentLearningStateService> persistent({
    StudentLearningStatePersistence? persistence,
  }) async {
    final storage = persistence ??
        await SharedPreferencesStudentLearningStatePersistence.create();
    final states = await storage.readAll();
    return StudentLearningStateService(
      seed: {for (final state in states) state.lessonLocalId: state},
      persistence: storage,
    );
  }

  final Map<String, StudentLearningState> _states;
  final StudentLearningStatePersistence? _persistence;

  StudentLearningState? read(String lessonLocalId) => _states[lessonLocalId];

  List<String> listLessonIds() => _states.keys.toList(growable: false);

  StudentLearningState ensure({required String lessonLocalId, String? userId}) {
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
    final saved = _states[state.lessonLocalId]!;
    unawaited(_persistence?.write(saved) ?? Future<void>.value());
    return saved;
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
