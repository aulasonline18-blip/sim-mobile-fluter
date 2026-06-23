import '../lesson/lesson_models.dart';
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'classroom_models.dart';
import 'lesson_answer_progress_controller.dart';
import 'lesson_hydration_engine.dart';
import 'lesson_main_view_model.dart';
import 'lesson_material_controller.dart';
import 'lesson_position_engine.dart';
import 'lesson_session_engine.dart';

class LessonRuntimeSnapshot {
  const LessonRuntimeSnapshot({
    required this.authReady,
    required this.authed,
    required this.hasCurriculum,
    required this.isDone,
    required this.viewModel,
    required this.phase,
    required this.history,
    required this.conteudo,
    required this.itemMarker,
    required this.itemText,
  });

  final bool authReady;
  final bool authed;
  final bool hasCurriculum;
  final bool isDone;
  final LessonMainViewModel? viewModel;
  final ClassroomPhase phase;
  final List<QuestionHistoryEntry> history;
  final LessonContent? conteudo;
  final String? itemMarker;
  final String? itemText;
}

class LessonRuntimeEngine {
  LessonRuntimeEngine({
    required this.stateService,
    required this.sessionEngine,
    required this.hydrationEngine,
    required this.positionEngine,
    required this.materialController,
    required this.answerController,
  });

  final StudentLearningStateService stateService;
  final LessonSessionEngine sessionEngine;
  final LessonHydrationEngine hydrationEngine;
  final LessonPositionEngine positionEngine;
  final LessonMaterialController materialController;
  final LessonAnswerProgressController answerController;

  LessonPositionState? _position;
  LessonSessionSnapshot? _session;

  Future<LessonRuntimeSnapshot> open({
    required String lessonLocalId,
    bool authReady = true,
    bool authed = true,
  }) async {
    final session = sessionEngine.read(lessonLocalId);
    _session = session;
    if (!authReady || !authed) {
      return LessonRuntimeSnapshot(
        authReady: authReady,
        authed: authed,
        hasCurriculum: false,
        isDone: false,
        viewModel: null,
        phase: const ClassroomPhase.loading(),
        history: const [],
        conteudo: null,
        itemMarker: null,
        itemText: null,
      );
    }
    if (session.curriculum == null || session.baseItems.isEmpty) {
      return LessonRuntimeSnapshot(
        authReady: authReady,
        authed: authed,
        hasCurriculum: false,
        isDone: false,
        viewModel: null,
        phase: const ClassroomPhase.loading(),
        history: const [],
        conteudo: null,
        itemMarker: null,
        itemText: null,
      );
    }

    final hydration = hydrationEngine.hydrate(
      state: session.state,
      baseItems: session.baseItems,
      lessonLocalId: lessonLocalId,
      topic: session.curriculum?.topic ?? session.onboarding.objetivo,
      idioma: session.idioma,
      academic: session.academic,
    );
    final position = positionEngine.create(
      initialProgress: hydration.initialProgress,
      initialFastLesson: hydration.initialFastLesson,
      baseItems: session.baseItems,
    );
    _position = position;
    if (hydration.initialFastLesson == null && position.itemAtivo != null) {
      await materialController.carregar(
        lessonLocalId: lessonLocalId,
        topic: session.curriculum?.topic ?? session.onboarding.objetivo,
        position: position,
        idioma: session.idioma,
        academic: session.academic,
        mode: LessonMode.session,
        baseItems: session.baseItems,
      );
    }
    return snapshot();
  }

  void select(AnswerLetter letter) {
    final position = _position;
    if (position == null) return;
    answerController.selecionar(position, letter);
  }

  void signal(DecisionSignal signal) {
    final position = _position;
    final session = _session;
    if (position == null || session == null) return;
    answerController.enviarSinal(
      lessonLocalId: session.lessonLocalId,
      topic: session.curriculum?.topic ?? session.onboarding.objetivo,
      position: position,
      signal: signal,
      baseItems: session.baseItems,
    );
  }

  Future<void> advance() async {
    final position = _position;
    final session = _session;
    if (position == null || session == null) return;
    await answerController.avancar(
      lessonLocalId: session.lessonLocalId,
      topic: session.curriculum?.topic ?? session.onboarding.objetivo,
      position: position,
      baseItems: session.baseItems,
      idioma: session.idioma,
      academic: session.academic,
    );
  }

  LessonRuntimeSnapshot snapshot() {
    final position = _position;
    final session = _session;
    if (position == null || session == null) {
      return const LessonRuntimeSnapshot(
        authReady: true,
        authed: true,
        hasCurriculum: false,
        isDone: false,
        viewModel: null,
        phase: ClassroomPhase.loading(),
        history: [],
        conteudo: null,
        itemMarker: null,
        itemText: null,
      );
    }
    final vm = buildLessonMainViewModel(
      baseItems: session.baseItems,
      mainAdvances: position.mainAdvances,
      isReviewAtivo: position.isReviewAtivo,
      itemAtivo: position.itemAtivo,
      itemIdx: position.itemIdx,
      layer: position.layer,
      phase: position.phase,
      conteudo: position.conteudo,
      items: position.items,
    );
    return LessonRuntimeSnapshot(
      authReady: true,
      authed: true,
      hasCurriculum: session.curriculum != null && session.baseItems.isNotEmpty,
      isDone: position.phase.type == ClassroomPhaseType.fim,
      viewModel: vm,
      phase: position.phase,
      history: position.history,
      conteudo: position.conteudo,
      itemMarker: position.itemAtivo?.marker,
      itemText: position.itemAtivo?.text,
    );
  }
}
