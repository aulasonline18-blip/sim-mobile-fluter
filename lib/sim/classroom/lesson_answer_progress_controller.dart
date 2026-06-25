import '../lesson/dopamine_ready_window_engine.dart';
import '../lesson/lesson_models.dart';
import '../lesson/student_lesson_material_service.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import '../state/student_lesson_executor.dart';
import 'classroom_models.dart';
import 'lesson_answer_feedback.dart';
import 'lesson_material_controller.dart';
import 'lesson_position_engine.dart';

class LessonAnswerProgressController {
  LessonAnswerProgressController({
    required this.stateService,
    required this.materialService,
    required this.materialController,
  });

  final StudentLearningStateService stateService;
  final StudentLessonMaterialService materialService;
  final LessonMaterialController materialController;

  void selecionar({
    required String lessonLocalId,
    required LessonPositionState position,
    required AnswerLetter letter,
  }) {
    if (position.phase.type != ClassroomPhaseType.lendo &&
        position.phase.type != ClassroomPhaseType.expandida) {
      return;
    }
    position.phase = ClassroomPhase.expanded(letter);
    final content = position.conteudo;
    final item = position.itemAtivo;
    if (content == null || item == null) return;
    final correct = letter == content.correctAnswer;
    final ts = DateTime.now().millisecondsSinceEpoch;
    stateService.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: 'ANSWER_SUBMITTED',
        ts: ts,
        payload: {
          'marker': item.marker,
          'layer': position.layer.value,
          'letra': letter.name,
          'correct': correct,
        },
      ),
    );
    stateService.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: 'FEEDBACK_SHOWN',
        ts: ts,
        payload: {
          'marker': item.marker,
          'layer': position.layer.value,
          'letra': letter.name,
          'correct': correct,
          'why_correct': content.whyCorrect,
          'why_wrong': content.whyWrong,
        },
      ),
    );
  }

  void enviarSinal({
    required String lessonLocalId,
    required String? topic,
    required LessonPositionState position,
    required DecisionSignal signal,
    required List<PlannedItem> baseItems,
  }) {
    final phase = position.phase;
    final content = position.conteudo;
    final item = position.itemAtivo;
    if (phase.type != ClassroomPhaseType.expandida ||
        phase.letter == null ||
        content == null ||
        item == null) {
      return;
    }

    final letter = phase.letter!;
    final correct = letter == content.correctAnswer;
    final ts = DateTime.now().millisecondsSinceEpoch;
    stateService.appendEvent(
      lessonLocalId,
      StudentLearningEvent(
        type: 'QUALIFIER_SUBMITTED',
        ts: ts,
        payload: {
          'marker': item.marker,
          'layer': position.layer.value,
          'letra': letter.name,
          'sinal': signal.value,
          'correct': correct,
        },
      ),
    );
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
            id: AnswerLetter.A, text: content.options[AnswerLetter.A] ?? ''),
        QuestionOptionEntry(
            id: AnswerLetter.B, text: content.options[AnswerLetter.B] ?? ''),
        QuestionOptionEntry(
            id: AnswerLetter.C, text: content.options[AnswerLetter.C] ?? ''),
      ],
      chosenOptionId: letter,
      correct: correct,
      imageUrl: position.imagem,
    );
    if (!position.history.any((old) =>
        old.id == entry.id && old.chosenOptionId == entry.chosenOptionId)) {
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
    final currentState = stateService.read(lessonLocalId);
    if (currentState != null && !position.isReviewAtivo) {
      final nextState = processAnswerWithEngine(
        currentState,
        AnswerContext(
          letra: letter,
          sinal: signal,
          correctAnswer: content.correctAnswer,
        ),
        now: ts,
      );
      stateService.write(nextState);
      final view = activeLessonView(nextState);
      if (view != null && !view.ended) {
        materialService.maintainLessonReadyWindow(
          lessonLocalId: lessonLocalId,
          topic: topic,
          itemIdx: view.itemIdx,
          layer: view.layer,
          items: baseItems
              .map((item) =>
                  DopamineWindowItem(text: item.text, marker: item.marker))
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
    final item = position.itemAtivo;
    if (item == null) {
      position.phase = const ClassroomPhase.doneEnd();
      return;
    }

    final state = stateService.read(lessonLocalId);
    final view = state == null ? null : activeLessonView(state);
    if (view == null) {
      position.phase = const ClassroomPhase.doneEnd();
      return;
    }
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
        mode: position.isReviewAtivo ? LessonMode.reforco : LessonMode.session,
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
          .map((item) =>
              DopamineWindowItem(text: item.text, marker: item.marker))
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
      mode: LessonMode.session,
      baseItems: baseItems,
    );
  }
}
