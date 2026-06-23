import '../state/student_learning_state.dart';

List<int> lessonProgressRank(LessonProgress? progress) {
  final itemIdx = progress?.itemIdx ?? 0;
  final layer = progress?.layer.value ?? 1;
  final mainAdvances = progress?.mainAdvances ?? 0;
  final concluidos = progress?.concluidos.length ?? 0;
  return [
    [itemIdx, mainAdvances, concluidos].reduce((a, b) => a > b ? a : b),
    itemIdx,
    layer,
    mainAdvances,
    concluidos,
  ];
}

int compareLessonProgressRank(List<int> a, List<int> b) {
  final len = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < len; i++) {
    final diff = (i < a.length ? a[i] : 0) - (i < b.length ? b[i] : 0);
    if (diff != 0) return diff;
  }
  return 0;
}

LessonProgress? pickMostAdvancedLessonProgress(
  LessonProgress? saved,
  LessonProgress? official,
) {
  if (saved == null) return official;
  if (official == null) return saved;
  return compareLessonProgressRank(
            lessonProgressRank(official),
            lessonProgressRank(saved),
          ) >
          0
      ? official
      : saved;
}
