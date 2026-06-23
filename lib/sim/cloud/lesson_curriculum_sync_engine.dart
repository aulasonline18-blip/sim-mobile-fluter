import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';

class LessonCurriculumSyncSnapshot {
  const LessonCurriculumSyncSnapshot({
    required this.entryState,
    required this.rehydrationSettled,
    this.curriculum,
  });

  final LiveEntry? entryState;
  final bool rehydrationSettled;
  final StudentCurriculum? curriculum;
}

class LessonCurriculumSyncEngine {
  const LessonCurriculumSyncEngine({required this.stateService});

  final StudentLearningStateService stateService;

  LessonCurriculumSyncSnapshot refresh({
    required String lessonLocalId,
    StudentCurriculum? currentCurriculum,
  }) {
    final state = stateService.read(lessonLocalId);
    final official = state?.curriculum;
    if (currentCurriculum?.items.isNotEmpty == true) {
      return LessonCurriculumSyncSnapshot(
        entryState: state?.entry,
        rehydrationSettled: true,
        curriculum: currentCurriculum,
      );
    }
    if (official?.items.isNotEmpty == true) {
      return LessonCurriculumSyncSnapshot(
        entryState: state?.entry,
        rehydrationSettled: true,
        curriculum: official,
      );
    }
    return LessonCurriculumSyncSnapshot(
      entryState: state?.entry,
      rehydrationSettled: false,
      curriculum: currentCurriculum,
    );
  }
}
