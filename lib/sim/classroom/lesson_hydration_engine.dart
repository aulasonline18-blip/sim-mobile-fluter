import '../lesson/lesson_models.dart';
import '../lesson/student_lesson_material_service.dart';
import '../state/student_learning_state.dart';
import 'classroom_models.dart';

class LessonHydrationResult {
  const LessonHydrationResult({
    required this.hydratedFromState,
    required this.initialProgress,
    required this.initialFastLesson,
  });

  final LessonCurrent? hydratedFromState;
  final LessonProgress? initialProgress;
  final ResolveLessonMaterialResult? initialFastLesson;
}

class LessonHydrationEngine {
  LessonHydrationEngine({required this.materialService});

  final StudentLessonMaterialService materialService;

  LessonHydrationResult hydrate({
    required StudentLearningState? state,
    required List<PlannedItem> baseItems,
    required String lessonLocalId,
    required String? topic,
    required String idioma,
    required String academic,
  }) {
    final hydrated = _validCurrent(state, baseItems);
    final progress = state?.progress;
    ResolveLessonMaterialResult? fast;
    final itemIdx = progress?.itemIdx ?? hydrated?.itemIdx ?? 0;
    final layer = progress?.layer ?? hydrated?.layer ?? LessonLayer.l1;
    if (itemIdx >= 0 && itemIdx < baseItems.length) {
      final item = baseItems[itemIdx];
      fast = materialService.resolveFastLessonMaterialFromStateOrCache(
        ResolveLessonMaterialInput(
          lessonLocalId: lessonLocalId,
          topic: topic,
          itemIdx: itemIdx,
          marker: item.marker,
          layer: layer,
          params: CompleteLessonParams(
            lessonLocalId: lessonLocalId,
            item: item.text,
            lang: idioma,
            academic: academic,
            layer: layer,
            mode: LessonMode.session,
            errCount: progress?.erros ?? 0,
            history: progress?.historia ?? const [],
            marker: item.marker,
          ),
        ),
      );
    }
    return LessonHydrationResult(
      hydratedFromState: hydrated,
      initialProgress: progress,
      initialFastLesson: fast,
    );
  }

  LessonCurrent? _validCurrent(
    StudentLearningState? state,
    List<PlannedItem> baseItems,
  ) {
    final current = state?.current;
    if (current == null) return null;
    if (current.itemIdx < 0 || current.itemIdx >= baseItems.length) return null;
    final expectedMarker = baseItems[current.itemIdx].marker;
    if (current.marker != null && current.marker != expectedMarker) return null;
    return current;
  }
}
