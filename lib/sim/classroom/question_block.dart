import 'classroom_models.dart';

QuestionBlockModel activeQuestionBlock({
  required String id,
  required String text,
  required List<QuestionOptionEntry> options,
}) {
  return QuestionBlockModel(
    id: id,
    text: text,
    options: options,
    mode: 'active',
  );
}

QuestionBlockModel answeredQuestionBlock(QuestionHistoryEntry entry) {
  return QuestionBlockModel(
    id: entry.id,
    text: entry.text,
    options: entry.options,
    mode: 'answered',
    chosenOptionId: entry.chosenOptionId,
    correct: entry.correct,
    imageUrl: entry.imageUrl,
  );
}
