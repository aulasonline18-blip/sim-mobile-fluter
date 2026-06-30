import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/cloud/cloud_functions.dart';
import 'package:sim_mobile/sim/cloud/cloud_queue.dart';
import 'package:sim_mobile/sim/cloud/supabase_client_contract.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_state_service.dart';
import 'package:sim_mobile/sim/state/student_state_store.dart';

void main() {
  test('student_state_roundtrip_test preserves the full student life', () {
    final state = _richState();
    final restored = StudentLearningState.fromJson(state.toJson());

    expect(restored.lessonLocalId, state.lessonLocalId);
    expect(restored.userId, 'user-1');
    expect(restored.curriculum?.items.map((item) => item.marker), ['M1', 'M2']);
    expect(restored.current?.marker, 'M2');
    expect(restored.current?.layer, LessonLayer.l2);
    expect(restored.progress?.itemIdx, 1);
    expect(restored.progress?.layer, LessonLayer.l2);
    expect(restored.progress?.concluidos, ['M1']);
    expect(restored.progress?.pendentesMarkers, ['M2']);
    expect(restored.attempts.single.sinal, DecisionSignal.two);
    expect(restored.truth.itemConsolidationStatus['M1'], 'mastered');
    expect(restored.auxRooms?['pendingMap'], isA<List>());
    expect(restored.currentLessonMaterial?['for_marker'], 'M2');
    expect(restored.readyLessonMaterials, contains('1:M2:L2'));
    expect(restored.syncStatus?.status, 'pending');
  });

  test(
    'simweb_backup_import_test imports Web backup and resumes same point',
    () {
      final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
      final backupText = _simWebBackupText();

      final state = store.importBackup(store.parseBackupText(backupText));

      expect(state.lessonLocalId, 'web-lesson-1');
      expect(state.profile.objetivo, 'Frações equivalentes');
      expect(state.profile.stableLang, 'pt-BR');
      expect(state.curriculum?.items.map((item) => item.marker), ['M1', 'M2']);
      expect(state.current?.marker, 'M2');
      expect(state.current?.layer, LessonLayer.l2);
      expect(state.progress?.itemIdx, 1);
      expect(state.progress?.layer, LessonLayer.l2);
      expect(state.attempts.single.marker, 'M1');
      expect(state.attempts.single.sinal, DecisionSignal.two);
      expect(state.truth.itemConsolidationStatus['M1'], 'mastered');
      expect(state.auxRooms?['pendingMap'], isA<List>());
      expect(state.currentLessonMaterial?['for_marker'], 'M2');
      expect(state.readyLessonMaterials, contains('1:M2:L2'));
      expect(store.listLocalStates(), hasLength(1));

      final reimported = store.importBackup(store.parseBackupText(backupText));
      expect(reimported.lessonLocalId, 'web-lesson-1');
      expect(store.listLocalStates(), hasLength(1));
    },
  );

  test('simapp_backup_roundtrip_test exports and imports without loss', () {
    final store = StudentStateStore(local: MemoryStudentStateLocalStorage());
    store.writeState(_richState());
    store.appendEvent(
      lessonLocalId: 'lesson-1',
      type: 'BACKUP_EXPORT_STARTED',
      payload: const {'source': 'test'},
      source: 'test',
    );

    final backup = store.exportBackup('lesson-1');
    final restoredStore = StudentStateStore(
      local: MemoryStudentStateLocalStorage(),
    );
    final restored = restoredStore.importBackup(backup);

    expect(restored.lessonLocalId, 'lesson-1');
    expect(restored.current?.marker, 'M2');
    expect(restored.progress?.layer, LessonLayer.l2);
    expect(restored.attempts, hasLength(1));
    expect(restored.truth.itemConsolidationStatus['M1'], 'mastered');
    expect(restoredStore.getEventLog('lesson-1'), isNotEmpty);
  });

  test('multi_device_state_sync_test converges two devices safely', () async {
    final cloud = _MemoryCloud();
    final session = _Session();
    final deviceA = StudentLearningStateService(
      seed: {'lesson-1': _richState()},
    );
    final queueA = CloudQueue(
      storage: MemoryCloudQueueStorage(),
      stateService: deviceA,
      sessionProvider: session,
      cloudFunctions: cloud,
      now: () => 1000,
    );
    queueA.enqueueStudentStateSync(lessonLocalId: 'lesson-1');
    await queueA.drainQueue();

    final deviceB = StudentLearningStateService(
      seed: {'lesson-1': StudentLearningState.empty(lessonLocalId: 'lesson-1')},
    );
    final remote = await cloud.getStudentStateByLesson(
      'lesson-1',
      const SupabaseSession(accessToken: 'token', userId: 'user-1'),
    );
    deviceB.write(remote!.state!);
    expect(deviceB.read('lesson-1')?.current?.marker, 'M2');
    expect(deviceB.read('lesson-1')?.attempts, hasLength(1));

    final advanced = deviceB
        .read('lesson-1')!
        .copyWith(
          progress: deviceB
              .read('lesson-1')!
              .progress
              ?.copyWith(
                itemIdx: 2,
                layer: LessonLayer.l1,
                mainAdvances: 2,
                pctAvanco: 100,
              ),
          current: const LessonCurrent(
            itemIdx: 2,
            marker: null,
            layer: LessonLayer.l1,
            amparoLvl: 0,
          ),
        );
    deviceB.write(advanced);
    final queueB = CloudQueue(
      storage: MemoryCloudQueueStorage(),
      stateService: deviceB,
      sessionProvider: session,
      cloudFunctions: cloud,
      now: () => 2000,
    );
    queueB.enqueueStudentStateSync(lessonLocalId: 'lesson-1');
    await queueB.drainQueue();

    final rejected = PersistStudentStateResult.rejectedRegression(
      remoteState: cloud.states['lesson-1'],
      remoteHighWaterMark: scoreOfStudentLearningState(
        cloud.states['lesson-1'],
      ),
    );
    cloud.nextPersist = rejected;
    final queueAAfterRemoteAdvance = CloudQueue(
      storage: MemoryCloudQueueStorage(),
      stateService: deviceA,
      sessionProvider: session,
      cloudFunctions: cloud,
      now: () => 3000,
    );
    queueAAfterRemoteAdvance.enqueueStudentStateSync(lessonLocalId: 'lesson-1');
    await queueAAfterRemoteAdvance.drainQueue();

    expect(deviceA.read('lesson-1')?.progress?.itemIdx, 2);
    expect(deviceA.read('lesson-1')?.progress?.pctAvanco, 100);
  });
}

StudentLearningState _richState() {
  const attempt = LessonAttempt(
    marker: 'M1',
    layer: LessonLayer.l1,
    letra: AnswerLetter.A,
    sinal: DecisionSignal.two,
    correct: true,
    ts: 10,
  );
  return StudentLearningState.empty(
    lessonLocalId: 'lesson-1',
    userId: 'user-1',
    now: 1,
  ).copyWith(
    updatedAt: 20,
    profile: const StudentProfile(
      objetivo: 'Frações equivalentes',
      stableLang: 'pt-BR',
      academicLevel: 'fundamental',
    ),
    curriculum: const StudentCurriculum(
      topic: 'Frações equivalentes',
      totalItems: 2,
      generatedAt: 1,
      provisional: false,
      items: [
        CurriculumItem(marker: 'M1', text: 'Reconhecer metade'),
        CurriculumItem(marker: 'M2', text: 'Comparar frações'),
      ],
    ),
    current: const LessonCurrent(
      itemIdx: 1,
      marker: 'M2',
      layer: LessonLayer.l2,
      amparoLvl: 0,
    ),
    progress: const LessonProgress(
      itemIdx: 1,
      layer: LessonLayer.l2,
      erros: 0,
      amparoLvl: 0,
      historia: ['M1'],
      mainAdvances: 1,
      concluidos: ['M1'],
      pendentesMarkers: ['M2'],
      totalItems: 2,
      pctAvanco: 50,
    ),
    attempts: const [attempt],
    events: const [
      StudentLearningEvent(
        type: 'ANSWER_SUBMITTED',
        ts: 10,
        payload: {'marker': 'M1', 'sinal': 2},
      ),
    ],
    auxRooms: const {
      'pendingMap': [
        {'marker': 'M2', 'signal': 2, 'status': 'pending'},
      ],
    },
    currentLessonMaterial: const {
      'text_status': 'ready',
      'explanation': 'Texto',
      'question': 'Pergunta?',
      'options': {'A': 'A', 'B': 'B', 'C': 'C'},
      'correct_answer': 'A',
      'for_itemIdx': 1,
      'for_marker': 'M2',
      'for_layer': 2,
    },
    readyLessonMaterials: const {
      '1:M2:L2': {'text_status': 'ready', 'for_marker': 'M2'},
    },
    truth: const StudentMasteryTruth(
      itemConsolidationStatus: {'M1': 'mastered'},
      masteryEvidence: [
        {'marker_id': 'M1', 'status': 'mastered'},
      ],
    ),
    syncStatus: const StudentSyncStatus(
      status: 'pending',
      pendingJobs: 1,
      highWaterMark: 1120,
      updatedAt: 20,
    ),
  );
}

String _simWebBackupText() {
  final webState = _richState()
      .copyWith(lessonLocalId: 'web-lesson-1')
      .toJson();
  webState['current_lesson_material'] = webState.remove(
    'currentLessonMaterial',
  );
  webState['ready_lesson_materials'] = webState.remove('readyLessonMaterials');
  webState['queued_actions'] = [
    {'type': 'SYNC_CLOUD', 'status': 'queued'},
  ];
  webState['syncInfo'] = {'lastMirrorAt': 20, 'deviceHint': 'web'};
  final backup = {
    'magic': 'SIM_CYBER_BACKUP_V1',
    'exportedAt': 20,
    'lessons': [
      {
        'id': 'web-lesson-1',
        'onboarding': {
          'objetivo': 'Frações equivalentes',
          'stable_lang': 'pt-BR',
          'academic_level': 'fundamental',
        },
        'curriculo': [
          {'marker': 'M1', 'text': 'Reconhecer metade'},
          {'marker': 'M2', 'text': 'Comparar frações'},
        ],
      },
    ],
    'studentLearningStates': {'web-lesson-1': webState},
  };
  final encoded = base64.encode(utf8.encode(jsonEncode(backup)));
  return [
    'SIM — BACKUP DE AULA',
    'SIM_CYBER_V1_BEGIN',
    encoded,
    'SIM_CYBER_V1_END',
  ].join('\n');
}

class _Session implements SupabaseSessionProvider {
  @override
  Future<SupabaseSession?> currentSession() async =>
      const SupabaseSession(accessToken: 'token', userId: 'user-1');
}

class _MemoryCloud implements StudentStateCloudFunctions {
  final states = <String, StudentLearningState>{};
  PersistStudentStateResult? nextPersist;

  @override
  Future<void> deleteStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {
    states.remove(lessonLocalId);
  }

  @override
  Future<StudentStateRow?> getStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  ) async {
    final state = states[lessonLocalId];
    if (state == null) return null;
    return StudentStateRow(
      lessonLocalId: lessonLocalId,
      state: state,
      highWaterMark: scoreOfStudentLearningState(state),
      schemaVersion: state.stateVersion,
    );
  }

  @override
  Future<List<StudentStateRow>> listStudentStates(
    SupabaseSession session,
  ) async {
    return [
      for (final state in states.values)
        StudentStateRow(
          lessonLocalId: state.lessonLocalId,
          state: state,
          highWaterMark: scoreOfStudentLearningState(state),
          schemaVersion: state.stateVersion,
        ),
    ];
  }

  @override
  Future<List<StudentStateSummaryRow>> listStudentStateSummaries(
    SupabaseSession session,
  ) async {
    return [
      for (final row in await listStudentStates(session))
        if (summarizeStudentStateRow(row) != null)
          summarizeStudentStateRow(row)!,
    ];
  }

  @override
  Future<PersistStudentStateResult> persistStudentState(
    PersistStudentStateInput input,
    SupabaseSession session,
  ) async {
    final next = nextPersist;
    nextPersist = null;
    if (next != null) return next;
    states[input.lessonLocalId] = input.state;
    return PersistStudentStateResult.accepted(
      lessonLocalId: input.lessonLocalId,
      highWaterMark: input.clientScore,
      schemaVersion: input.schemaVersion,
    );
  }
}
