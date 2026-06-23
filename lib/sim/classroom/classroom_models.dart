import '../state/student_learning_state.dart';

enum ClassroomPhaseType {
  carregando,
  erroEngine,
  lendo,
  expandida,
  processando,
  concluido,
  fim,
}

class ClassroomPhase {
  const ClassroomPhase({
    required this.type,
    this.message,
    this.letter,
    this.signal,
    this.wasCorrect,
  });

  final ClassroomPhaseType type;
  final String? message;
  final AnswerLetter? letter;
  final DecisionSignal? signal;
  final bool? wasCorrect;

  const ClassroomPhase.loading() : this(type: ClassroomPhaseType.carregando);
  const ClassroomPhase.reading() : this(type: ClassroomPhaseType.lendo);
  const ClassroomPhase.doneEnd() : this(type: ClassroomPhaseType.fim);
  const ClassroomPhase.engineError(String message)
      : this(type: ClassroomPhaseType.erroEngine, message: message);
  const ClassroomPhase.expanded(AnswerLetter letter)
      : this(type: ClassroomPhaseType.expandida, letter: letter);
  const ClassroomPhase.processing(AnswerLetter letter, DecisionSignal signal)
      : this(
          type: ClassroomPhaseType.processando,
          letter: letter,
          signal: signal,
        );
  const ClassroomPhase.completed({
    required String message,
    required bool wasCorrect,
    required DecisionSignal signal,
  }) : this(
          type: ClassroomPhaseType.concluido,
          message: message,
          wasCorrect: wasCorrect,
          signal: signal,
        );
}

class PlannedItem {
  const PlannedItem({
    required this.marker,
    required this.text,
    this.title,
    this.isReview = false,
    this.reviewLayer,
    this.reviewKind,
    this.originalMarker,
  });

  final String marker;
  final String text;
  final String? title;
  final bool isReview;
  final LessonLayer? reviewLayer;
  final String? reviewKind;
  final String? originalMarker;

  factory PlannedItem.fromCurriculum(CurriculumItem item) => PlannedItem(
        marker: item.marker,
        text: item.teacherText,
        title: item.title,
      );
}

class QuestionOptionEntry {
  const QuestionOptionEntry({required this.id, required this.text});

  final AnswerLetter id;
  final String text;
}

class QuestionHistoryEntry {
  const QuestionHistoryEntry({
    required this.id,
    required this.text,
    required this.options,
    required this.chosenOptionId,
    required this.correct,
    this.imageUrl,
  });

  final String id;
  final String text;
  final List<QuestionOptionEntry> options;
  final AnswerLetter chosenOptionId;
  final bool correct;
  final String? imageUrl;
}

class QuestionBlockModel {
  const QuestionBlockModel({
    required this.id,
    required this.text,
    required this.options,
    required this.mode,
    this.chosenOptionId,
    this.correct,
    this.imageUrl,
  });

  final String id;
  final String text;
  final List<QuestionOptionEntry> options;
  final String mode;
  final AnswerLetter? chosenOptionId;
  final bool? correct;
  final String? imageUrl;
}

int progressIndex(LessonProgress? progress, int total) {
  final raw = [
    progress?.mainAdvances ?? 0,
    progress?.itemIdx ?? 0,
    progress?.concluidos.length ?? 0,
  ].reduce((a, b) => a > b ? a : b);
  return total > 0 ? (raw > total ? total : raw) : raw;
}

bool lessonAlreadyStarted(LessonProgress? progress) {
  if (progress == null) return false;
  return progress.itemIdx > 0 ||
      progress.layer != LessonLayer.l1 ||
      progress.erros > 0 ||
      progress.mainAdvances > 0 ||
      progress.historia.isNotEmpty ||
      progress.concluidos.isNotEmpty;
}

String nivelToAcademic(String? nivel) {
  return switch (nivel) {
    'zero' => 'iniciante absoluto (zero conhecimento)',
    'pouco' => 'iniciante (algum contato previo)',
    'base' => 'intermediario (base solida)',
    _ => 'iniciante (nivel incerto, ajustar)',
  };
}

({int idx, LessonLayer layer})? nextLessonSlot(
  int idx,
  LessonLayer layer,
  List<PlannedItem> pool,
) {
  final item = idx >= 0 && idx < pool.length ? pool[idx] : null;
  if (item == null) return null;
  if (!item.isReview && layer != LessonLayer.l3) {
    return (
      idx: idx,
      layer: layer == LessonLayer.l1 ? LessonLayer.l2 : LessonLayer.l3,
    );
  }
  final nextIdx = idx + 1;
  if (nextIdx >= pool.length) return null;
  final next = pool[nextIdx];
  return (idx: nextIdx, layer: next.isReview ? next.reviewLayer ?? LessonLayer.l1 : LessonLayer.l1);
}

List<({int idx, PlannedItem item, LessonLayer layer})> lessonWindow(
  int fromIdx,
  LessonLayer currentLayer,
  List<PlannedItem> pool,
) {
  if (fromIdx < 0 || fromIdx >= pool.length) return const [];
  final first = pool[fromIdx];
  final firstLayer = first.isReview ? first.reviewLayer ?? LessonLayer.l1 : currentLayer;
  final window = <({int idx, PlannedItem item, LessonLayer layer})>[
    (idx: fromIdx, item: first, layer: firstLayer),
  ];
  var position = (idx: fromIdx, layer: firstLayer);
  while (window.length < 3) {
    final next = nextLessonSlot(position.idx, position.layer, pool);
    if (next == null) break;
    if (next.idx < 0 || next.idx >= pool.length) break;
    final item = pool[next.idx];
    window.add((idx: next.idx, item: item, layer: next.layer));
    position = next;
  }
  return window;
}

({int idx, LessonLayer layer, bool ended})? nextAdvancePosition({
  required bool isReview,
  required int itemIdx,
  required List<PlannedItem> pool,
  required StudentLessonViewLite? officialView,
}) {
  if (!isReview) {
    if (officialView == null) return null;
    return (
      idx: officialView.itemIdx,
      layer: officialView.layer,
      ended: officialView.ended,
    );
  }
  final idx = itemIdx + 1;
  if (idx >= pool.length) return (idx: idx, layer: LessonLayer.l1, ended: true);
  final next = pool[idx];
  return (
    idx: idx,
    layer: next.isReview ? next.reviewLayer ?? LessonLayer.l1 : LessonLayer.l1,
    ended: false,
  );
}

class StudentLessonViewLite {
  const StudentLessonViewLite({
    required this.itemIdx,
    required this.layer,
    required this.ended,
  });

  final int itemIdx;
  final LessonLayer layer;
  final bool ended;
}
