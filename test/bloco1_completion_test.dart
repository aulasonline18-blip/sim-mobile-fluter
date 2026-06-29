import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sim_mobile/sim/classroom/amparo_controller.dart';
import 'package:sim_mobile/sim/core/signal_tracker.dart';
import 'package:sim_mobile/sim/lesson/lesson_material_cache.dart';
import 'package:sim_mobile/sim/lesson/lesson_models.dart';
import 'package:sim_mobile/sim/state/learning_decision_engine.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

StudentLearningState _state({
  String lessonLocalId = 'bloco1',
  List<LessonAttempt> attempts = const [],
}) {
  const items = [
    CurriculumItem(marker: 'M1', text: 'Item 1'),
    CurriculumItem(marker: 'M2', text: 'Item 2'),
  ];
  return StudentLearningState.empty(lessonLocalId: lessonLocalId).copyWith(
    curriculum: const StudentCurriculum(
      topic: 'Matematica',
      totalItems: 2,
      generatedAt: null,
      provisional: false,
      items: items,
    ),
    current: const LessonCurrent(
      itemIdx: 0,
      marker: 'M1',
      layer: LessonLayer.l1,
      amparoLvl: 0,
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
      totalItems: 2,
      pctAvanco: 0,
    ),
    attempts: attempts,
  );
}

CompleteLesson _lesson(String text) {
  final content = LessonContent(
    explanation: text,
    question: 'Pergunta?',
    options: const {
      AnswerLetter.A: 'A',
      AnswerLetter.B: 'B',
      AnswerLetter.C: 'C',
    },
    correctAnswer: AnswerLetter.A,
  );
  return CompleteLesson(
    conteudo: content,
    imagem: 'data:image/png;base64,large',
    audioText: content.audioText,
  );
}

void main() {
  test('merge profundo une attempts duplicados e novos sem perda', () {
    const duplicated = LessonAttempt(
      marker: 'M1',
      layer: LessonLayer.l1,
      letra: AnswerLetter.A,
      sinal: DecisionSignal.one,
      correct: true,
      ts: 10,
    );
    const localOnly = LessonAttempt(
      marker: 'M1',
      layer: LessonLayer.l2,
      letra: AnswerLetter.B,
      sinal: DecisionSignal.two,
      correct: false,
      ts: 20,
    );
    const remoteOnly = LessonAttempt(
      marker: 'M2',
      layer: LessonLayer.l1,
      letra: AnswerLetter.C,
      sinal: DecisionSignal.three,
      correct: false,
      ts: 30,
    );

    final merged = mergeStudentLearningStateFromCloud(
      _state(attempts: const [duplicated, localOnly]),
      _state(attempts: const [duplicated, remoteOnly]),
    );

    expect(merged.attempts, hasLength(3));
    expect(merged.attempts.map((a) => a.ts), [10, 20, 30]);
  });

  test(
    'shadow decision grava auditoria uma vez sem se autoalimentar',
    () async {
      var runs = 0;
      late final StudentLearningStateService service;
      service = StudentLearningStateService(seed: {'bloco1': _state()})
        ..setShadowDecisionRunner((id) {
          runs++;
          runShadowDecision(id, service);
        });

      service.write(_state());
      await Future<void>.delayed(const Duration(milliseconds: 350));
      await Future<void>.delayed(const Duration(milliseconds: 350));

      final events = service.read('bloco1')!.events;
      expect(runs, 1);
      expect(events.map((event) => event.type), [
        'DECISION_ENGINE_SUGGESTED',
        'DECISION_ENGINE_COMPARED',
      ]);
    },
  );

  test('SignalTracker com tres sinais 3 dispara amparo real', () {
    final attempts = List<LessonAttempt>.generate(
      3,
      (index) => LessonAttempt(
        marker: 'M1',
        layer: LessonLayer.l1,
        letra: AnswerLetter.A,
        sinal: DecisionSignal.three,
        correct: true,
        ts: 100 + index,
      ),
    );
    final service = StudentLearningStateService(
      seed: {'bloco1': _state(attempts: attempts)},
    );
    final tracker = SignalTracker(service);
    final record = tracker.getByItem('M1');

    final next = const AmparoController().applyIfNeeded(
      state: _state(),
      correct: true,
      ts: 100,
      signalThreeCount: record?.s3 ?? 0,
    );

    expect(next.progress!.amparoLvl, 1);
    expect(next.events.single.type, 'AMPARO_TRIGGERED');
    expect(next.events.single.payload['trigger'], 'signal_tracker');
  });

  test(
    'LessonMaterialCache hidrata de SharedPreferences antes do primeiro uso',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = LessonMaterialCache();
      first.put('lesson-key', _lesson('Texto persistido'));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final hydrated = LessonMaterialCache();
      hydrated.hydrateFromPreferences(prefs);
      final cached = hydrated.peekCachedLesson('lesson-key');

      expect(cached, isNotNull);
      expect(cached!.conteudo.explanation, 'Texto persistido');
      expect(cached.imagem, isNull);
    },
  );
}
