import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/mastery_truth_engine.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

void main() {
  StudentLearningState stateWithAttempts(List<LessonAttempt> attempts) {
    return StudentLearningState.empty(
      lessonLocalId: 'lesson-1',
      now: 1,
    ).copyWith(attempts: attempts);
  }

  LessonAttempt attempt({
    required bool correct,
    required int ts,
    DecisionSignal sinal = DecisionSignal.three,
  }) {
    return LessonAttempt(
      marker: 'M1',
      layer: LessonLayer.l1,
      letra: AnswerLetter.A,
      sinal: sinal,
      correct: correct,
      ts: ts,
    );
  }

  test('StateStore persiste, relê e registra Event Log canonico', () {
    var clock = 10;
    var ids = 0;
    final store = StudentStateStore(
      local: MemoryStudentStateLocalStorage(),
      now: () => clock++,
      idFactory: () => 'event-${ids++}',
    );

    store.patchState('lesson-1', (state) {
      return state.copyWith(
        profile: state.profile.copyWith(objetivo: 'Frações'),
      );
    });
    final event = store.appendEvent(
      lessonLocalId: 'lesson-1',
      type: 'OBJECTIVE_SUBMITTED',
      payload: const {'objetivo': 'Frações', 'language': 'Portuguese'},
      source: 'test',
    );

    expect(event.eventId, 'event-0');
    expect(store.readState('lesson-1').profile.objetivo, 'Frações');
    expect(store.getEventLog('lesson-1').single.type, 'OBJECTIVE_SUBMITTED');

    final secondStore = StudentStateStore(
      local: store.local,
      now: () => clock++,
    );
    expect(secondStore.readState('lesson-1').profile.objetivo, 'Frações');
    expect(secondStore.getEventLog('lesson-1').single.eventId, 'event-0');
  });

  test(
    'StateStore exporta/importa backup e evita evento duplicado no replay',
    () {
      var ids = 0;
      final store = StudentStateStore(
        local: MemoryStudentStateLocalStorage(),
        idFactory: () => 'event-${ids++}',
        now: () => 100 + ids,
      );
      store.appendEvent(
        lessonLocalId: 'lesson-1',
        type: 'ANSWER_SUBMITTED',
        source: 'test',
        payload: {'attempt': attempt(correct: true, ts: 1).toJson()},
      );
      final backup = store.exportBackup('lesson-1');
      final imported = StudentStateStore(
        local: MemoryStudentStateLocalStorage(),
        now: () => 200,
      ).importBackup(backup);

      expect(imported.lessonLocalId, 'lesson-1');
      expect(imported.events, isNotEmpty);

      final replayed = store.replayEvents(
        seed: StudentLearningState.empty(lessonLocalId: 'lesson-1', now: 1),
        events: [
          ...store.getEventLog('lesson-1'),
          ...store.getEventLog('lesson-1'),
        ],
      );
      expect(replayed.attempts.length, 1);
    },
  );

  test('StateStore resolve conflito mantendo estado mais avancado', () {
    final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
    final local = StudentLearningState.empty(lessonLocalId: 'lesson-1', now: 1)
        .copyWith(
          progress: const LessonProgress(
            itemIdx: 2,
            layer: LessonLayer.l2,
            erros: 0,
            amparoLvl: 0,
            historia: [],
            mainAdvances: 2,
            concluidos: ['M1', 'M2'],
            pendentesMarkers: [],
            totalItems: 5,
            pctAvanco: 40,
          ),
        );
    final cloud = StudentLearningState.empty(lessonLocalId: 'lesson-1', now: 2)
        .copyWith(
          progress: const LessonProgress(
            itemIdx: 1,
            layer: LessonLayer.l3,
            erros: 0,
            amparoLvl: 0,
            historia: [],
            mainAdvances: 1,
            concluidos: ['M1'],
            pendentesMarkers: [],
            totalItems: 5,
            pctAvanco: 20,
          ),
        );

    expect(store.resolveConflict(local, cloud), StateConflictResolution.local);
    expect(store.syncState(local, cloud).progress?.itemIdx, 2);
  });

  test('MasteryTruthEngine nao aceita um acerto isolado como dominio', () {
    const engine = MasteryTruthEngine();
    final evidence = engine.evaluateMarker(
      stateWithAttempts([attempt(correct: true, ts: 1)]),
      'M1',
    );

    expect(evidence.status, MasteryStatus.learning);
    expect(evidence.needsReview, isTrue);
  });

  test('MasteryTruthEngine marca dominio apenas com evidencia suficiente', () {
    const engine = MasteryTruthEngine();
    final evidence = engine.evaluateMarker(
      stateWithAttempts([
        attempt(correct: true, ts: 1),
        attempt(correct: true, ts: 2),
        attempt(correct: true, ts: 3),
      ]),
      'M1',
    );

    expect(evidence.status, MasteryStatus.mastered);
    expect(evidence.needsReinforcement, isFalse);
  });

  test('MasteryTruthEngine detecta fraqueza e falsa maestria', () {
    const engine = MasteryTruthEngine();

    final weak = engine.evaluateMarker(
      stateWithAttempts([
        attempt(correct: false, ts: 1),
        attempt(correct: false, ts: 2),
      ]),
      'M1',
    );
    expect(weak.status, MasteryStatus.weak);
    expect(weak.needsReinforcement, isTrue);

    final falseMastery = engine.evaluateMarker(
      stateWithAttempts([
        attempt(correct: false, ts: 3, sinal: DecisionSignal.one),
      ]),
      'M1',
    );
    expect(falseMastery.status, MasteryStatus.falseMastery);
  });

  test('MasteryTruthEngine escreve verdade pedagogica no Estado', () {
    const engine = MasteryTruthEngine();
    final state = stateWithAttempts([attempt(correct: false, ts: 1)]);
    final evidence = engine.evaluateMarker(state, 'M1');
    final next = engine.writeTruthToState(state, evidence);

    expect(next.extra['truth'], isA<Map>());
    expect(
      ((next.extra['truth'] as Map)['item_consolidation_status'] as Map)['M1'],
      evidence.status.name,
    );
  });
}
