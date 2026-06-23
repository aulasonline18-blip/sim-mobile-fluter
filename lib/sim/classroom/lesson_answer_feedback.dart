import '../state/student_learning_state.dart';

enum LessonReviewNeed { none, light, heavy }

LessonReviewNeed lessonNeedsReview({
  required bool correct,
  required DecisionSignal signal,
}) {
  if (signal == DecisionSignal.three) return LessonReviewNeed.heavy;
  if (!correct) return LessonReviewNeed.heavy;
  if (signal == DecisionSignal.two) return LessonReviewNeed.light;
  return LessonReviewNeed.none;
}

String buildLessonAnswerFeedback({
  required bool correct,
  required DecisionSignal signal,
  required bool isReview,
}) {
  final need = lessonNeedsReview(correct: correct, signal: signal);
  if (isReview) {
    if (need == LessonReviewNeed.none) return 'aula_fb_review_none';
    if (need == LessonReviewNeed.light) return 'aula_fb_review_light';
    return 'aula_fb_review_heavy';
  }
  if (correct && signal == DecisionSignal.one) return 'aula_fb_correct';
  if (correct && signal == DecisionSignal.two) return 'aula_fb_correct_rev';
  if (signal == DecisionSignal.three) return 'aula_fb_dont_know';
  return 'aula_fb_redo';
}

String nextButtonLabel({
  required bool isReview,
  required LessonLayer layer,
  required int itemIdx,
  required int plannedLen,
  bool? wasCorrect,
  DecisionSignal? signal,
}) {
  if (isReview) return 'aula_next';
  if (layer == LessonLayer.l3) {
    if (itemIdx + 1 >= plannedLen) return 'aula_consolidate';
    return 'aula_next_item';
  }
  if (layer == LessonLayer.l1 &&
      wasCorrect == true &&
      signal == DecisionSignal.one) {
    return 'aula_layer_label_3';
  }
  return 'aula_layer_label_${layer.value + 1}';
}
