import 'learning_decision_engine.dart';
import 'mastery_truth_engine.dart';
import 'foundation_sync.dart';
import 'student_learning_state.dart';
import 'student_learning_governor.dart';
import 'student_state_store.dart';

class MediaStateGovernor {
  MediaStateGovernor({required this.store});

  final StudentStateStore store;

  CanonicalLearningEvent requestAudio({
    required String lessonLocalId,
    required String text,
    String? marker,
    String source = 'media-state-governor',
  }) {
    return _recordMedia(
      lessonLocalId: lessonLocalId,
      type: 'AUDIO_REQUESTED',
      source: source,
      payload: _withOptional({'text': text}, 'marker', marker),
      kind: 'audio',
      value: {'status': 'requested', 'text': text},
      marker: marker,
    );
  }

  CanonicalLearningEvent audioReady({
    required String lessonLocalId,
    required String audioUrl,
    String? marker,
    String source = 'media-state-governor',
  }) {
    return _recordMedia(
      lessonLocalId: lessonLocalId,
      type: 'AUDIO_READY',
      source: source,
      payload: _withOptional({'audio_url': audioUrl}, 'marker', marker),
      kind: 'audio',
      value: {'status': 'ready', 'audio_url': audioUrl},
      marker: marker,
    );
  }

  CanonicalLearningEvent offerPaidImage({
    required String lessonLocalId,
    required int cost,
    String? marker,
    String source = 'media-state-governor',
  }) {
    return _recordMedia(
      lessonLocalId: lessonLocalId,
      type: 'PAID_IMAGE_OFFERED',
      source: source,
      payload: _withOptional({'cost': cost}, 'marker', marker),
      kind: 'image_offer',
      value: {'status': 'offered', 'cost': cost},
      marker: marker,
    );
  }

  CanonicalLearningEvent requestImage({
    required String lessonLocalId,
    required String prompt,
    String? marker,
    String source = 'media-state-governor',
  }) {
    return _recordMedia(
      lessonLocalId: lessonLocalId,
      type: 'IMAGE_REQUESTED',
      source: source,
      payload: _withOptional({'prompt': prompt}, 'marker', marker),
      kind: 'image',
      value: {'status': 'requested', 'prompt': prompt},
      marker: marker,
    );
  }

  CanonicalLearningEvent imageReady({
    required String lessonLocalId,
    required String imageUrl,
    String? marker,
    String source = 'media-state-governor',
  }) {
    return _recordMedia(
      lessonLocalId: lessonLocalId,
      type: 'IMAGE_READY',
      source: source,
      payload: _withOptional({'image_url': imageUrl}, 'marker', marker),
      kind: 'image',
      value: {'status': 'ready', 'image_url': imageUrl},
      marker: marker,
    );
  }

  CanonicalLearningEvent mediaFailed({
    required String lessonLocalId,
    required String kind,
    required String reason,
    String? marker,
    String source = 'media-state-governor',
  }) {
    return _recordMedia(
      lessonLocalId: lessonLocalId,
      type: 'MEDIA_FAILED',
      source: source,
      payload: {'kind': kind, 'reason': reason, ..._optional('marker', marker)},
      kind: kind,
      value: {'status': 'failed', 'reason': reason},
      marker: marker,
    );
  }

  CanonicalLearningEvent _recordMedia({
    required String lessonLocalId,
    required String type,
    required String source,
    required JsonMap payload,
    required String kind,
    required JsonMap value,
    String? marker,
  }) {
    return store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: type,
      source: source,
      payload: payload,
      mutate: (state, event) {
        final media = _map(state.extra['media']);
        return state.copyWith(
          extra: {
            ...state.extra,
            'media': {
              ...media,
              kind: {
                ...value,
                ..._optional('marker', marker),
                'updated_at': event.createdAt,
                'event_id': event.eventId,
              },
            },
          },
        );
      },
    );
  }
}

class CreditStateGovernor {
  CreditStateGovernor({required this.store});

  final StudentStateStore store;

  CanonicalLearningEvent reserve({
    required String lessonLocalId,
    required int amount,
    required String reason,
    String? operationId,
    String source = 'credit-state-governor',
  }) {
    if (_hasCreditOperation(lessonLocalId, 'CREDIT_RESERVED', operationId)) {
      return _duplicateCreditEvent(
        lessonLocalId: lessonLocalId,
        originalType: 'CREDIT_RESERVED',
        operationId: operationId,
        source: source,
      );
    }
    return _recordCredit(
      lessonLocalId: lessonLocalId,
      type: 'CREDIT_RESERVED',
      source: source,
      payload: {
        'amount': amount,
        'reason': reason,
        ..._optional('operation_id', operationId),
      },
      amount: amount,
      field: 'reserved',
      reservedDelta: amount,
      reason: reason,
      operationId: operationId,
    );
  }

  CanonicalLearningEvent capture({
    required String lessonLocalId,
    required int amount,
    required String reason,
    String? operationId,
    String source = 'credit-state-governor',
  }) {
    if (_hasCreditOperation(lessonLocalId, 'CREDIT_CAPTURED', operationId)) {
      return _duplicateCreditEvent(
        lessonLocalId: lessonLocalId,
        originalType: 'CREDIT_CAPTURED',
        operationId: operationId,
        source: source,
      );
    }
    return _recordCredit(
      lessonLocalId: lessonLocalId,
      type: 'CREDIT_CAPTURED',
      source: source,
      payload: {
        'amount': amount,
        'reason': reason,
        ..._optional('operation_id', operationId),
      },
      amount: amount,
      field: 'spent',
      reservedDelta: -amount,
      reason: reason,
      operationId: operationId,
    );
  }

  CanonicalLearningEvent refund({
    required String lessonLocalId,
    required int amount,
    required String reason,
    String? operationId,
    String source = 'credit-state-governor',
  }) {
    if (_hasCreditOperation(lessonLocalId, 'CREDIT_REFUNDED', operationId)) {
      return _duplicateCreditEvent(
        lessonLocalId: lessonLocalId,
        originalType: 'CREDIT_REFUNDED',
        operationId: operationId,
        source: source,
      );
    }
    return _recordCredit(
      lessonLocalId: lessonLocalId,
      type: 'CREDIT_REFUNDED',
      source: source,
      payload: {
        'amount': amount,
        'reason': reason,
        ..._optional('operation_id', operationId),
      },
      amount: amount,
      field: 'refunded',
      reservedDelta: -amount,
      reason: reason,
      operationId: operationId,
    );
  }

  CanonicalLearningEvent _recordCredit({
    required String lessonLocalId,
    required String type,
    required String source,
    required JsonMap payload,
    required int amount,
    required String field,
    required String reason,
    int reservedDelta = 0,
    String? operationId,
  }) {
    return store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: type,
      source: source,
      payload: payload,
      mutate: (state, event) {
        final credits = _map(state.extra['credits']);
        final ledger = _list(credits['ledger']);
        final reserved = _int(credits['reserved']) + reservedDelta;
        return state.copyWith(
          extra: {
            ...state.extra,
            'credits': {
              ...credits,
              field: _int(credits[field]) + amount,
              'reserved': reserved < 0 ? 0 : reserved,
              'ledger': [
                ...ledger,
                {
                  'event_id': event.eventId,
                  'type': event.type,
                  'amount': amount,
                  'reason': reason,
                  ..._optional('operation_id', operationId),
                  'created_at': event.createdAt,
                },
              ],
            },
          },
        );
      },
    );
  }

  bool _hasCreditOperation(
    String lessonLocalId,
    String type,
    String? operationId,
  ) {
    if (operationId == null || operationId.trim().isEmpty) return false;
    final credits = _map(store.readState(lessonLocalId).extra['credits']);
    return _list(credits['ledger']).any(
      (entry) =>
          entry is Map &&
          entry['type'] == type &&
          entry['operation_id'] == operationId,
    );
  }

  CanonicalLearningEvent _duplicateCreditEvent({
    required String lessonLocalId,
    required String originalType,
    required String? operationId,
    required String source,
  }) {
    return store.appendEvent(
      lessonLocalId: lessonLocalId,
      type: 'CREDIT_OPERATION_DUPLICATE',
      source: source,
      payload: {
        'original_type': originalType,
        ..._optional('operation_id', operationId),
      },
    );
  }
}

class AuxiliaryStateGovernor {
  AuxiliaryStateGovernor({required this.store});

  final StudentStateStore store;

  CanonicalLearningEvent routeFromTruth({
    required String lessonLocalId,
    required MasteryEvidence evidence,
    String source = 'auxiliary-state-governor',
  }) {
    if (evidence.needsReinforcement) {
      return requireRecovery(
        lessonLocalId: lessonLocalId,
        marker: evidence.marker,
        reason: evidence.reason,
        source: source,
      );
    }
    if (evidence.needsReview) {
      return scheduleReview(
        lessonLocalId: lessonLocalId,
        marker: evidence.marker,
        reason: evidence.reason,
        source: source,
      );
    }
    return store.appendEvent(
      lessonLocalId: lessonLocalId,
      type: 'AUX_ROOM_NOT_NEEDED',
      source: source,
      payload: evidence.toJson(),
    );
  }

  CanonicalLearningEvent scheduleReview({
    required String lessonLocalId,
    required String marker,
    required String reason,
    String source = 'auxiliary-state-governor',
  }) {
    return _recordAuxQueue(
      lessonLocalId: lessonLocalId,
      type: 'REVIEW_SCHEDULED',
      source: source,
      payload: {'marker': marker, 'reason': reason},
      queueName: 'review_queue',
      marker: marker,
      reason: reason,
    );
  }

  CanonicalLearningEvent requireRecovery({
    required String lessonLocalId,
    required String marker,
    required String reason,
    String source = 'auxiliary-state-governor',
  }) {
    return _recordAuxQueue(
      lessonLocalId: lessonLocalId,
      type: 'RECOVERY_REQUIRED',
      source: source,
      payload: {'marker': marker, 'reason': reason},
      queueName: 'recovery_queue',
      marker: marker,
      reason: reason,
    );
  }

  CanonicalLearningEvent completeAuxRoom({
    required String lessonLocalId,
    required String marker,
    required String room,
    String source = 'auxiliary-state-governor',
  }) {
    return store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: 'AUX_ROOM_COMPLETED',
      source: source,
      payload: {'marker': marker, 'room': room},
      mutate: (state, event) {
        final aux = _map(state.auxRooms);
        final completed = _list(aux['completed']);
        return state.copyWith(
          auxRooms: {
            ...aux,
            'completed': [
              ...completed,
              {
                'marker': marker,
                'room': room,
                'completed_at': event.createdAt,
                'event_id': event.eventId,
              },
            ],
          },
        );
      },
    );
  }

  CanonicalLearningEvent _recordAuxQueue({
    required String lessonLocalId,
    required String type,
    required String source,
    required JsonMap payload,
    required String queueName,
    required String marker,
    required String reason,
  }) {
    return store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: type,
      source: source,
      payload: payload,
      mutate: (state, event) {
        final aux = _map(state.auxRooms);
        final queue = _list(aux[queueName]);
        final exists = queue.any(
          (item) => item is Map && item['marker']?.toString() == marker,
        );
        final nextQueue = exists
            ? queue
            : [
                ...queue,
                {
                  'marker': marker,
                  'reason': reason,
                  'created_at': event.createdAt,
                  'event_id': event.eventId,
                },
              ];
        return state.copyWith(auxRooms: {...aux, queueName: nextQueue});
      },
    );
  }
}

class SyncStateGovernor {
  SyncStateGovernor({required this.store});

  final StudentStateStore store;

  Future<CanonicalLearningEvent> syncToCloud({
    required String lessonLocalId,
    String source = 'sync-state-governor',
  }) async {
    final recorder = FoundationSyncRecorder(store: store);
    recorder.recordPending(
      lessonLocalId: lessonLocalId,
      direction: 'push',
      source: source,
    );
    try {
      await store.persistCloud(lessonLocalId);
      return recorder.recordCompleted(
        lessonLocalId: lessonLocalId,
        direction: 'push',
        source: source,
      );
    } catch (error) {
      return recorder.recordFailed(
        lessonLocalId: lessonLocalId,
        direction: 'push',
        message: error.toString(),
        source: source,
      );
    }
  }

  Future<StudentLearningState> hydrateFromCloud({
    required String lessonLocalId,
    String source = 'sync-state-governor',
  }) async {
    final recorder = FoundationSyncRecorder(store: store);
    recorder.recordPending(
      lessonLocalId: lessonLocalId,
      direction: 'pull',
      source: source,
    );
    final state = await store.hydrateFromCloud(lessonLocalId);
    recorder.recordCompleted(
      lessonLocalId: lessonLocalId,
      direction: 'pull',
      source: source,
    );
    return state;
  }
}

class DecisionAuditGovernor {
  DecisionAuditGovernor({required this.store});

  final StudentStateStore store;

  ({CanonicalLearningEvent suggested, CanonicalLearningEvent compared})
  suggestAndCompare({
    required String lessonLocalId,
    int? actualItemIdx,
    LessonLayer? actualLayer,
    String source = 'decision-audit-governor',
  }) {
    final state = store.readState(lessonLocalId);
    final decision = decideNextActionFromState(state);
    final currentItemIdx =
        actualItemIdx ?? state.progress?.itemIdx ?? state.current?.itemIdx;
    final currentLayer =
        actualLayer ?? state.progress?.layer ?? state.current?.layer;
    final suggested = store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: 'DECISION_ENGINE_SUGGESTED',
      source: source,
      payload: {
        'currentItemIdx': currentItemIdx,
        'currentLayer': currentLayer?.value,
        'proposedItemIdx': decision.proposedItemIdx,
        'proposedLayer': decision.proposedLayer?.value,
        'proposedMarker': decision.proposedMarker,
        'actionType': decision.actionType.name,
        'confidence': decision.confidence.name,
        'reason': decision.reason,
      },
      mutate: (state, event) {
        final decisionAudit = _map(state.extra['decision_audit']);
        return state.copyWith(
          extra: {
            ...state.extra,
            'decision_audit': {
              ...decisionAudit,
              'last_suggested': {
                'event_id': event.eventId,
                'action_type': decision.actionType.name,
                'reason': decision.reason,
                'created_at': event.createdAt,
              },
            },
          },
        );
      },
    );
    final engineItemIdx = decision.proposedItemIdx ?? currentItemIdx;
    final engineLayer = decision.proposedLayer ?? currentLayer;
    final matched =
        engineItemIdx == currentItemIdx && engineLayer == currentLayer;
    final compared = store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: 'DECISION_ENGINE_COMPARED',
      source: source,
      payload: {
        'engineAction': decision.actionType.name,
        'actualItemIdx': currentItemIdx,
        'actualLayer': currentLayer?.value,
        'engineItemIdx': engineItemIdx,
        'engineLayer': engineLayer?.value,
        'matched': matched,
        'reason': decision.reason,
      },
      mutate: (state, event) {
        final decisionAudit = _map(state.extra['decision_audit']);
        return state.copyWith(
          extra: {
            ...state.extra,
            'decision_audit': {
              ...decisionAudit,
              'last_compared': {
                'event_id': event.eventId,
                'matched': matched,
                'created_at': event.createdAt,
              },
            },
          },
        );
      },
    );
    return (suggested: suggested, compared: compared);
  }
}

class PlacementStateGovernor {
  PlacementStateGovernor({required this.store});

  final StudentStateStore store;

  CanonicalLearningEvent updatePlacement({
    required String lessonLocalId,
    required JsonMap placement,
    String type = 'PLACEMENT_UPDATED',
    String source = 'placement-state-governor',
  }) {
    return store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: type,
      source: source,
      payload: {
        'status': placement['status'],
        'index': placement['index'],
        'answers': placement['answers'] is List
            ? (placement['answers'] as List).length
            : null,
        'start_marker': placement['start_marker'] ?? placement['startMarker'],
        'source': placement['source'],
        'limited': placement['limited'] == true,
      },
      mutate: (state, event) {
        final profileExtra = {
          ...state.profile.extra,
          'pretest_status': placement['status'],
          'pretest_blocks': placement['blocks'] ?? const [],
          'pretest_answers': placement['answers'] ?? const [],
          'pretest_result': placement['result'],
          'start_marker': placement['start_marker'] ?? placement['startMarker'],
          'pretest_index': placement['index'] ?? 0,
          'pretest_source': placement['source'],
          'pretest_limited': placement['limited'] == true,
          'pretest_started_at':
              placement['started_at'] ?? placement['startedAt'],
          'pretest_finished_at':
              placement['finished_at'] ?? placement['finishedAt'],
        };
        return state.copyWith(
          placement: {
            ...placement,
            'updated_at': event.createdAt,
            'event_id': event.eventId,
          },
          profile: state.profile.copyWith(extra: profileExtra),
        );
      },
    );
  }

  CanonicalLearningEvent resetPlacement({
    required String lessonLocalId,
    String source = 'placement-state-governor',
  }) {
    return updatePlacement(
      lessonLocalId: lessonLocalId,
      type: 'PLACEMENT_RESET',
      source: source,
      placement: const {
        'status': 'idle',
        'blocks': [],
        'answers': [],
        'result': null,
        'start_marker': null,
        'index': 0,
        'source': null,
        'limited': false,
        'started_at': null,
        'finished_at': null,
      },
    );
  }
}

class DoubtStateGovernor {
  DoubtStateGovernor({required this.store});

  final StudentStateStore store;

  CanonicalLearningEvent openDoubt({
    required String lessonLocalId,
    String? marker,
    String source = 'doubt-state-governor',
  }) {
    return _recordDoubt(
      lessonLocalId: lessonLocalId,
      type: 'DOUBT_OPENED',
      source: source,
      payload: _withOptional({'status': 'open'}, 'marker', marker),
      value: {'status': 'open'},
      marker: marker,
    );
  }

  CanonicalLearningEvent submitDoubt({
    required String lessonLocalId,
    required String text,
    String? marker,
    bool hasImage = false,
    String source = 'doubt-state-governor',
  }) {
    return _recordDoubt(
      lessonLocalId: lessonLocalId,
      type: 'DOUBT_SUBMITTED',
      source: source,
      payload: {
        'text': text,
        'has_image': hasImage,
        ..._optional('marker', marker),
      },
      value: {'status': 'submitted', 'text': text, 'has_image': hasImage},
      marker: marker,
    );
  }

  CanonicalLearningEvent answerReady({
    required String lessonLocalId,
    required String answer,
    String? marker,
    String source = 'doubt-state-governor',
  }) {
    return _recordDoubt(
      lessonLocalId: lessonLocalId,
      type: 'DOUBT_ANSWER_READY',
      source: source,
      payload: _withOptional({'answer': answer}, 'marker', marker),
      value: {'status': 'answered', 'answer': answer},
      marker: marker,
    );
  }

  CanonicalLearningEvent answerFailed({
    required String lessonLocalId,
    required String reason,
    String? marker,
    String source = 'doubt-state-governor',
  }) {
    return _recordDoubt(
      lessonLocalId: lessonLocalId,
      type: 'DOUBT_ANSWER_FAILED',
      source: source,
      payload: _withOptional({'reason': reason}, 'marker', marker),
      value: {'status': 'failed', 'reason': reason},
      marker: marker,
    );
  }

  CanonicalLearningEvent _recordDoubt({
    required String lessonLocalId,
    required String type,
    required String source,
    required JsonMap payload,
    required JsonMap value,
    String? marker,
  }) {
    return store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: type,
      source: source,
      payload: payload,
      mutate: (state, event) {
        final doubt = _map(state.extra['doubt']);
        final history = _list(doubt['history']);
        final nextValue = {
          ...value,
          ..._optional('marker', marker),
          'updated_at': event.createdAt,
          'event_id': event.eventId,
        };
        return state.copyWith(
          extra: {
            ...state.extra,
            'doubt': {
              ...doubt,
              ...nextValue,
              'history': [...history, nextValue],
            },
          },
        );
      },
    );
  }
}

class SettledAnswerResult {
  const SettledAnswerResult({
    required this.learning,
    required this.auxiliaryEvent,
    this.syncEvent,
  });

  final GovernedAnswerResult learning;
  final CanonicalLearningEvent auxiliaryEvent;
  final CanonicalLearningEvent? syncEvent;
}

class PaidImageFlowResult {
  const PaidImageFlowResult({
    required this.offerEvent,
    required this.reserveEvent,
    required this.requestEvent,
    this.readyEvent,
    this.captureEvent,
    this.failedEvent,
    this.refundEvent,
    this.syncEvent,
  });

  final CanonicalLearningEvent offerEvent;
  final CanonicalLearningEvent reserveEvent;
  final CanonicalLearningEvent requestEvent;
  final CanonicalLearningEvent? readyEvent;
  final CanonicalLearningEvent? captureEvent;
  final CanonicalLearningEvent? failedEvent;
  final CanonicalLearningEvent? refundEvent;
  final CanonicalLearningEvent? syncEvent;

  bool get completed => readyEvent != null && captureEvent != null;
  bool get failed => failedEvent != null;
  bool get pending => !completed && !failed;
}

class AudioFlowResult {
  const AudioFlowResult({
    required this.requestEvent,
    this.readyEvent,
    this.failedEvent,
    this.syncEvent,
  });

  final CanonicalLearningEvent requestEvent;
  final CanonicalLearningEvent? readyEvent;
  final CanonicalLearningEvent? failedEvent;
  final CanonicalLearningEvent? syncEvent;

  bool get completed => readyEvent != null;
  bool get failed => failedEvent != null;
  bool get pending => !completed && !failed;
}

class DoubtFlowResult {
  const DoubtFlowResult({
    required this.openEvent,
    required this.submitEvent,
    this.readyEvent,
    this.failedEvent,
    this.syncEvent,
  });

  final CanonicalLearningEvent openEvent;
  final CanonicalLearningEvent submitEvent;
  final CanonicalLearningEvent? readyEvent;
  final CanonicalLearningEvent? failedEvent;
  final CanonicalLearningEvent? syncEvent;

  bool get completed => readyEvent != null;
  bool get failed => failedEvent != null;
  bool get pending => !completed && !failed;
}

class InternalOrgansCoordinator {
  InternalOrgansCoordinator({
    required StudentStateStore store,
    StudentLearningGovernor? learning,
    AuxiliaryStateGovernor? auxiliary,
    MediaStateGovernor? media,
    CreditStateGovernor? credits,
    SyncStateGovernor? sync,
    DoubtStateGovernor? doubt,
    DecisionAuditGovernor? decisionAudit,
    PlacementStateGovernor? placement,
  }) : learning = learning ?? StudentLearningGovernor(store: store),
       auxiliary = auxiliary ?? AuxiliaryStateGovernor(store: store),
       media = media ?? MediaStateGovernor(store: store),
       credits = credits ?? CreditStateGovernor(store: store),
       sync = sync ?? SyncStateGovernor(store: store),
       doubt = doubt ?? DoubtStateGovernor(store: store),
       decisionAudit = decisionAudit ?? DecisionAuditGovernor(store: store),
       placement = placement ?? PlacementStateGovernor(store: store);

  final StudentLearningGovernor learning;
  final AuxiliaryStateGovernor auxiliary;
  final MediaStateGovernor media;
  final CreditStateGovernor credits;
  final SyncStateGovernor sync;
  final DoubtStateGovernor doubt;
  final DecisionAuditGovernor decisionAudit;
  final PlacementStateGovernor placement;

  Future<SettledAnswerResult> submitAnswerAndSettle({
    required String lessonLocalId,
    required AnswerLetter selected,
    required AnswerLetter correctAnswer,
    required DecisionSignal signal,
    bool syncAfter = true,
  }) async {
    final result = learning.submitAnswer(
      lessonLocalId: lessonLocalId,
      selected: selected,
      correctAnswer: correctAnswer,
      signal: signal,
      source: 'internal-organs-coordinator',
    );
    final auxEvent = auxiliary.routeFromTruth(
      lessonLocalId: lessonLocalId,
      evidence: result.mastery,
      source: 'internal-organs-coordinator',
    );
    decisionAudit.suggestAndCompare(
      lessonLocalId: lessonLocalId,
      source: 'internal-organs-coordinator',
    );
    final syncEvent = syncAfter
        ? await sync.syncToCloud(
            lessonLocalId: lessonLocalId,
            source: 'internal-organs-coordinator',
          )
        : null;
    return SettledAnswerResult(
      learning: result,
      auxiliaryEvent: auxEvent,
      syncEvent: syncEvent,
    );
  }

  Future<PaidImageFlowResult> requestPaidImage({
    required String lessonLocalId,
    required String prompt,
    required int cost,
    String? marker,
    String? operationId,
    Future<String> Function()? generateImage,
    bool syncAfter = true,
  }) async {
    final offer = media.offerPaidImage(
      lessonLocalId: lessonLocalId,
      cost: cost,
      marker: marker,
      source: 'internal-organs-coordinator',
    );
    final reserve = credits.reserve(
      lessonLocalId: lessonLocalId,
      amount: cost,
      reason: 'paid_lesson_image',
      operationId: operationId,
      source: 'internal-organs-coordinator',
    );
    final request = media.requestImage(
      lessonLocalId: lessonLocalId,
      prompt: prompt,
      marker: marker,
      source: 'internal-organs-coordinator',
    );

    if (generateImage == null) {
      return PaidImageFlowResult(
        offerEvent: offer,
        reserveEvent: reserve,
        requestEvent: request,
      );
    }

    try {
      final imageUrl = await generateImage();
      final ready = media.imageReady(
        lessonLocalId: lessonLocalId,
        imageUrl: imageUrl,
        marker: marker,
        source: 'internal-organs-coordinator',
      );
      final capture = credits.capture(
        lessonLocalId: lessonLocalId,
        amount: cost,
        reason: 'paid_lesson_image_ready',
        operationId: operationId,
        source: 'internal-organs-coordinator',
      );
      final syncEvent = syncAfter
          ? await sync.syncToCloud(
              lessonLocalId: lessonLocalId,
              source: 'internal-organs-coordinator',
            )
          : null;
      return PaidImageFlowResult(
        offerEvent: offer,
        reserveEvent: reserve,
        requestEvent: request,
        readyEvent: ready,
        captureEvent: capture,
        syncEvent: syncEvent,
      );
    } catch (error) {
      final failed = media.mediaFailed(
        lessonLocalId: lessonLocalId,
        kind: 'image',
        reason: error.toString(),
        marker: marker,
        source: 'internal-organs-coordinator',
      );
      final refund = credits.refund(
        lessonLocalId: lessonLocalId,
        amount: cost,
        reason: 'paid_lesson_image_failed',
        operationId: operationId,
        source: 'internal-organs-coordinator',
      );
      final syncEvent = syncAfter
          ? await sync.syncToCloud(
              lessonLocalId: lessonLocalId,
              source: 'internal-organs-coordinator',
            )
          : null;
      return PaidImageFlowResult(
        offerEvent: offer,
        reserveEvent: reserve,
        requestEvent: request,
        failedEvent: failed,
        refundEvent: refund,
        syncEvent: syncEvent,
      );
    }
  }

  Future<AudioFlowResult> requestLessonAudio({
    required String lessonLocalId,
    required String text,
    String? marker,
    Future<String> Function()? synthesizeAudio,
    bool syncAfter = true,
  }) async {
    final request = media.requestAudio(
      lessonLocalId: lessonLocalId,
      text: text,
      marker: marker,
      source: 'internal-organs-coordinator',
    );
    if (synthesizeAudio == null) {
      return AudioFlowResult(requestEvent: request);
    }
    try {
      final audioUrl = await synthesizeAudio();
      final ready = media.audioReady(
        lessonLocalId: lessonLocalId,
        audioUrl: audioUrl,
        marker: marker,
        source: 'internal-organs-coordinator',
      );
      final syncEvent = syncAfter
          ? await sync.syncToCloud(
              lessonLocalId: lessonLocalId,
              source: 'internal-organs-coordinator',
            )
          : null;
      return AudioFlowResult(
        requestEvent: request,
        readyEvent: ready,
        syncEvent: syncEvent,
      );
    } catch (error) {
      final failed = media.mediaFailed(
        lessonLocalId: lessonLocalId,
        kind: 'audio',
        reason: error.toString(),
        marker: marker,
        source: 'internal-organs-coordinator',
      );
      final syncEvent = syncAfter
          ? await sync.syncToCloud(
              lessonLocalId: lessonLocalId,
              source: 'internal-organs-coordinator',
            )
          : null;
      return AudioFlowResult(
        requestEvent: request,
        failedEvent: failed,
        syncEvent: syncEvent,
      );
    }
  }

  Future<DoubtFlowResult> askDoubt({
    required String lessonLocalId,
    required String text,
    String? marker,
    bool hasImage = false,
    Future<String> Function()? answerDoubt,
    bool syncAfter = true,
  }) async {
    final open = doubt.openDoubt(
      lessonLocalId: lessonLocalId,
      marker: marker,
      source: 'internal-organs-coordinator',
    );
    final submit = doubt.submitDoubt(
      lessonLocalId: lessonLocalId,
      text: text,
      marker: marker,
      hasImage: hasImage,
      source: 'internal-organs-coordinator',
    );
    if (answerDoubt == null) {
      return DoubtFlowResult(openEvent: open, submitEvent: submit);
    }
    try {
      final answer = await answerDoubt();
      final ready = doubt.answerReady(
        lessonLocalId: lessonLocalId,
        answer: answer,
        marker: marker,
        source: 'internal-organs-coordinator',
      );
      final syncEvent = syncAfter
          ? await sync.syncToCloud(
              lessonLocalId: lessonLocalId,
              source: 'internal-organs-coordinator',
            )
          : null;
      return DoubtFlowResult(
        openEvent: open,
        submitEvent: submit,
        readyEvent: ready,
        syncEvent: syncEvent,
      );
    } catch (error) {
      final failed = doubt.answerFailed(
        lessonLocalId: lessonLocalId,
        reason: error.toString(),
        marker: marker,
        source: 'internal-organs-coordinator',
      );
      final syncEvent = syncAfter
          ? await sync.syncToCloud(
              lessonLocalId: lessonLocalId,
              source: 'internal-organs-coordinator',
            )
          : null;
      return DoubtFlowResult(
        openEvent: open,
        submitEvent: submit,
        failedEvent: failed,
        syncEvent: syncEvent,
      );
    }
  }
}

JsonMap _map(Object? value) {
  if (value is Map) return JsonMap.from(value);
  return {};
}

JsonMap _optional(String key, Object? value) {
  if (value == null) return {};
  return {key: value};
}

JsonMap _withOptional(JsonMap map, String key, Object? value) {
  if (value == null) return map;
  return {...map, key: value};
}

List<dynamic> _list(Object? value) {
  if (value is List) return List<dynamic>.from(value);
  return <dynamic>[];
}

int _int(Object? value) {
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
