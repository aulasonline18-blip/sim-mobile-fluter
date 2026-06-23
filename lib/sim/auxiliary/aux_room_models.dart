import '../lesson/lesson_models.dart';
import '../state/student_learning_state.dart';

enum AuxRoomMode { review, recovery, doubt }

enum ReviewRoomStatus {
  choose,
  preparing,
  ready,
  answering,
  result,
  done,
  failed,
}

enum RecoveryRoomStatus {
  intro,
  ready,
  answering,
  result,
  preparing,
  done,
  failed,
}

enum DoubtStatus { idle, processing, explaining, error }

class AuxRoomProfile {
  const AuxRoomProfile({
    this.stableLang,
    this.academicLevel,
    this.preferredName,
    this.notes,
    this.extra = const {},
  });

  final String? stableLang;
  final String? academicLevel;
  final String? preferredName;
  final String? notes;
  final JsonMap extra;

  JsonMap toJson() => {
        ...extra,
        if (stableLang != null) 'stableLang': stableLang,
        if (academicLevel != null) 'academicLevel': academicLevel,
        if (preferredName != null) 'preferredName': preferredName,
        if (notes != null) 'notes': notes,
      };
}

class AuxRoomItem {
  const AuxRoomItem({this.marker, this.text});

  final String? marker;
  final String? text;
}

class AuxRoomContent {
  const AuxRoomContent({
    required this.question,
    required this.options,
    required this.correctAnswer,
    this.explanation = '',
  });

  final String question;
  final Map<AnswerLetter, String> options;
  final AnswerLetter correctAnswer;
  final String explanation;

  factory AuxRoomContent.fromLesson(LessonContent content) => AuxRoomContent(
        question: content.question,
        options: content.options,
        correctAnswer: content.correctAnswer,
        explanation: content.explanation,
      );
}

class ReviewRoomContext {
  const ReviewRoomContext({
    required this.lessonLocalId,
    required this.topic,
    required this.items,
    required this.fallbackStartIdx,
    required this.layer,
    required this.profile,
  });

  final String lessonLocalId;
  final String topic;
  final List<AuxRoomItem> items;
  final int fallbackStartIdx;
  final LessonLayer layer;
  final AuxRoomProfile profile;
}

class RecoveryRoomContext {
  const RecoveryRoomContext({
    required this.lessonLocalId,
    required this.topic,
    required this.items,
    required this.layer,
    required this.profile,
  });

  final String lessonLocalId;
  final String topic;
  final List<AuxRoomItem> items;
  final LessonLayer layer;
  final AuxRoomProfile profile;
}

class ReviewRoomView {
  const ReviewRoomView({
    required this.status,
    required this.count,
    required this.queue,
    required this.idx,
    this.conteudo,
    this.letra,
    this.sinal,
    this.resultCorrect,
    this.errMsg,
  });

  final ReviewRoomStatus status;
  final int count;
  final List<String> queue;
  final int idx;
  final AuxRoomContent? conteudo;
  final AnswerLetter? letra;
  final DecisionSignal? sinal;
  final bool? resultCorrect;
  final String? errMsg;

  ReviewRoomView copyWith({
    ReviewRoomStatus? status,
    int? count,
    List<String>? queue,
    int? idx,
    AuxRoomContent? conteudo,
    AnswerLetter? letra,
    DecisionSignal? sinal,
    bool? resultCorrect,
    String? errMsg,
  }) {
    return ReviewRoomView(
      status: status ?? this.status,
      count: count ?? this.count,
      queue: queue ?? this.queue,
      idx: idx ?? this.idx,
      conteudo: conteudo ?? this.conteudo,
      letra: letra ?? this.letra,
      sinal: sinal ?? this.sinal,
      resultCorrect: resultCorrect ?? this.resultCorrect,
      errMsg: errMsg ?? this.errMsg,
    );
  }
}

class RecoveryRoomView {
  const RecoveryRoomView({
    required this.status,
    required this.queue,
    required this.idx,
    this.conteudo,
    this.letra,
    this.sinal,
    this.resultCorrect,
    this.errMsg,
    this.restartRequired = false,
  });

  final RecoveryRoomStatus status;
  final List<String> queue;
  final int idx;
  final AuxRoomContent? conteudo;
  final AnswerLetter? letra;
  final DecisionSignal? sinal;
  final bool? resultCorrect;
  final String? errMsg;
  final bool restartRequired;

  RecoveryRoomView copyWith({
    RecoveryRoomStatus? status,
    List<String>? queue,
    int? idx,
    AuxRoomContent? conteudo,
    AnswerLetter? letra,
    DecisionSignal? sinal,
    bool? resultCorrect,
    String? errMsg,
    bool? restartRequired,
  }) {
    return RecoveryRoomView(
      status: status ?? this.status,
      queue: queue ?? this.queue,
      idx: idx ?? this.idx,
      conteudo: conteudo ?? this.conteudo,
      letra: letra ?? this.letra,
      sinal: sinal ?? this.sinal,
      resultCorrect: resultCorrect ?? this.resultCorrect,
      errMsg: errMsg ?? this.errMsg,
      restartRequired: restartRequired ?? this.restartRequired,
    );
  }
}

class DoubtImagePayload {
  const DoubtImagePayload({
    required this.name,
    required this.type,
    required this.size,
    required this.dataUrl,
  });

  final String name;
  final String type;
  final int size;
  final String dataUrl;
}

class DoubtResponse {
  const DoubtResponse({required this.explanation, this.visualTrigger});

  final String explanation;
  final JsonMap? visualTrigger;
}

class DoubtState {
  const DoubtState({
    required this.status,
    required this.progress,
    this.sheetOpen = false,
    this.error,
    this.response,
  });

  final DoubtStatus status;
  final int progress;
  final bool sheetOpen;
  final String? error;
  final DoubtResponse? response;

  static const idle = DoubtState(status: DoubtStatus.idle, progress: 0);

  DoubtState copyWith({
    DoubtStatus? status,
    int? progress,
    bool? sheetOpen,
    String? error,
    DoubtResponse? response,
  }) {
    return DoubtState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      sheetOpen: sheetOpen ?? this.sheetOpen,
      error: error,
      response: response ?? this.response,
    );
  }
}
