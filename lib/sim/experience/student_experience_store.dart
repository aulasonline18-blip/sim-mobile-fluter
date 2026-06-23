import '../state/live_entry_state.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'student_experience_types.dart';

StudentExperienceRouteStage stageForExperienceState(
  StudentExperienceState state,
) {
  return switch (state) {
    StudentExperienceState.idle => StudentExperienceRouteStage.profile,
    StudentExperienceState.fichaRecebida => StudentExperienceRouteStage.profile,
    StudentExperienceState.t00Streaming =>
      StudentExperienceRouteStage.curriculum,
    StudentExperienceState.primeiroItemRecebido =>
      StudentExperienceRouteStage.curriculum,
    StudentExperienceState.providerFailedAfterPartial =>
      StudentExperienceRouteStage.curriculum,
    StudentExperienceState.nivelamentoNecessario =>
      StudentExperienceRouteStage.placement,
    StudentExperienceState.nivelamentoEmAndamento =>
      StudentExperienceRouteStage.placement,
    StudentExperienceState.t02PrimeiraAulaStreaming =>
      StudentExperienceRouteStage.lesson,
    StudentExperienceState.primeiraAulaMinimaPronta =>
      StudentExperienceRouteStage.lesson,
    StudentExperienceState.salaAberta => StudentExperienceRouteStage.ready,
    StudentExperienceState.continuidadePreparando =>
      StudentExperienceRouteStage.ready,
    StudentExperienceState.erroRecuperavel =>
      StudentExperienceRouteStage.curriculum,
    StudentExperienceState.erroBloqueante =>
      StudentExperienceRouteStage.curriculum,
  };
}

LiveEntryStatus liveEntryStatusFor(StudentExperienceState state) {
  return switch (state) {
    StudentExperienceState.fichaRecebida => LiveEntryStatus.pedidoRecebido,
    StudentExperienceState.t00Streaming => LiveEntryStatus.t00Running,
    StudentExperienceState.primeiroItemRecebido ||
    StudentExperienceState.providerFailedAfterPartial =>
      LiveEntryStatus.firstItemReady,
    StudentExperienceState.t02PrimeiraAulaStreaming =>
      LiveEntryStatus.t02FirstLessonRunning,
    StudentExperienceState.primeiraAulaMinimaPronta =>
      LiveEntryStatus.firstLessonReady,
    StudentExperienceState.salaAberta ||
    StudentExperienceState.continuidadePreparando =>
      LiveEntryStatus.showingFirstLesson,
    StudentExperienceState.erroBloqueante ||
    StudentExperienceState.erroRecuperavel =>
      LiveEntryStatus.failedT02,
    _ => LiveEntryStatus.idle,
  };
}

void publishStudentExperienceEvent(
  StudentLearningStateService service,
  String lessonLocalId,
  StudentExperienceEventType type, [
  JsonMap payload = const {},
]) {
  service.appendEvent(
    lessonLocalId,
    StudentLearningEvent(
      type: 'PROGRESS_UPDATED',
      ts: DateTime.now().millisecondsSinceEpoch,
      payload: {
        'source': 'StudentExperienceEngineV2',
        'event': type.name,
        ...payload,
      },
    ),
  );
}

StudentExperienceSnapshot writeStudentExperienceSnapshot(
  StudentLearningStateService service, {
  required String lessonLocalId,
  required StudentExperienceState state,
  String? destination,
  String? startMarker,
  int startItemIndex = 0,
  StudentExperienceErrorInfo? error,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final snapshot = StudentExperienceSnapshot(
    state: state,
    stage: stageForExperienceState(state),
    lessonLocalId: lessonLocalId,
    destination: destination,
    startMarker: startMarker,
    startItemIndex: startItemIndex,
    error: error,
    updatedAt: now,
  );

  service.mutate(lessonLocalId, (studentState) {
    final extra = {
      ...studentState.profile.extra,
      'student_experience_engine': 'v2',
      'student_experience_state': snapshot.state.name,
      'student_experience_stage': snapshot.stage.name,
      'student_experience_destination': snapshot.destination,
    };
    return studentState.copyWith(
      profile: studentState.profile.copyWith(extra: extra),
    );
  });

  updateLiveEntryState(
    service,
    lessonLocalId,
    status: liveEntryStatusFor(state),
    error: snapshot.error?.message,
    firstItemMarker: snapshot.startMarker,
    firstLessonMaterialKey: entryLessonMaterialKey(
      snapshot.startItemIndex,
      snapshot.startMarker,
    ),
  );

  return snapshot;
}
