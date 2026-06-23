import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/state/internal_organs_governor.dart';
import 'package:sim_mobile/sim/state/mastery_truth_engine.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';
import 'package:sim_mobile/sim/state/student_learning_governor.dart';
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
      idFactory: () => 'evt-${++id}',
    );
  });

  test('midia escreve no StateStore e no diario canonico', () {
    final media = MediaStateGovernor(store: store);

    media.requestAudio(
      lessonLocalId: 'lesson-1',
      text: 'Texto da aula',
      marker: 'm1',
    );
    media.audioReady(
      lessonLocalId: 'lesson-1',
      audioUrl: 'https://audio.local/aula.mp3',
      marker: 'm1',
    );
    media.offerPaidImage(lessonLocalId: 'lesson-1', cost: 10, marker: 'm1');
    media.imageReady(
      lessonLocalId: 'lesson-1',
      imageUrl: 'https://image.local/aula.png',
      marker: 'm1',
    );

    final state = store.readState('lesson-1');
    final mediaState = state.extra['media'] as Map;
    expect((mediaState['audio'] as Map)['status'], 'ready');
    expect((mediaState['audio'] as Map)['event_id'], 'evt-2');
    expect((mediaState['image_offer'] as Map)['cost'], 10);
    expect((mediaState['image'] as Map)['image_url'], contains('aula.png'));
    expect(state.extra['foundation']['revision'], 4);
    expect(
      store.getEventLog('lesson-1').map((event) => event.type),
      containsAll([
        'AUDIO_REQUESTED',
        'AUDIO_READY',
        'PAID_IMAGE_OFFERED',
        'IMAGE_READY',
      ]),
    );
  });

  test('creditos reservam, capturam e reembolsam no estado vivo', () {
    final credits = CreditStateGovernor(store: store);

    credits.reserve(
      lessonLocalId: 'lesson-1',
      amount: 10,
      reason: 'imagem paga',
      operationId: 'img-1',
    );
    credits.capture(
      lessonLocalId: 'lesson-1',
      amount: 10,
      reason: 'imagem gerada',
      operationId: 'img-1',
    );
    credits.refund(
      lessonLocalId: 'lesson-1',
      amount: 3,
      reason: 'ajuste',
      operationId: 'adj-1',
    );

    final state = store.readState('lesson-1');
    final creditState = state.extra['credits'] as Map;
    expect(creditState['reserved'], 0);
    expect(creditState['spent'], 10);
    expect(creditState['refunded'], 3);
    expect(creditState['ledger'], hasLength(3));
    expect((creditState['ledger'] as List).last['event_id'], 'evt-3');
    expect(state.extra['foundation']['revision'], 3);
    expect(
      store.getEventLog('lesson-1').map((event) => event.type),
      containsAll(['CREDIT_RESERVED', 'CREDIT_CAPTURED', 'CREDIT_REFUNDED']),
    );
  });

  test('credito com mesmo operationId nao duplica ledger nem saldo', () {
    final credits = CreditStateGovernor(store: store);

    final first = credits.reserve(
      lessonLocalId: 'lesson-1',
      amount: 10,
      reason: 'imagem paga',
      operationId: 'img-1',
    );
    final duplicate = credits.reserve(
      lessonLocalId: 'lesson-1',
      amount: 10,
      reason: 'imagem paga',
      operationId: 'img-1',
    );

    final creditState = store.readState('lesson-1').extra['credits'] as Map;
    expect(first.type, 'CREDIT_RESERVED');
    expect(duplicate.type, 'CREDIT_OPERATION_DUPLICATE');
    expect(creditState['reserved'], 10);
    expect(creditState['ledger'], hasLength(1));
  });

  test('verdade pedagogica abre revisao ou recuperacao', () {
    final auxiliary = AuxiliaryStateGovernor(store: store);

    final review = const MasteryEvidence(
      marker: 'm-review',
      status: MasteryStatus.reviewNeeded,
      reason: 'precisa revisar',
      score: 2,
      consecutiveCorrect: 1,
      consecutiveWrong: 0,
      attemptCount: 1,
      needsReview: true,
      needsReinforcement: false,
    );
    final recovery = const MasteryEvidence(
      marker: 'm-recovery',
      status: MasteryStatus.weak,
      reason: 'erro repetido',
      score: -4,
      consecutiveCorrect: 0,
      consecutiveWrong: 2,
      attemptCount: 2,
      needsReview: false,
      needsReinforcement: true,
    );

    auxiliary.routeFromTruth(lessonLocalId: 'lesson-1', evidence: review);
    auxiliary.routeFromTruth(lessonLocalId: 'lesson-1', evidence: recovery);

    final aux = store.readState('lesson-1').auxRooms!;
    expect(aux['review_queue'], hasLength(1));
    expect(aux['recovery_queue'], hasLength(1));
    expect(store.readState('lesson-1').extra['foundation']['revision'], 2);
    expect(
      store.getEventLog('lesson-1').map((event) => event.type),
      containsAll(['REVIEW_SCHEDULED', 'RECOVERY_REQUIRED']),
    );
  });

  test('sync real passa pelo StateStore', () async {
    final sync = SyncStateGovernor(store: store);

    store.patchState(
      'lesson-1',
      (state) => state.copyWith(extra: {...state.extra, 'seed': true}),
    );
    final event = await sync.syncToCloud(lessonLocalId: 'lesson-1');

    expect(event.type, 'SYNC_COMPLETED');
    expect(cloud.states['lesson-1']?.extra['seed'], isTrue);
    expect(store.readState('lesson-1').extra['sync']['status'], 'synced');
    expect(store.readState('lesson-1').extra['sync']['direction'], 'push');
    expect(
      store.readState('lesson-1').extra['foundation']['last_event_type'],
      'SYNC_COMPLETED',
    );
    expect(
      store.getEventLog('lesson-1').map((event) => event.type),
      containsAll(['SYNC_STARTED', 'SYNC_COMPLETED']),
    );
  });

  test(
    'decision audit registra sugestao e comparacao sem aplicar progresso',
    () {
      _seedActiveLesson(store, lessonLocalId: 'lesson-1');
      final audit = DecisionAuditGovernor(store: store);

      final before = store.readState('lesson-1').progress?.itemIdx;
      final result = audit.suggestAndCompare(lessonLocalId: 'lesson-1');
      final after = store.readState('lesson-1').progress?.itemIdx;

      expect(result.suggested.type, 'DECISION_ENGINE_SUGGESTED');
      expect(result.compared.type, 'DECISION_ENGINE_COMPARED');
      expect(before, after);
      expect(
        store
            .readState('lesson-1')
            .extra['decision_audit']['last_compared']['matched'],
        isTrue,
      );
      expect(
        store.getEventLog('lesson-1').map((event) => event.type),
        containsAll(['DECISION_ENGINE_SUGGESTED', 'DECISION_ENGINE_COMPARED']),
      );
    },
  );

  test(
    'placement governor grava estado e espelho legado como evento canonico',
    () {
      final placement = PlacementStateGovernor(store: store);

      final event = placement.updatePlacement(
        lessonLocalId: 'lesson-1',
        placement: const {
          'status': 'completed',
          'blocks': [],
          'answers': [
            {'marker': 'M1', 'correct': true},
          ],
          'result': {'start_marker': 'M2'},
          'start_marker': 'M2',
          'index': 1,
          'source': 't02',
          'limited': false,
          'started_at': 10,
          'finished_at': 20,
        },
      );

      final state = store.readState('lesson-1');
      expect(event.type, 'PLACEMENT_UPDATED');
      expect(state.placement?['start_marker'], 'M2');
      expect(state.profile.extra['pretest_status'], 'completed');
      expect(state.profile.extra['start_marker'], 'M2');
    },
  );

  test('resposta, verdade, decisao e sala auxiliar usam o mesmo estado', () {
    final state = StudentLearningState.empty(lessonLocalId: 'lesson-1')
        .copyWith(
          curriculum: StudentCurriculum(
            topic: 'Matematica',
            totalItems: 1,
            generatedAt: 1,
            provisional: false,
            items: const [
              CurriculumItem(marker: 'm1', text: 'Somar numeros naturais'),
            ],
          ),
          current: const LessonCurrent(
            itemIdx: 0,
            marker: 'm1',
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
            pendentesMarkers: ['m1'],
            totalItems: 1,
            pctAvanco: 0,
          ),
        );
    store.writeState(state);

    final learning = StudentLearningGovernor(store: store);
    final auxiliary = AuxiliaryStateGovernor(store: store);
    final result = learning.submitAnswer(
      lessonLocalId: 'lesson-1',
      selected: AnswerLetter.A,
      correctAnswer: AnswerLetter.B,
      signal: DecisionSignal.one,
    );
    auxiliary.routeFromTruth(
      lessonLocalId: 'lesson-1',
      evidence: result.mastery,
    );

    final after = store.readState('lesson-1');
    expect(after.attempts, hasLength(1));
    expect(
      after.events.map((event) => event.type),
      contains('ANSWER_SUBMITTED'),
    );
    final truth = after.extra['truth'] as Map;
    expect((truth['item_consolidation_status'] as Map)['m1'], isNotNull);
    expect(after.auxRooms!['recovery_queue'], hasLength(1));
    expect(
      store.getEventLog('lesson-1').map((event) => event.type),
      containsAll([
        'ANSWER_SUBMITTED',
        'MASTERY_EVALUATED',
        'NEXT_ACTION_DECIDED',
        'RECOVERY_REQUIRED',
      ]),
    );
  });

  test(
    'coordenador assenta resposta ate auxiliar e sync no mesmo estado',
    () async {
      _seedActiveLesson(store, lessonLocalId: 'lesson-1');
      final coordinator = InternalOrgansCoordinator(store: store);

      final result = await coordinator.submitAnswerAndSettle(
        lessonLocalId: 'lesson-1',
        selected: AnswerLetter.A,
        correctAnswer: AnswerLetter.B,
        signal: DecisionSignal.one,
      );

      expect(result.learning.mastery.needsReinforcement, isTrue);
      expect(result.auxiliaryEvent.type, 'RECOVERY_REQUIRED');
      expect(result.syncEvent?.type, 'SYNC_COMPLETED');
      expect(
        cloud.states['lesson-1']?.auxRooms?['recovery_queue'],
        hasLength(1),
      );
      expect(
        store.getEventLog('lesson-1').map((event) => event.type),
        containsAll([
          'ANSWER_SUBMITTED',
          'MASTERY_EVALUATED',
          'NEXT_ACTION_DECIDED',
          'RECOVERY_REQUIRED',
          'SYNC_STARTED',
          'SYNC_COMPLETED',
        ]),
      );
    },
  );

  test('imagem paga real captura creditos e sincroniza', () async {
    final coordinator = InternalOrgansCoordinator(store: store);

    final result = await coordinator.requestPaidImage(
      lessonLocalId: 'lesson-1',
      prompt: 'desenhe a celula',
      cost: 10,
      marker: 'm1',
      operationId: 'img-1',
      generateImage: () async => 'https://cdn.sim/aula.png',
    );

    expect(result.completed, isTrue);
    expect(result.syncEvent?.type, 'SYNC_COMPLETED');
    final state = store.readState('lesson-1');
    expect(state.extra['media']['image']['status'], 'ready');
    expect(state.extra['credits']['spent'], 10);
    expect(state.extra['credits']['reserved'], 0);
    expect(
      cloud.states['lesson-1']?.extra['media']['image']['status'],
      'ready',
    );
  });

  test(
    'imagem paga falha sem fingir sucesso e devolve credito reservado',
    () async {
      final coordinator = InternalOrgansCoordinator(store: store);

      final result = await coordinator.requestPaidImage(
        lessonLocalId: 'lesson-1',
        prompt: 'desenhe a celula',
        cost: 10,
        marker: 'm1',
        operationId: 'img-1',
        generateImage: () async => throw StateError('servidor indisponivel'),
      );

      expect(result.failed, isTrue);
      final state = store.readState('lesson-1');
      expect(state.extra['media']['image']['status'], 'failed');
      expect(state.extra['credits']['refunded'], 10);
      expect(state.extra['credits']['reserved'], 0);
      expect(
        store.getEventLog('lesson-1').map((event) => event.type),
        containsAll(['MEDIA_FAILED', 'CREDIT_REFUNDED', 'SYNC_COMPLETED']),
      );
    },
  );

  test(
    'audio sem chamada real fica pendente, com chamada real fica pronto',
    () async {
      final coordinator = InternalOrgansCoordinator(store: store);

      final pending = await coordinator.requestLessonAudio(
        lessonLocalId: 'lesson-1',
        text: 'Texto da aula',
        marker: 'm1',
      );
      expect(pending.pending, isTrue);
      expect(
        store.readState('lesson-1').extra['media']['audio']['status'],
        'requested',
      );

      final ready = await coordinator.requestLessonAudio(
        lessonLocalId: 'lesson-1',
        text: 'Texto da aula',
        marker: 'm1',
        synthesizeAudio: () async => 'https://cdn.sim/aula.mp3',
      );
      expect(ready.completed, isTrue);
      expect(
        store.readState('lesson-1').extra['media']['audio']['status'],
        'ready',
      );
    },
  );

  test('duvida entra no Estado, sincroniza e preserva historico', () async {
    final coordinator = InternalOrgansCoordinator(store: store);

    final result = await coordinator.askDoubt(
      lessonLocalId: 'lesson-1',
      text: 'Por que essa alternativa esta errada?',
      marker: 'm1',
      hasImage: true,
      answerDoubt: () async => 'Porque ela troca causa por consequencia.',
    );

    expect(result.completed, isTrue);
    expect(result.syncEvent?.type, 'SYNC_COMPLETED');
    final doubt = store.readState('lesson-1').extra['doubt'] as Map;
    expect(doubt['status'], 'answered');
    expect(doubt['has_image'], isTrue);
    expect(doubt['history'], hasLength(3));
    expect(cloud.states['lesson-1']?.extra['doubt']['status'], 'answered');
    expect(
      store.getEventLog('lesson-1').map((event) => event.type),
      containsAll([
        'DOUBT_OPENED',
        'DOUBT_SUBMITTED',
        'DOUBT_ANSWER_READY',
        'SYNC_COMPLETED',
      ]),
    );
  });

  test('duvida falha sem fingir explicacao pronta', () async {
    final coordinator = InternalOrgansCoordinator(store: store);

    final result = await coordinator.askDoubt(
      lessonLocalId: 'lesson-1',
      text: 'Nao entendi.',
      marker: 'm1',
      answerDoubt: () async => throw StateError('T02 indisponivel'),
    );

    expect(result.failed, isTrue);
    final doubt = store.readState('lesson-1').extra['doubt'] as Map;
    expect(doubt['status'], 'failed');
    expect(doubt['answer'], isNull);
    expect(
      store.getEventLog('lesson-1').map((event) => event.type),
      containsAll(['DOUBT_ANSWER_FAILED', 'SYNC_COMPLETED']),
    );
  });

  test('evento de resposta carrega attempt suficiente para replay', () {
    _seedActiveLesson(store, lessonLocalId: 'lesson-1');
    final learning = StudentLearningGovernor(store: store);

    learning.submitAnswer(
      lessonLocalId: 'lesson-1',
      selected: AnswerLetter.C,
      correctAnswer: AnswerLetter.C,
      signal: DecisionSignal.two,
    );
    final events = store.getEventLog('lesson-1');
    final answerEvent = events.firstWhere(
      (event) => event.type == 'ANSWER_SUBMITTED',
    );

    expect(answerEvent.payload['attempt'], isA<Map>());
    final replayed = store.replayEvents(
      seed: StudentLearningState.empty(lessonLocalId: 'lesson-replay'),
      events: events,
    );
    expect(replayed.attempts, hasLength(1));
    expect(replayed.attempts.single.marker, 'm1');
    expect(replayed.attempts.single.correct, isTrue);
  });
}

void _seedActiveLesson(
  StudentStateStore store, {
  required String lessonLocalId,
}) {
  final state = StudentLearningState.empty(lessonLocalId: lessonLocalId)
      .copyWith(
        curriculum: StudentCurriculum(
          topic: 'Matematica',
          totalItems: 1,
          generatedAt: 1,
          provisional: false,
          items: const [
            CurriculumItem(marker: 'm1', text: 'Somar numeros naturais'),
          ],
        ),
        current: const LessonCurrent(
          itemIdx: 0,
          marker: 'm1',
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
          pendentesMarkers: ['m1'],
          totalItems: 1,
          pctAvanco: 0,
        ),
      );
  store.writeState(state);
}
