import '../state/student_learning_state.dart';

enum StudentExperienceRouteStage {
  profile,
  curriculum,
  placement,
  lesson,
  ready,
}

enum StudentExperienceState {
  idle,
  fichaRecebida,
  t00Streaming,
  primeiroItemRecebido,
  providerFailedAfterPartial,
  nivelamentoNecessario,
  nivelamentoEmAndamento,
  t02PrimeiraAulaStreaming,
  primeiraAulaMinimaPronta,
  salaAberta,
  continuidadePreparando,
  erroRecuperavel,
  erroBloqueante,
}

enum StudentExperienceEventType {
  studentFormSubmitted,
  t00Started,
  objectiveSubmittedAt,
  t00StreamStartedAt,
  t00FirstRawChunkAt,
  t00ProfilePartialReceived,
  t00FirstItemReceived,
  t00FirstItemReceivedAt,
  t00FinalCurriculumReceived,
  t00ProviderFailedAfterPartial,
  t00FallbackGatewayStarted,
  t00FallbackGatewaySucceeded,
  t00FallbackGatewayFailed,
  firstItemFastPathStarted,
  placementRequired,
  t02FirstLessonStarted,
  t02FirstMinimumLessonReady,
  firstSlotARequested,
  firstSlotAReady,
  placementStartFromZeroClicked,
  placementContinueToAula,
  recoverableError,
  blockingError,
}

enum StudentExperienceErrorKind { credits, timeout, generic }

class StudentExperienceErrorInfo {
  const StudentExperienceErrorInfo({
    required this.kind,
    required this.message,
  });

  final StudentExperienceErrorKind kind;
  final String message;
}

class StudentExperienceEngineException implements Exception {
  const StudentExperienceEngineException(this.error);

  final StudentExperienceErrorInfo error;

  @override
  String toString() => error.message;
}

class StudentExperienceSnapshot {
  const StudentExperienceSnapshot({
    required this.state,
    required this.stage,
    required this.lessonLocalId,
    required this.destination,
    required this.startMarker,
    required this.startItemIndex,
    required this.error,
    required this.updatedAt,
  });

  final StudentExperienceState state;
  final StudentExperienceRouteStage stage;
  final String lessonLocalId;
  final String? destination;
  final String? startMarker;
  final int startItemIndex;
  final StudentExperienceErrorInfo? error;
  final int updatedAt;
}

class StudentExperienceArgs {
  const StudentExperienceArgs({
    required this.academic,
    required this.idioma,
    required this.lessonLocalId,
    required this.onboarding,
    this.onStage,
  });

  final String academic;
  final String idioma;
  final String lessonLocalId;
  final JsonMap onboarding;
  final void Function(StudentExperienceRouteStage stage)? onStage;
}

class StudentExperienceResult {
  const StudentExperienceResult({
    required this.destination,
    required this.curriculum,
    required this.startMarker,
    required this.startItemIndex,
  });

  final String destination;
  final StudentCurriculum curriculum;
  final String? startMarker;
  final int startItemIndex;
}

class FirstCurriculumItem {
  const FirstCurriculumItem({
    required this.curriculum,
    required this.item,
    required this.itemIndex,
    required this.marker,
  });

  final StudentCurriculum curriculum;
  final CurriculumItem item;
  final int itemIndex;
  final String? marker;
}
