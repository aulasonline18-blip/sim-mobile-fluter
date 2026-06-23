import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/cloud/supabase_client_contract.dart';
import 'package:sim_mobile/sim/state/foundation_identity.dart';
import 'package:sim_mobile/sim/state/foundation_sync.dart';
import 'package:sim_mobile/sim/state/mastery_truth_engine.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

void main() {
  late MemoryStudentStateLocalStorage local;
  late MemoryStudentStateCloudStorage cloud;
  late StudentStateStore store;

  setUp(() {
    var tick = 1000;
    var id = 0;
    local = MemoryStudentStateLocalStorage();
    cloud = MemoryStudentStateCloudStorage();
    store = StudentStateStore(
      local: local,
      cloud: cloud,
      now: () => tick++,
      idFactory: () => 'foundation-${++id}',
    );
  });

  test('identidade Google/Supabase vincula usuario ao estado e evento', () {
    final binder = FoundationIdentityBinder(store: store);

    final event = binder.bindSession(
      lessonLocalId: 'lesson-1',
      session: const SupabaseSession(accessToken: 'token', userId: 'user-1'),
      email: 'aluno@sim.local',
      displayName: 'Aluno SIM',
    );

    final state = store.readState('lesson-1');
    expect(event.type, 'IDENTITY_BOUND');
    expect(event.userId, 'user-1');
    expect(state.userId, 'user-1');
    expect(state.extra['identity']['email'], 'aluno@sim.local');
    expect(store.getEventLog('lesson-1').single.type, 'IDENTITY_BOUND');
  });

  test('mutacao atomica nao deixa evento sem estado nem estado sem evento', () {
    final event = store.mutateWithEvent(
      lessonLocalId: 'lesson-1',
      type: 'OBJECTIVE_SUBMITTED',
      source: 'foundation-test',
      payload: const {'objetivo': 'Geometria', 'language': 'Portuguese'},
      mutate: (state, event) => state.copyWith(
        profile: state.profile.copyWith(
          objetivo: event.payload['objetivo']?.toString(),
          stableLang: event.payload['language']?.toString(),
        ),
      ),
    );

    final state = store.readState('lesson-1');
    final log = store.getEventLog('lesson-1');

    expect(state.profile.objetivo, 'Geometria');
    expect(state.events.single.payload['event_id'], event.eventId);
    expect(log.single.eventId, event.eventId);
    expect(state.extra['foundation']['revision'], 1);
    expect(state.extra['foundation']['last_event_id'], event.eventId);
    expect(event.payload['foundation_revision_before'], 0);
    expect(event.payload['foundation_revision_after'], 1);
  });

  test('troca de identidade nao apaga historico e marca detach', () {
    final binder = FoundationIdentityBinder(store: store);

    binder.bindIdentity(
      lessonLocalId: 'lesson-1',
      identity: const StudentIdentity(userId: 'user-1'),
    );
    binder.detachIdentity(lessonLocalId: 'lesson-1');
    binder.bindIdentity(
      lessonLocalId: 'lesson-1',
      identity: const StudentIdentity(userId: 'user-2'),
    );

    final state = store.readState('lesson-1');
    expect(state.userId, 'user-2');
    expect(store.getEventLog('lesson-1').map((event) => event.type), [
      'IDENTITY_BOUND',
      'IDENTITY_DETACHED',
      'IDENTITY_BOUND',
    ]);
    expect(state.extra['foundation']['revision'], 3);
  });

  test('sync base fica registrado como fato canonico da fundacao', () {
    final sync = FoundationSyncRecorder(store: store);

    final pending = sync.recordPending(
      lessonLocalId: 'lesson-1',
      direction: 'push',
    );
    final completed = sync.recordCompleted(
      lessonLocalId: 'lesson-1',
      direction: 'push',
    );

    final state = store.readState('lesson-1');
    expect(state.extra['sync']['status'], 'synced');
    expect(state.extra['sync']['direction'], 'push');
    expect(state.extra['sync']['event_id'], completed.eventId);
    expect(store.getEventLog('lesson-1').map((event) => event.type), [
      'SYNC_STARTED',
      'SYNC_COMPLETED',
    ]);
    expect(pending.payload['foundation_revision_after'], 1);
    expect(completed.payload['foundation_revision_after'], 2);
  });

  test('replay reconstrói identidade, tentativa, verdade e sync', () {
    final binder = FoundationIdentityBinder(store: store);
    binder.bindIdentity(
      lessonLocalId: 'lesson-1',
      identity: const StudentIdentity(userId: 'user-1'),
    );
    store.appendEvent(
      lessonLocalId: 'lesson-1',
      type: 'ANSWER_SUBMITTED',
      source: 'test',
      payload: {
        'attempt': const LessonAttempt(
          marker: 'M1',
          layer: LessonLayer.l1,
          letra: AnswerLetter.A,
          sinal: DecisionSignal.three,
          correct: true,
          ts: 100,
        ).toJson(),
      },
    );
    store.appendEvent(
      lessonLocalId: 'lesson-1',
      type: 'MASTERY_EVALUATED',
      source: 'test',
      payload: const MasteryEvidence(
        marker: 'M1',
        status: MasteryStatus.learning,
        reason: 'um acerto isolado nao prova dominio',
        score: 3,
        consecutiveCorrect: 1,
        consecutiveWrong: 0,
        attemptCount: 1,
        needsReview: true,
        needsReinforcement: false,
      ).toJson(),
    );
    store.appendEvent(
      lessonLocalId: 'lesson-1',
      type: 'SYNC_COMPLETED',
      source: 'test',
      payload: const {'direction': 'push'},
    );

    final replayed = store.replayEvents(
      seed: StudentLearningState.empty(lessonLocalId: 'lesson-1'),
      events: store.getEventLog('lesson-1'),
    );

    expect(replayed.userId, 'user-1');
    expect(replayed.attempts, hasLength(1));
    expect(
      replayed.extra['truth']['item_consolidation_status']['M1'],
      'learning',
    );
    expect(replayed.extra['sync']['status'], 'synced');
    expect(replayed.extra['foundation']['revision'], 4);
    expect(replayed.extra['foundation']['last_event_type'], 'SYNC_COMPLETED');
  });

  test('backup preserva estado e diario fundacional importavel', () {
    final binder = FoundationIdentityBinder(store: store);
    binder.bindIdentity(
      lessonLocalId: 'lesson-1',
      identity: const StudentIdentity(userId: 'user-1'),
    );
    store.patchState(
      'lesson-1',
      (state) => state.copyWith(
        profile: state.profile.copyWith(
          objetivo: 'Algebra',
          stableLang: 'pt-BR',
        ),
      ),
    );

    final backup = store.exportBackup('lesson-1');
    final restoredStore = StudentStateStore(
      local: MemoryStudentStateLocalStorage(),
      now: () => 2000,
    );
    final restored = restoredStore.importBackup(backup);

    expect(restored.userId, 'user-1');
    expect(restored.profile.objetivo, 'Algebra');
    expect(restoredStore.getEventLog('lesson-1').single.type, 'IDENTITY_BOUND');
  });

  test('hydrateFromCloud respeita estado mais avancado da fundacao', () async {
    final localState =
        StudentLearningState.empty(lessonLocalId: 'lesson-1', now: 1).copyWith(
          userId: 'user-1',
          progress: const LessonProgress(
            itemIdx: 1,
            layer: LessonLayer.l1,
            erros: 0,
            amparoLvl: 0,
            historia: [],
            mainAdvances: 1,
            concluidos: ['M1'],
            pendentesMarkers: [],
            totalItems: 3,
            pctAvanco: 33,
          ),
        );
    final cloudState =
        StudentLearningState.empty(lessonLocalId: 'lesson-1', now: 2).copyWith(
          userId: 'user-1',
          progress: const LessonProgress(
            itemIdx: 2,
            layer: LessonLayer.l2,
            erros: 0,
            amparoLvl: 0,
            historia: [],
            mainAdvances: 2,
            concluidos: ['M1', 'M2'],
            pendentesMarkers: [],
            totalItems: 3,
            pctAvanco: 66,
          ),
        );
    store.writeState(localState);
    cloud.states['lesson-1'] = cloudState;

    final resolved = await store.hydrateFromCloud('lesson-1');

    expect(resolved.progress?.itemIdx, 2);
    expect(store.readState('lesson-1').progress?.itemIdx, 2);
  });
}
