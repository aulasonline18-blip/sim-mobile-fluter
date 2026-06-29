import '../core/signal_tracker.dart';
import '../lesson/dopamine_ready_window_engine.dart';
import '../lesson/lesson_models.dart';
import '../lesson/student_lesson_material_service.dart';
import '../media/audio_core.dart';
import '../state/learning_decision_engine.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import '../state/student_lesson_executor.dart';
import '../state/mastery_truth_engine.dart';
import '../state/student_state_store.dart';
import 'amparo_controller.dart';
import 'classroom_models.dart';
import 'lesson_answer_feedback.dart';
import 'lesson_material_controller.dart';
import 'lesson_position_engine.dart';

class LessonAnswerProgressController {
  LessonAnswerProgressController({
    required this.stateService,
    required this.materialService,
    required this.materialController,
    this.store,
    this.audioCore,
    SignalTracker? signalTracker,
    MasteryTruthEngine? truthEngine,
  }) : signalTracker = signalTracker ?? SignalTracker(),
       truthEngine = truthEngine ?? const MasteryTruthEngine();

  final StudentLearningStateService stateService;
  final StudentLessonMaterialService materialService;
  final LessonMaterialController materialController;
  final StudentStateStore? store;
  final AudioCore? audioCore;
  final SignalTracker signalTracker;
  final MasteryTruthEngine truthEngine;
  final AmparoController _amparo = const AmparoController();

  void selecionar(LessonPositionState position, AnswerLetter letter) {
    if (position.phase.type != ClassroomPhaseType.lendo &&
        position.phase.type != ClassroomPhaseType.expandida) {
      return;
    }
    audioCore?.stop();
    position.phase = ClassroomPhase.expanded(letter);
  }

  Future<void> enviarSinal({
    required String lessonLocalId,
    required String? topic,
    required LessonPositionState position,
    required DecisionSignal signal,
    required List<PlannedItem> baseItems,
  }) async {
    final phase = position.phase;
    final content = position.conteudo;
    final item = position.itemAtivo;
    if (phase.type != ClassroomPhaseType.expandida ||
        phase.letter == null ||
        content == null ||
        item == null) {
      return;
    }

    audioCore?.stop();
    final letter = phase.letter!;
    signalTracker.recordSignal(
      marker: item.marker,
      layer: position.layer,
      sinal: signal,
    );
    final signalThreeCount = signalTracker.getSignalCount(
      marker: item.marker,
      layer: position.layer,
      sinal: DecisionSignal.three,
    );
    final correct = letter == content.correctAnswer;
    final questionId = [
      item.marker,
      'layer-${position.layer.value}',
      content.question,
    ].join('::');
    final entry = QuestionHistoryEntry(
      id: questionId,
      text: content.question,
      options: [
        QuestionOptionEntry(
          id: AnswerLetter.A,
          text: content.options[AnswerLetter.A] ?? '',
        ),
        QuestionOptionEntry(
          id: AnswerLetter.B,
          text: content.options[AnswerLetter.B] ?? '',
        ),
        QuestionOptionEntry(
          id: AnswerLetter.C,
          text: content.options[AnswerLetter.C] ?? '',
        ),
      ],
      chosenOptionId: letter,
      correct: correct,
      imageUrl: position.imagem,
    );
    // Prevent double-tap (only block if the immediately preceding entry is identical)
    final lastEntry = position.history.isEmpty ? null : position.history.last;
    if (lastEntry == null ||
        lastEntry.id != entry.id ||
        lastEntry.chosenOptionId != entry.chosenOptionId) {
      final next = [...position.history, entry];
      final firstImageToKeep = (next.length - 4).clamp(0, next.length);
      position.history = next.asMap().entries.map((mapEntry) {
        if (mapEntry.key < firstImageToKeep) {
          final old = mapEntry.value;
          return QuestionHistoryEntry(
            id: old.id,
            text: old.text,
            options: old.options,
            chosenOptionId: old.chosenOptionId,
            correct: old.correct,
            imageUrl: null,
          );
        }
        return mapEntry.value;
      }).toList();
    }

    position.phase = ClassroomPhase.processing(letter, signal);
    // VIII.3: 350ms delay before engine runs so the UI can show "processando" state
    await Future.delayed(const Duration(milliseconds: 350));
    final currentState = stateService.read(lessonLocalId);
    if (currentState != null && !position.isReviewAtivo) {
      final nextState = processAnswerWithEngine(
        currentState,
        AnswerContext(
          letra: letter,
          sinal: signal,
          correctAnswer: content.correctAnswer,
        ),
      );
      final savedState = stateService.write(nextState);
      final amparoState = _amparo.applyIfNeeded(
        state: savedState,
        correct: correct,
        ts: DateTime.now().millisecondsSinceEpoch,
        signalThreeCount: signalThreeCount,
      );
      final savedAfterAmparo = amparoState != savedState
          ? stateService.write(amparoState)
          : savedState;
      final evidence = truthEngine.evaluateMarker(
        savedAfterAmparo,
        item.marker,
      );
      final truthState = truthEngine.writeTruthToState(
        savedAfterAmparo,
        evidence,
      );
      final savedTruthState = stateService.write(truthState);
      _appendMasteryEvaluatedEvent(
        lessonLocalId: lessonLocalId,
        state: savedTruthState,
        evidence: evidence,
      );
      _appendWeaknessEventsIfNeeded(
        lessonLocalId: lessonLocalId,
        state: savedTruthState,
        evidence: evidence,
      );
      final postMasteryState =
          stateService.read(lessonLocalId) ?? savedTruthState;
      final decidedState = _applyPostMasteryDecision(
        lessonLocalId: lessonLocalId,
        state: postMasteryState,
        evidence: evidence,
      );
      final view = activeLessonView(decidedState);
      if (view != null && !view.ended) {
        materialService.maintainLessonReadyWindow(
          lessonLocalId: lessonLocalId,
          topic: topic,
          itemIdx: view.itemIdx,
          layer: view.layer,
          items: baseItems
              .map(
                (item) =>
                    DopamineWindowItem(text: item.text, marker: item.marker),
              )
              .toList(),
          source: 'cyber.aula.after-signal',
          priority: 'active',
          reason: 'answer_signal_prepares_next_experience',
        );
      }
    }

    final message = buildLessonAnswerFeedback(
      correct: correct,
      signal: signal,
      isReview: position.isReviewAtivo,
    );
    position.phase = ClassroomPhase.completed(
      message: message,
      wasCorrect: correct,
      signal: signal,
    );
    stateService.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: 'ANSWER_SUBMITTED',
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: {
          'marker': item.marker,
          'layer': position.layer.value,
          'letra': letter.name,
          'sinal': signal.value,
          'correct': correct,
          'isReview': position.isReviewAtivo,
        },
      ),
    );
  }

  StudentLearningState _applyPostMasteryDecision({
    required String lessonLocalId,
    required StudentLearningState state,
    required MasteryEvidence evidence,
  }) {
    final curriculum = state.curriculum;
    final progress = state.progress;
    if (curriculum == null || progress == null) return state;
    final itemIdx = progress.itemIdx;
    if (itemIdx < 0 || itemIdx >= curriculum.items.length) return state;
    final marker = curriculum.items[itemIdx].marker;
    final stateForDecision =
        evidence.status == MasteryStatus.mastered &&
            !(progress.concluidos.contains(marker))
        ? state.copyWith(
            progress: progress.copyWith(
              concluidos: [...progress.concluidos, marker],
            ),
          )
        : state;
    final decision = decideNextActionFromState(stateForDecision);
    final applied = applyStudentDecision(
      progress,
      decision,
      itemIdx: itemIdx,
      layer: progress.layer,
      totalItems: curriculum.items.length,
      marker: marker,
    );
    final nextProgress = applied.nextProgress;
    final nextState = state.copyWith(
      progress: nextProgress,
      current: LessonCurrent(
        itemIdx: nextProgress.itemIdx,
        marker: nextProgress.itemIdx < curriculum.items.length
            ? curriculum.items[nextProgress.itemIdx].marker
            : null,
        layer: nextProgress.layer,
        amparoLvl: nextProgress.amparoLvl,
      ),
      extra: {
        ...state.extra,
        'next_action': {
          'action': decision.actionType.name,
          'reason': decision.reason,
          'confidence': decision.confidence.name,
          'marker': marker,
          'from_itemIdx': itemIdx,
          'from_layer': progress.layer.value,
          'to_itemIdx': nextProgress.itemIdx,
          'to_layer': nextProgress.layer.value,
          'mastery_status': evidence.status.name,
          'needs_reinforcement': evidence.needsReinforcement,
        },
      },
    );
    final saved = stateService.write(nextState);
    _appendCanonicalOrLegacyEvent(
      lessonLocalId: lessonLocalId,
      state: saved,
      type: 'NEXT_ACTION_DECIDED',
      payload: {
        'action': decision.actionType.name,
        'reason': decision.reason,
        'confidence': decision.confidence.name,
        'marker': marker,
        'fromItemIdx': itemIdx,
        'fromLayer': progress.layer.value,
        'toItemIdx': nextProgress.itemIdx,
        'toLayer': nextProgress.layer.value,
        'masteryStatus': evidence.status.name,
      },
    );
    if (evidence.status == MasteryStatus.mastered) {
      _appendCanonicalOrLegacyEvent(
        lessonLocalId: lessonLocalId,
        state: saved,
        type: 'ITEM_MASTERED',
        payload: {
          'marker': evidence.marker,
          'status': evidence.status.name,
          'reason': evidence.reason,
          'score': evidence.score,
        },
      );
    }
    if (applied.applied && nextProgress.itemIdx != itemIdx) {
      _appendCanonicalOrLegacyEvent(
        lessonLocalId: lessonLocalId,
        state: saved,
        type: 'ITEM_ADVANCED',
        payload: {
          'fromItemIdx': itemIdx,
          'toItemIdx': nextProgress.itemIdx,
          'fromLayer': progress.layer.value,
          'toLayer': nextProgress.layer.value,
          'fromMarker': marker,
          'toMarker': nextProgress.itemIdx < curriculum.items.length
              ? curriculum.items[nextProgress.itemIdx].marker
              : null,
        },
      );
    }
    return stateService.read(lessonLocalId) ?? saved;
  }

  void _appendWeaknessEventsIfNeeded({
    required String lessonLocalId,
    required StudentLearningState state,
    required MasteryEvidence evidence,
  }) {
    if (!evidence.needsReinforcement) return;
    final payload = {
      'marker': evidence.marker,
      'status': evidence.status.name,
      'reason': evidence.reason,
      'score': evidence.score,
      'consecutiveWrong': evidence.consecutiveWrong,
      'attemptCount': evidence.attemptCount,
      'needsReview': evidence.needsReview,
      'needsReinforcement': evidence.needsReinforcement,
    };
    _appendCanonicalOrLegacyEvent(
      lessonLocalId: lessonLocalId,
      state: state,
      type: 'WEAKNESS_REGISTERED',
      payload: payload,
    );
    _appendCanonicalOrLegacyEvent(
      lessonLocalId: lessonLocalId,
      state: state,
      type: 'REINFORCEMENT_REQUIRED',
      payload: payload,
    );
  }

  void _appendMasteryEvaluatedEvent({
    required String lessonLocalId,
    required StudentLearningState state,
    required MasteryEvidence evidence,
  }) {
    _appendCanonicalOrLegacyEvent(
      lessonLocalId: lessonLocalId,
      state: state,
      type: 'MASTERY_EVALUATED',
      payload: {...evidence.toJson(), 'status': evidence.status.name},
    );
  }

  void _appendCanonicalOrLegacyEvent({
    required String lessonLocalId,
    required StudentLearningState state,
    required String type,
    required JsonMap payload,
  }) {
    final canonicalStore = store;
    if (canonicalStore != null) {
      canonicalStore.appendEvent(
        lessonLocalId: lessonLocalId,
        type: type,
        payload: payload,
        source: 'lesson-answer-progress-controller',
        userId: state.userId,
      );
      return;
    }
    stateService.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: type,
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: payload,
      ),
    );
  }

  Future<void> avancar({
    required String lessonLocalId,
    required String? topic,
    required LessonPositionState position,
    required List<PlannedItem> baseItems,
    required String idioma,
    required String academic,
  }) async {
    if (position.phase.type != ClassroomPhaseType.concluido) return;
    audioCore?.stop();
    final item = position.itemAtivo;
    final state = stateService.read(lessonLocalId);
    final view = state == null ? null : activeLessonView(state);
    if (item == null) {
      position.phase = const ClassroomPhase.doneEnd();
      stateService.appendEvent(
        lessonLocalId,
        StudentLearningEvent(
          type: 'FINAL_COMPLETION_ALLOWED',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: {
            'itemIdx': view?.itemIdx ?? position.itemIdx,
            'layer': (view?.layer ?? position.layer).value,
            'totalItens': baseItems.length,
            'mainAdvances': view?.mainAdvances ?? position.mainAdvances,
          },
        ),
      );
      return;
    }
    if (view == null || state == null) {
      position.phase = const ClassroomPhase.doneEnd();
      return;
    }
    final activeState = state;
    if (!view.ended &&
        view.itemIdx == position.itemIdx &&
        view.layer == position.layer) {
      position.historia = view.historia;
      position.mainAdvances = view.mainAdvances;
      position.erros = view.erros;
      position.phase = const ClassroomPhase.loading();
      await materialController.carregar(
        lessonLocalId: lessonLocalId,
        topic: topic,
        position: position,
        idioma: idioma,
        academic: academic,
        mode: _modeForNextMaterial(activeState, position.isReviewAtivo),
        baseItems: baseItems,
        forceRefresh: true,
      );
      return;
    }

    position.loadingLayer = view.layer;
    position.itemIdx = view.itemIdx;
    position.layer = view.layer;
    position.erros = view.erros;
    position.historia = view.historia;
    position.mainAdvances = view.mainAdvances;
    if (view.ended) {
      position.phase = const ClassroomPhase.doneEnd();
      stateService.appendEvent(
        lessonLocalId,
        StudentLearningEvent(
          type: 'FINAL_COMPLETION_ALLOWED',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: {
            'itemIdx': view.itemIdx,
            'layer': view.layer.value,
            'totalItens': baseItems.length,
            'mainAdvances': view.mainAdvances,
          },
        ),
      );
      return;
    }

    materialService.maintainLessonReadyWindow(
      lessonLocalId: lessonLocalId,
      topic: topic,
      itemIdx: view.itemIdx,
      layer: view.layer,
      items: baseItems
          .map(
            (item) => DopamineWindowItem(text: item.text, marker: item.marker),
          )
          .toList(),
      source: 'cyber.aula.after-answer',
      priority: 'background',
      reason: 'answer_advanced_position',
    );
    position.phase = const ClassroomPhase.loading();
    await materialController.carregar(
      lessonLocalId: lessonLocalId,
      topic: topic,
      position: position,
      idioma: idioma,
      academic: academic,
      mode: _modeForNextMaterial(activeState, position.isReviewAtivo),
      baseItems: baseItems,
    );
  }

  LessonMode _modeForNextMaterial(
    StudentLearningState state,
    bool isReviewAtivo,
  ) {
    if (isReviewAtivo) return LessonMode.reforco;
    final amparoLvl = state.progress?.amparoLvl ?? 0;
    if (amparoLvl > 0) return LessonMode.amparo;
    final nextAction = state.extra['next_action'];
    if (nextAction is Map && nextAction['action'] == 'needsReinforcement') {
      return LessonMode.reforco;
    }
    return LessonMode.session;
  }
}
