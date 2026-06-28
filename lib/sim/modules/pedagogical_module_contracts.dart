import '../state/student_learning_state.dart';

class T00BootstrapRequest {
  const T00BootstrapRequest({
    required this.lessonLocalId,
    required this.onboarding,
    required this.lang,
    required this.academic,
  });

  final String lessonLocalId;
  final JsonMap onboarding;
  final String lang;
  final String academic;
}

class T00BootstrapChunk {
  const T00BootstrapChunk({
    required this.type,
    required this.payload,
  });

  final String type;
  final JsonMap payload;
}

abstract interface class T00BootstrapClient {
  Stream<T00BootstrapChunk> runBootstrap(T00BootstrapRequest request);
}

class T02LessonRequest {
  const T02LessonRequest({
    required this.lessonLocalId,
    required this.item,
    required this.lang,
    required this.academic,
    required this.layer,
    required this.mode,
    required this.errCount,
    required this.history,
    this.marker,
    this.profile = const {},
    this.addendum,
    this.amparoLvl,
  });

  final String lessonLocalId;
  final String item;
  final String lang;
  final String academic;
  final LessonLayer layer;
  final String mode;
  final int errCount;
  final List<String> history;
  final String? marker;
  final JsonMap profile;
  final String? addendum;
  final int? amparoLvl;
}

class T02LessonMaterial {
  const T02LessonMaterial({
    required this.explanation,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.whyCorrect,
    required this.whyWrong,
    required this.generatedAt,
    required this.source,
  });

  final String explanation;
  final String question;
  final Map<AnswerLetter, String> options;
  final AnswerLetter correctAnswer;
  final String whyCorrect;
  final Object? whyWrong;
  final DateTime generatedAt;
  final String source;
}

abstract interface class T02LessonClient {
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request);

  Future<T02LessonMaterial> doubt(T02LessonRequest request);

  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request);

  Future<T02LessonMaterial> placement(T02LessonRequest request);
}
