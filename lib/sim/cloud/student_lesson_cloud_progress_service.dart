import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'student_learning_sync.dart';

class LessonCloudProgressInput {
  const LessonCloudProgressInput({
    required this.lessonLocalId,
    required this.itemIdx,
    required this.layer,
    required this.totalItens,
    required this.mainAdvances,
    this.markerAtual,
  });

  final String lessonLocalId;
  final int itemIdx;
  final LessonLayer layer;
  final int totalItens;
  final int mainAdvances;
  final String? markerAtual;
}

class StudentLessonCloudProgressService {
  const StudentLessonCloudProgressService({
    required this.stateService,
    required this.sync,
  });

  final StudentLearningStateService stateService;
  final StudentLearningSync sync;

  void publishLessonStarted(
    String lessonLocalId, {
    String? marker,
    required int itemIdx,
    required LessonLayer layer,
    String? mode,
    String? source,
  }) {
    if (lessonLocalId.isEmpty) return;
    stateService.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: 'LESSON_POSITION_MIRRORED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'marker': marker,
          'itemIdx': itemIdx,
          'layer': layer.value,
          'mode': mode,
          'source': source,
        },
      ),
    );
  }

  void publishAnswerEvent(
    String lessonLocalId, {
    String? marker,
    required LessonLayer layer,
    required AnswerLetter letra,
    required DecisionSignal sinal,
    required bool correct,
    required bool isReview,
  }) {
    if (lessonLocalId.isEmpty) return;
    stateService.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: 'ANSWER_SUBMITTED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'marker': marker,
          'layer': layer.value,
          'letra': letra.name,
          'sinal': sinal.value,
          'correct': correct,
          'isReview': isReview,
        },
      ),
    );
  }

  void publishLessonProgress(LessonCloudProgressInput input) {
    if (input.lessonLocalId.isEmpty) return;
    stateService.mutate(input.lessonLocalId, (state) {
      final progress = state.progress ??
          LessonProgress(
            itemIdx: input.itemIdx,
            layer: input.layer,
            erros: 0,
            amparoLvl: 0,
            historia: const [],
            mainAdvances: 0,
            concluidos: const [],
            pendentesMarkers: const [],
            totalItems: 0,
            pctAvanco: 0,
          );
      return state.copyWith(
        current: LessonCurrent(
          itemIdx: input.itemIdx,
          layer: input.layer,
          marker: input.markerAtual ?? state.current?.marker,
          amparoLvl: state.current?.amparoLvl ?? 0,
        ),
        progress: progress.copyWith(
          itemIdx: input.itemIdx,
          layer: input.layer,
          mainAdvances: input.mainAdvances > progress.mainAdvances
              ? input.mainAdvances
              : progress.mainAdvances,
          totalItems: input.totalItens > progress.totalItems
              ? input.totalItens
              : progress.totalItems,
        ),
      );
    });
    sync.enqueuePatch(input.lessonLocalId);
  }

  void publishLessonFinished(
    LessonCloudProgressInput input, {
    bool blockedByRecovery = false,
    bool recovered = false,
  }) {
    if (input.lessonLocalId.isEmpty) return;
    stateService.appendEvent(
      input.lessonLocalId,
      StudentLearningEvent(
        type: 'PROGRESS_UPDATED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'itemIdx': input.itemIdx,
          'layer': input.layer.value,
          'mainAdvances': input.mainAdvances,
          'blockedByRecovery': blockedByRecovery,
          'recovered': recovered,
        },
      ),
    );
    publishLessonProgress(input);
    if (!blockedByRecovery) {
      stateService.mutate(input.lessonLocalId, (state) {
        return state.copyWith(extra: {...state.extra, 'finalizada': true});
      });
    }
    sync.enqueuePatch(input.lessonLocalId);
  }
}
