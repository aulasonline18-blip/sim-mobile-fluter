import '../state/student_learning_state.dart';
import 'lesson_models.dart';

class LessonContentValidationException implements Exception {
  const LessonContentValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _requiredText(Object? value, String field) {
  final text = (value ?? '').toString().trim();
  if (text.isEmpty) {
    throw LessonContentValidationException('$field ausente/vazio');
  }
  return text;
}

AnswerLetter parseRequiredCorrectAnswer(Object? value) {
  final raw = value?.toString().trim().toUpperCase();
  if (raw == null || raw.isEmpty) {
    throw const LessonContentValidationException('correct_answer ausente');
  }
  return AnswerLetter.values.firstWhere(
    (letter) => letter.name == raw,
    orElse: () =>
        throw const LessonContentValidationException('correct_answer invalido'),
  );
}

void validateVisualTrigger(Object? value) {
  if (value == null) return;
  if (value is! Map) {
    throw const LessonContentValidationException('visual_trigger nao-objeto');
  }
  bool isStringList(Object? candidate) =>
      candidate is List && candidate.every((item) => item is String);

  final needsImage = value['needs_image'];
  if (needsImage != null && needsImage is! bool) {
    throw const LessonContentValidationException(
      'visual_trigger.needs_image invalido',
    );
  }
  final topic = value['topic'];
  if (topic != null && topic is! String) {
    throw const LessonContentValidationException(
      'visual_trigger.topic invalido',
    );
  }
  final imagePrompt = value['image_prompt'];
  if (imagePrompt != null && imagePrompt is! String) {
    throw const LessonContentValidationException(
      'visual_trigger.image_prompt invalido',
    );
  }
  final pedagogicalNeed = value['pedagogical_need'];
  if (pedagogicalNeed != null &&
      !const {
        'none',
        'helpful',
        'important',
        'essential',
      }.contains(pedagogicalNeed.toString())) {
    throw const LessonContentValidationException(
      'visual_trigger.pedagogical_need invalido',
    );
  }
  final renderStrategy = value['render_strategy'];
  if (renderStrategy != null &&
      !const {'software', 'ai'}.contains(renderStrategy.toString())) {
    throw const LessonContentValidationException(
      'visual_trigger.render_strategy invalido',
    );
  }
  final visualType = value['visual_type'];
  if (visualType != null &&
      !const {
        'none',
        'diagram',
        'process',
        'comparison',
        'spatial',
        'anatomy',
        'geometry',
        'graph',
        'map',
        'structure',
        'experiment',
      }.contains(visualType.toString())) {
    throw const LessonContentValidationException(
      'visual_trigger.visual_type invalido',
    );
  }
  if (value.containsKey('key_elements') &&
      !isStringList(value['key_elements'])) {
    throw const LessonContentValidationException(
      'visual_trigger.key_elements invalido',
    );
  }
}

LessonContent validatedLessonContentFromJson(JsonMap source) {
  final options = source['options'];
  if (options is! Map) {
    throw const LessonContentValidationException('options ausente');
  }
  final normalizedOptions = {
    AnswerLetter.A: _requiredText(options['A'] ?? options['a'], 'options.A'),
    AnswerLetter.B: _requiredText(options['B'] ?? options['b'], 'options.B'),
    AnswerLetter.C: _requiredText(options['C'] ?? options['c'], 'options.C'),
  };
  final visualTriggerRaw = source['visual_trigger'] ?? source['visualTrigger'];
  validateVisualTrigger(visualTriggerRaw);
  return LessonContent(
    explanation: _requiredText(
      source['explanation'] ?? source['explicacao'],
      'explanation',
    ),
    question: _requiredText(
      source['question'] ?? source['pergunta'],
      'question',
    ),
    options: normalizedOptions,
    correctAnswer: parseRequiredCorrectAnswer(
      source['correct_answer'] ?? source['correctAnswer'],
    ),
    whyCorrect: (source['why_correct'] ?? source['whyCorrect'])?.toString(),
    whyWrong: source['why_wrong'] ?? source['whyWrong'],
    visualTrigger: visualTriggerRaw is Map
        ? JsonMap.from(visualTriggerRaw)
        : null,
  );
}
