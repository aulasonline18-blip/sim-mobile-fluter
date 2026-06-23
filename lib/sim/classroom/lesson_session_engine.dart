import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'classroom_models.dart';

class LessonSessionSnapshot {
  const LessonSessionSnapshot({
    required this.lessonLocalId,
    required this.state,
    required this.onboarding,
    required this.curriculum,
    required this.savedProgress,
    required this.idioma,
    required this.academic,
    required this.baseItems,
  });

  final String lessonLocalId;
  final StudentLearningState? state;
  final StudentProfile onboarding;
  final StudentCurriculum? curriculum;
  final LessonProgress? savedProgress;
  final String idioma;
  final String academic;
  final List<PlannedItem> baseItems;
}

class LessonSessionEngine {
  LessonSessionEngine({required this.service});

  final StudentLearningStateService service;

  LessonSessionSnapshot read(String lessonLocalId) {
    final state = service.read(lessonLocalId);
    final profile = state?.profile ?? const StudentProfile();
    final curriculum = state?.curriculum;
    return LessonSessionSnapshot(
      lessonLocalId: lessonLocalId,
      state: state,
      onboarding: profile,
      curriculum: curriculum,
      savedProgress: state?.progress,
      idioma: profile.stableLang ?? profile.language ?? 'English',
      academic: nivelToAcademic(profile.nivel),
      baseItems: (curriculum?.items ?? const [])
          .map(PlannedItem.fromCurriculum)
          .toList(),
    );
  }
}
