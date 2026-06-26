import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/cloud/cloud_functions.dart';
import 'package:sim_mobile/sim/cloud/cloud_queue.dart';
import 'package:sim_mobile/sim/cloud/lesson_cloud_bootstrap.dart';
import 'package:sim_mobile/sim/cloud/lesson_curriculum_sync_engine.dart';
import 'package:sim_mobile/sim/cloud/student_learning_sync.dart';
import 'package:sim_mobile/sim/cloud/supabase_student_state_cloud_storage.dart';
import 'package:sim_mobile/sim/cloud/student_lesson_cloud_progress_service.dart';
import 'package:sim_mobile/sim/cloud/student_lesson_progress_service.dart';
import 'package:sim_mobile/sim/cloud/supabase_client_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';

class FakeSessionProvider implements SupabaseSessionProvider {
  SupabaseSession? session = const SupabaseSession(
    accessToken: 'token',
    userId: 'u1',
  );

  @override
  Future<SupabaseSession?> currentSession() async => session;
}

class FakeCloudFunctions implements StudentStateCloudFunctions {
  int persistCalls = 0;
  int deleteCalls = 0;
  PersistStudentStateResult? nextPersist;

  @override
  Future<void> deleteStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {
    deleteCalls += 1;
  }

  StudentLearningState? remoteState;
  SupabaseSession? lastSession;
  PersistStudentStateInput? lastPersistInput;

  @override
  Future<StudentStateRow?> getStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {
    lastSession = session;
    final state = remoteState;
    if (state == null || state.lessonLocalId != lessonLocalId) return null;
    return StudentStateRow(
      lessonLocalId: lessonLocalId,
      state: state,
      highWaterMark: scoreOfStudentLearningState(state),
      schemaVersion: studentLearningStateSchemaVersion,
    );
  }

  @override
  Future<List<StudentStateRow>> listStudentStates(
    SupabaseSession session,
  ) async {
    return const [];
  }

  @override
  Future<List<StudentStateSummaryRow>> listStudentStateSummaries(
    SupabaseSession session,
  ) async {
    return const [];
  }

  @override
  Future<PersistStudentStateResult> persistStudentState(
    PersistStudentStateInput input,
    SupabaseSession session,
  ) async {
    persistCalls += 1;
    lastSession = session;
    lastPersistInput = input;
    return nextPersist ??
        PersistStudentStateResult.accepted(
          lessonLocalId: input.lessonLocalId,
          highWaterMark: input.clientScore,
          schemaVersion: input.schemaVersion,
        );
  }
}

StudentLearningState stateWithProgress({
  required String id,
  required int itemIdx,
  required LessonLayer layer,
  required int mainAdvances,
}) {
  return StudentLearningState.empty(lessonLocalId: id, now: 1).copyWith(
    updatedAt: 1,
    profile: const StudentProfile(objetivo: 'Matematica', stableLang: 'pt-BR'),
    curriculum: StudentCurriculum(
      topic: 'Matematica',
      totalItems: 3,
      generatedAt: 1,
      provisional: false,
      items: const [
        CurriculumItem(marker: 'M1', text: 'Item 1'),
        CurriculumItem(marker: 'M2', text: 'Item 2'),
        CurriculumItem(marker: 'M3', text: 'Item 3'),
      ],
    ),
    current: LessonCurrent(
      itemIdx: itemIdx,
      marker: 'M$itemIdx',
      layer: layer,
      amparoLvl: 0,
    ),
    progress: LessonProgress(
      itemIdx: itemIdx,
      layer: layer,
      erros: 0,
      amparoLvl: 0,
      historia: const [],
      mainAdvances: mainAdvances,
      concluidos: const [],
      pendentesMarkers: const [],
      totalItems: 3,
      pctAvanco: 0,
    ),
  );
}

void main() {
  test(
    'supabase cloud storage loads and persists through authenticated session',
    () async {
      final cloud = FakeCloudFunctions()
        ..remoteState = stateWithProgress(
          id: 'l1',
          itemIdx: 2,
          layer: LessonLayer.l3,
          mainAdvances: 2,
        );
      final sessionProvider = FakeSessionProvider();
      final storage = SupabaseStudentStateCloudStorage(
        cloudFunctions: cloud,
        sessionProvider: sessionProvider,
      );

      final loaded = await storage.loadCloud('l1');
      expect(loaded?.progress?.itemIdx, 2);
      expect(cloud.lastSession?.userId, 'u1');

      final local = stateWithProgress(
        id: 'l1',
        itemIdx: 1,
        layer: LessonLayer.l2,
        mainAdvances: 1,
      );
      await storage.persistCloud(local);
      expect(cloud.persistCalls, 1);
      expect(cloud.lastPersistInput?.lessonLocalId, 'l1');
      expect(
        cloud.lastPersistInput?.clientScore,
        scoreOfStudentLearningState(local),
      );
    },
  );

  test(
    'supabase cloud storage is inert without authenticated session',
    () async {
      final cloud = FakeCloudFunctions();
      final sessionProvider = FakeSessionProvider()..session = null;
      final storage = SupabaseStudentStateCloudStorage(
        cloudFunctions: cloud,
        sessionProvider: sessionProvider,
      );

      expect(await storage.loadCloud('l1'), isNull);
      await storage.persistCloud(
        stateWithProgress(
          id: 'l1',
          itemIdx: 1,
          layer: LessonLayer.l1,
          mainAdvances: 1,
        ),
      );
      expect(cloud.persistCalls, 0);
    },
  );

  test('StudentLearningState serializes full snapshot for cloud sync', () {
    final state = stateWithProgress(
      id: 'l1',
      itemIdx: 1,
      layer: LessonLayer.l2,
      mainAdvances: 1,
    ).copyWith(auxRooms: {'pendingMap': []});

    final restored = StudentLearningState.fromJson(state.toJson());
    expect(restored.lessonLocalId, 'l1');
    expect(restored.progress?.layer, LessonLayer.l2);
    expect(restored.auxRooms?['pendingMap'], isA<List>());
  });

  test(
    'cloud queue persists patch and removes it after successful drain',
    () async {
      final states = StudentLearningStateService(
        seed: {
          'l1': stateWithProgress(
            id: 'l1',
            itemIdx: 1,
            layer: LessonLayer.l1,
            mainAdvances: 1,
          ),
        },
      );
      final cloud = FakeCloudFunctions();
      final queue = CloudQueue(
        storage: MemoryCloudQueueStorage(),
        stateService: states,
        sessionProvider: FakeSessionProvider(),
        cloudFunctions: cloud,
        now: () => 1000,
      );

      queue.enqueueStudentStateSync(lessonLocalId: 'l1');
      expect(queue.getQueueSnapshot(), contains('l1'));
      await queue.drainQueue();
      expect(cloud.persistCalls, 1);
      expect(queue.getQueueSnapshot(), isEmpty);
    },
  );

  test(
    'cloud queue merges remote state when server rejects regression',
    () async {
      final local = stateWithProgress(
        id: 'l1',
        itemIdx: 0,
        layer: LessonLayer.l1,
        mainAdvances: 0,
      );
      final remote = stateWithProgress(
        id: 'l1',
        itemIdx: 2,
        layer: LessonLayer.l3,
        mainAdvances: 2,
      );
      final states = StudentLearningStateService(seed: {'l1': local});
      final cloud = FakeCloudFunctions()
        ..nextPersist = PersistStudentStateResult.rejectedRegression(
          remoteState: remote,
          remoteHighWaterMark: 2003,
        );
      final queue = CloudQueue(
        storage: MemoryCloudQueueStorage(),
        stateService: states,
        sessionProvider: FakeSessionProvider(),
        cloudFunctions: cloud,
        now: () => 1000,
      );

      queue.enqueueStudentStateSync(lessonLocalId: 'l1');
      await queue.drainQueue();
      expect(states.read('l1')?.progress?.itemIdx, 2);
      expect(queue.getQueueSnapshot(), contains('l1'));
    },
  );

  test('progress service picks the most advanced progress', () {
    final saved = stateWithProgress(
      id: 'l1',
      itemIdx: 1,
      layer: LessonLayer.l1,
      mainAdvances: 1,
    ).progress;
    final official = stateWithProgress(
      id: 'l1',
      itemIdx: 2,
      layer: LessonLayer.l1,
      mainAdvances: 2,
    ).progress;

    expect(pickMostAdvancedLessonProgress(saved, official), official);
  });

  test('cloud progress publishes position and enqueues sync', () {
    final states = StudentLearningStateService(
      seed: {
        'l1': stateWithProgress(
          id: 'l1',
          itemIdx: 0,
          layer: LessonLayer.l1,
          mainAdvances: 0,
        ),
      },
    );
    final queue = CloudQueue(
      storage: MemoryCloudQueueStorage(),
      stateService: states,
      sessionProvider: FakeSessionProvider(),
      cloudFunctions: FakeCloudFunctions(),
      now: () => 1000,
    );
    final service = StudentLessonCloudProgressService(
      stateService: states,
      sync: StudentLearningSync(queue),
    );

    service.publishLessonProgress(
      const LessonCloudProgressInput(
        lessonLocalId: 'l1',
        itemIdx: 1,
        layer: LessonLayer.l2,
        totalItens: 3,
        mainAdvances: 1,
        markerAtual: 'M2',
      ),
    );

    expect(states.read('l1')?.current?.marker, 'M2');
    expect(queue.getQueueSnapshot(), contains('l1'));
  });

  test(
    'lesson cloud bootstrap enqueues and drains when curriculum is ready',
    () async {
      final states = StudentLearningStateService(
        seed: {
          'local-1': stateWithProgress(
            id: 'local-1',
            itemIdx: 0,
            layer: LessonLayer.l1,
            mainAdvances: 0,
          ),
        },
      );
      final cloud = FakeCloudFunctions();
      final queue = CloudQueue(
        storage: MemoryCloudQueueStorage(),
        stateService: states,
        sessionProvider: FakeSessionProvider(),
        cloudFunctions: cloud,
        now: () => 1000,
      );
      final bootstrap = LessonCloudBootstrap(sync: StudentLearningSync(queue));
      final ok = await bootstrap.run(
        LessonCloudBootstrapInput(
          curriculum: states.read('local-1')!.curriculum,
          onboarding: {'objetivo': 'Matematica', 'lessonLocalId': 'local-1'},
          itemIdx: 0,
          layer: LessonLayer.l1,
          mainAdvances: 0,
        ),
      );

      expect(ok, true);
      expect(cloud.persistCalls, 1);
    },
  );

  test('curriculum sync settles from official state when UI has none', () {
    final states = StudentLearningStateService(
      seed: {
        'l1': stateWithProgress(
          id: 'l1',
          itemIdx: 0,
          layer: LessonLayer.l1,
          mainAdvances: 0,
        ),
      },
    );
    final engine = LessonCurriculumSyncEngine(stateService: states);

    final snap = engine.refresh(lessonLocalId: 'l1');
    expect(snap.rehydrationSettled, true);
    expect(snap.curriculum?.items.length, 3);
  });
}
