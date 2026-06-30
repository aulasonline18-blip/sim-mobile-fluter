import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_models.dart';
import 'package:sim_mobile/sim/auxiliary/aux_room_t02_caller.dart';
import 'package:sim_mobile/sim/auxiliary/aux_rooms_controller.dart';
import 'package:sim_mobile/sim/auxiliary/doubt_input_sheet.dart';
import 'package:sim_mobile/sim/auxiliary/doubt_t02_caller.dart';
import 'package:sim_mobile/sim/auxiliary/lesson_doubt_controller.dart';
import 'package:sim_mobile/sim/auxiliary/lesson_recovery_gate.dart';
import 'package:sim_mobile/sim/auxiliary/recovery_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/review_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_room_service.dart';
import 'package:sim_mobile/sim/auxiliary/student_aux_rooms.dart';
import 'package:sim_mobile/sim/modules/pedagogical_module_contracts.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

class FakeT02Client implements T02LessonClient {
  FakeT02Client({this.visualTrigger});

  final JsonMap? visualTrigger;
  int doubtCalls = 0;
  int auxCalls = 0;
  T02LessonRequest? lastDoubtRequest;

  T02LessonMaterial _material(String source) => T02LessonMaterial(
    explanation: 'Explicacao $source',
    question: 'Pergunta $source',
    options: const {
      AnswerLetter.A: 'Opcao A',
      AnswerLetter.B: 'Opcao B',
      AnswerLetter.C: 'Opcao C',
    },
    correctAnswer: AnswerLetter.B,
    whyCorrect: 'Porque B.',
    whyWrong: const {},
    generatedAt: DateTime(2026),
    source: source,
    visualTrigger: visualTrigger,
  );

  @override
  Future<T02LessonMaterial> auxiliaryRoom(T02LessonRequest request) async {
    auxCalls += 1;
    return _material(request.mode);
  }

  @override
  Future<T02LessonMaterial> completeLesson(T02LessonRequest request) async {
    return _material('complete');
  }

  @override
  Future<T02LessonMaterial> doubt(T02LessonRequest request) async {
    doubtCalls += 1;
    lastDoubtRequest = request;
    return _material('doubt');
  }

  @override
  Future<T02LessonMaterial> placement(T02LessonRequest request) async {
    return _material('placement');
  }
}

StudentLearningState seedState() {
  final now = DateTime(2026).millisecondsSinceEpoch;
  return StudentLearningState.empty(lessonLocalId: 'l1', now: now).copyWith(
    profile: const StudentProfile(
      stableLang: 'Portuguese',
      academicLevel: 'ensino_medio',
      preferredName: 'Aluno',
    ),
    curriculum: StudentCurriculum(
      topic: 'Matematica',
      totalItems: 3,
      generatedAt: now,
      provisional: false,
      items: const [
        CurriculumItem(marker: 'M1', text: 'Item 1'),
        CurriculumItem(marker: 'M2', text: 'Item 2'),
        CurriculumItem(marker: 'M3', text: 'Item 3'),
      ],
    ),
    progress: const LessonProgress(
      itemIdx: 0,
      layer: LessonLayer.l1,
      erros: 0,
      amparoLvl: 0,
      historia: [],
      mainAdvances: 0,
      concluidos: [],
      pendentesMarkers: [],
      totalItems: 3,
      pctAvanco: 0,
    ),
    current: const LessonCurrent(
      itemIdx: 0,
      marker: 'M1',
      layer: LessonLayer.l1,
      amparoLvl: 0,
    ),
  );
}

void main() {
  test('doubt input preserves validation and text limit', () {
    expect(const DoubtInputDraft().validate(), emptyDoubtMessage);
    expect(
      const DoubtInputDraft(
        image: DoubtImagePayload(
          name: 'x.txt',
          type: 'text/plain',
          size: 4,
          dataUrl: 'data:text/plain,abc',
        ),
      ).validate(),
      imageOnlyMessage,
    );
    final long = DoubtInputDraft(text: 'a' * 1400);
    expect(long.cleanText.length, doubtTextMaxLength);
  });

  test('doubt controller sends valid doubt to T02 doubt mode', () async {
    final client = FakeT02Client();
    final controller = LessonDoubtController(
      caller: DoubtT02Caller(client: client),
    );

    await controller.submitDoubt(
      lessonLocalId: 'l1',
      profile: const AuxRoomProfile(stableLang: 'Portuguese'),
      itemText: 'Item 1',
      currentContent: 'Conteudo atual',
      layer: LessonLayer.l1,
      itemIdx: 0,
      marker: 'M1',
      input: const DoubtInputDraft(text: 'Nao entendi.'),
    );

    expect(client.doubtCalls, 1);
    expect(controller.state.status, DoubtStatus.explaining);
    expect(controller.state.response?.explanation, 'Explicacao doubt');
  });

  test('doubt with photo preserves optional free visual trigger', () async {
    final trigger = <String, dynamic>{
      'needs_image': true,
      'pedagogical_need': 'helpful',
      'render_strategy': 'software',
      'svg_payload':
          '<svg viewBox="0 0 10 10"><circle cx="5" cy="5" r="4"/></svg>',
    };
    final client = FakeT02Client(visualTrigger: trigger);
    final controller = LessonDoubtController(
      caller: DoubtT02Caller(client: client),
    );

    await controller.submitDoubt(
      lessonLocalId: 'l1',
      profile: const AuxRoomProfile(stableLang: 'Portuguese'),
      itemText: 'Item 1',
      currentContent: 'Conteudo atual',
      layer: LessonLayer.l1,
      itemIdx: 0,
      marker: 'M1',
      input: const DoubtInputDraft(
        text: 'Pode explicar pela foto?',
        image: DoubtImagePayload(
          name: 'foto.png',
          type: 'image/png',
          size: 64,
          dataUrl: 'data:image/png;base64,AAAA',
        ),
      ),
    );

    expect(client.doubtCalls, 1);
    expect(client.lastDoubtRequest?.profile['doubt_image'], {
      'name': 'foto.png',
      'type': 'image/png',
      'size': 64,
      'hasDataUrl': true,
    });
    expect(controller.state.response?.visualTrigger, trigger);
  });

  test('aux pending map registers and clears live pending items', () {
    var state = seedState();
    state = registerPendingFromAttempt(
      state,
      LessonAttempt(
        marker: 'M1',
        layer: LessonLayer.l1,
        letra: AnswerLetter.A,
        sinal: DecisionSignal.three,
        correct: false,
        ts: 1,
      ),
    );
    expect(pendingMapOf(ensureAuxRooms(state)).single['status'], 'pending');

    state = clearPendingIfSignalOne(state, 'M1', LessonLayer.l1);
    expect(pendingMapOf(ensureAuxRooms(state)).single['status'], 'cleared');
  });

  test('review room builds queue, answers, and completes', () async {
    final client = FakeT02Client();
    final states = {'l1': seedState()};
    final service = StudentAuxRoomService(
      readState: (id) => states[id]!,
      writeState: (state) => states[state.lessonLocalId] = state,
      t02Caller: AuxRoomT02Caller(client: client),
    );
    final review = ReviewRoomService(service);
    final context = ReviewRoomContext(
      lessonLocalId: 'l1',
      topic: 'Matematica',
      items: const [
        AuxRoomItem(marker: 'M1', text: 'Item 1'),
        AuxRoomItem(marker: 'M2', text: 'Item 2'),
      ],
      fallbackStartIdx: 0,
      layer: LessonLayer.l1,
      profile: const AuxRoomProfile(stableLang: 'Portuguese'),
    );

    var view = await review.startReviewRoom(context, 5);
    expect(view.status, ReviewRoomStatus.ready);
    expect(client.auxCalls, 1);
    view = review.selectLetter(view, AnswerLetter.B);
    view = review.answerReviewRoom(context, view, DecisionSignal.one);
    expect(view.status, ReviewRoomStatus.result);
    expect(view.resultCorrect, true);
  });

  test(
    'recovery room starts only when pending blocks final completion',
    () async {
      final client = FakeT02Client();
      final states = {'l1': seedState()};
      states['l1'] = registerPendingFromAttempt(
        states['l1']!,
        LessonAttempt(
          marker: 'M2',
          layer: LessonLayer.l1,
          letra: AnswerLetter.A,
          sinal: DecisionSignal.three,
          correct: false,
          ts: 1,
        ),
      );
      final service = StudentAuxRoomService(
        readState: (id) => states[id]!,
        writeState: (state) => states[state.lessonLocalId] = state,
        t02Caller: AuxRoomT02Caller(client: client),
      );
      final recovery = RecoveryRoomService(service);
      final context = RecoveryRoomContext(
        lessonLocalId: 'l1',
        topic: 'Matematica',
        items: const [
          AuxRoomItem(marker: 'M1', text: 'Item 1'),
          AuxRoomItem(marker: 'M2', text: 'Item 2'),
        ],
        layer: LessonLayer.l1,
        profile: const AuxRoomProfile(stableLang: 'Portuguese'),
      );

      expect(isFinalBlockedByRecovery(recovery, 'l1'), true);
      var view = await recovery.startRecoveryRoom(context);
      expect(view.status, RecoveryRoomStatus.intro);
      view = recovery.continueRecovery(view);
      view = recovery.selectLetter(view, AnswerLetter.B);
      view = recovery.answerRecoveryRoom(context, view, DecisionSignal.one);
      expect(view.status, RecoveryRoomStatus.result);
      expect(view.resultCorrect, true);
    },
  );

  test('aux rooms controller preserves review and recovery commands', () async {
    final client = FakeT02Client();
    final states = {'l1': seedState()};
    final service = StudentAuxRoomService(
      readState: (id) => states[id]!,
      writeState: (state) => states[state.lessonLocalId] = state,
      t02Caller: AuxRoomT02Caller(client: client),
    );
    final controller = AuxRoomsController(
      reviewRoomService: ReviewRoomService(service),
      recoveryRoomService: RecoveryRoomService(service),
    );
    final reviewContext = ReviewRoomContext(
      lessonLocalId: 'l1',
      topic: 'Matematica',
      items: const [AuxRoomItem(marker: 'M1', text: 'Item 1')],
      fallbackStartIdx: 0,
      layer: LessonLayer.l1,
      profile: const AuxRoomProfile(),
    );

    await controller.startReview(reviewContext, 5);
    controller.reviewSelecionar(AnswerLetter.B);
    controller.reviewEnviarSinal(reviewContext, DecisionSignal.one);
    expect(controller.review.status, ReviewRoomStatus.result);
  });
}
