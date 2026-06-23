import '../lesson/lesson_models.dart';
import '../lesson/student_lesson_material_service.dart';
import '../state/student_learning_state.dart';
import 'classroom_models.dart';

class LessonPositionState {
  LessonPositionState({
    required this.itemIdx,
    required this.layer,
    required this.erros,
    required this.historia,
    required this.history,
    required this.mainAdvances,
    required this.loadingLayer,
    required this.conteudo,
    required this.phase,
    required this.imagem,
    required this.teoriaPronta,
    required this.items,
  });

  int itemIdx;
  LessonLayer layer;
  int erros;
  List<String> historia;
  List<QuestionHistoryEntry> history;
  int mainAdvances;
  LessonLayer loadingLayer;
  LessonContent? conteudo;
  ClassroomPhase phase;
  String? imagem;
  bool teoriaPronta;
  List<PlannedItem> items;

  PlannedItem? get itemAtivo =>
      itemIdx >= 0 && itemIdx < items.length ? items[itemIdx] : null;
  bool get itemAtivoDisponivel => itemAtivo != null;
  bool get isReviewAtivo => itemAtivo?.isReview == true;
}

class LessonPositionEngine {
  LessonPositionState create({
    required LessonProgress? initialProgress,
    required ResolveLessonMaterialResult? initialFastLesson,
    required List<PlannedItem> baseItems,
  }) {
    return LessonPositionState(
      itemIdx: initialProgress?.itemIdx ?? 0,
      layer: initialProgress?.layer ?? LessonLayer.l1,
      erros: initialProgress?.erros ?? 0,
      historia: initialProgress?.historia ?? const [],
      history: [],
      mainAdvances: initialProgress == null
          ? 0
          : progressIndex(initialProgress, baseItems.length),
      loadingLayer: initialProgress?.layer ?? LessonLayer.l1,
      conteudo: initialFastLesson?.conteudo,
      phase: initialFastLesson == null
          ? const ClassroomPhase.loading()
          : const ClassroomPhase.reading(),
      imagem: initialFastLesson?.imagem,
      teoriaPronta: initialFastLesson != null,
      items: List<PlannedItem>.from(baseItems),
    );
  }

  void mergeBaseItems(LessonPositionState state, List<PlannedItem> baseItems) {
    final mainCount = state.items.where((item) => !item.isReview).length;
    if (state.items.isEmpty || baseItems.length > mainCount) {
      final pendingReviews = state.items.where((item) => item.isReview);
      state.items = [...baseItems, ...pendingReviews];
    }
  }
}
