import '../state/student_learning_state_service.dart';
import 'student_experience_guards.dart';
import 'student_experience_store.dart';
import 'student_experience_t00_adapter.dart';
import 'student_experience_t02_adapter.dart';
import 'student_experience_types.dart';

abstract interface class PlacementDecisionReader {
  bool get settled;
}

class LabPlacementDecisionReader implements PlacementDecisionReader {
  const LabPlacementDecisionReader({this.settled = false});

  @override
  final bool settled;
}

class StudentExperienceEngine {
  StudentExperienceEngine({
    required this.service,
    required this.t00,
    required this.placement,
    this.t02,
  });

  final StudentLearningStateService service;
  final StudentExperienceT00Adapter t00;
  final StudentExperienceT02Adapter? t02;
  final PlacementDecisionReader placement;

  Future<StudentExperienceResult> prepareStudentExperienceEntry(
    StudentExperienceArgs args,
  ) async {
    final topic = (args.onboarding['objetivo'] ?? '').toString().trim();
    if (topic.isEmpty) {
      throw const StudentExperienceEngineException(
        StudentExperienceErrorInfo(
          kind: StudentExperienceErrorKind.generic,
          message: 'Conte o que voce quer estudar antes de entrar na aula.',
        ),
      );
    }

    service.ensure(lessonLocalId: args.lessonLocalId);
    writeStudentExperienceSnapshot(
      service,
      lessonLocalId: args.lessonLocalId,
      state: StudentExperienceState.fichaRecebida,
    );
    publishStudentExperienceEvent(
      service,
      args.lessonLocalId,
      StudentExperienceEventType.studentFormSubmitted,
      {'topic': topic},
    );

    try {
      final first = await t00.startT00UntilFirstItem(args);
      publishStudentExperienceEvent(
        service,
        args.lessonLocalId,
        StudentExperienceEventType.firstItemFastPathStarted,
        {
          'at': DateTime.now().millisecondsSinceEpoch,
          'marker': first.marker,
          'itemIdx': first.itemIndex,
        },
      );

      await t02?.prepareFirstMinimumLesson(args: args, first: first);

      if (!placement.settled) {
        args.onStage?.call(StudentExperienceRouteStage.placement);
        writeStudentExperienceSnapshot(
          service,
          lessonLocalId: args.lessonLocalId,
          state: StudentExperienceState.nivelamentoNecessario,
          destination: '/cyber/placement',
          startMarker: first.marker,
          startItemIndex: first.itemIndex,
        );
        publishStudentExperienceEvent(
          service,
          args.lessonLocalId,
          StudentExperienceEventType.placementRequired,
          {'marker': first.marker},
        );
        return StudentExperienceResult(
          destination: '/cyber/placement',
          curriculum: first.curriculum,
          startMarker: null,
          startItemIndex: 0,
        );
      }

      args.onStage?.call(StudentExperienceRouteStage.ready);
      writeStudentExperienceSnapshot(
        service,
        lessonLocalId: args.lessonLocalId,
        state: StudentExperienceState.salaAberta,
        destination: '/cyber/aula',
        startMarker: first.marker,
        startItemIndex: first.itemIndex,
      );
      return StudentExperienceResult(
        destination: '/cyber/aula',
        curriculum: first.curriculum,
        startMarker: first.marker,
        startItemIndex: first.itemIndex,
      );
    } catch (error) {
      final info = classifyStudentExperienceError(error);
      writeStudentExperienceSnapshot(
        service,
        lessonLocalId: args.lessonLocalId,
        state: info.kind == StudentExperienceErrorKind.timeout
            ? StudentExperienceState.erroRecuperavel
            : StudentExperienceState.erroBloqueante,
        error: info,
      );
      publishStudentExperienceEvent(
        service,
        args.lessonLocalId,
        info.kind == StudentExperienceErrorKind.timeout
            ? StudentExperienceEventType.recoverableError
            : StudentExperienceEventType.blockingError,
        {'error': info.message},
      );
      throw StudentExperienceEngineException(info);
    }
  }
}
