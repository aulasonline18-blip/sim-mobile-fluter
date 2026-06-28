import '../state/student_learning_state.dart';
import 'aux_room_models.dart';
import 'aux_room_t02_caller.dart';
import 'student_aux_rooms.dart' as aux_state;

class PreparedAuxRoomQuestion {
  const PreparedAuxRoomQuestion.ok(this.conteudo)
      : ok = true,
        error = null;

  const PreparedAuxRoomQuestion.failed(this.error)
      : ok = false,
        conteudo = null;

  final bool ok;
  final AuxRoomContent? conteudo;
  final String? error;
}

class StudentAuxRoomService {
  StudentAuxRoomService({
    required this.readState,
    required this.writeState,
    required this.t02Caller,
    this.auxRoomsEnabled = true,
    this.recoveryRoomEnabled = true,
  });

  final StudentLearningState Function(String lessonLocalId) readState;
  final StudentLearningState Function(StudentLearningState state) writeState;
  final AuxRoomT02Caller t02Caller;
  final bool auxRoomsEnabled;
  final bool recoveryRoomEnabled;

  List<AuxRoomItem> normalizeItems(List<AuxRoomItem> items) {
    return items
        .map(
          (item) => AuxRoomItem(
            marker: (item.marker ?? '').trim(),
            text: (item.text ?? '').trim(),
          ),
        )
        .where((item) => item.marker!.isNotEmpty && item.text!.isNotEmpty)
        .toList(growable: false);
  }

  AuxRoomItem? pickAuxRoomItem(String marker, List<AuxRoomItem> items) {
    for (final item in normalizeItems(items)) {
      if (item.marker == marker) return item;
    }
    return null;
  }

  List<String> buildReviewQueueForLesson({
    required String lessonLocalId,
    required String topic,
    required List<AuxRoomItem> items,
    required int count,
    required int fallbackStartIdx,
  }) {
    var state = readState(lessonLocalId);
    final normalized = normalizeItems(items);
    if (state.curriculum == null) {
      state = state.copyWith(
        curriculum: StudentCurriculum(
          topic: topic,
          totalItems: normalized.length,
          generatedAt: DateTime.now().millisecondsSinceEpoch,
          provisional: false,
          items: normalized
              .map(
                (item) => CurriculumItem(
                  marker: item.marker!,
                  text: item.text!,
                ),
              )
              .toList(growable: false),
        ),
      );
    }
    var queue = aux_state.buildReviewQueue(state, count);
    final now = DateTime.now().millisecondsSinceEpoch;
    state = state.copyWith(
      auxRooms: aux_state.ensureAuxRooms(state),
      events: [
        ...state.events,
        StudentLearningEvent(
          type: 'REVIEW_QUEUE_PREPARED',
          ts: now,
          payload: {'requestedCount': count, 'queueLength': queue.length},
        ),
      ],
    );
    writeState(state);
    if (queue.isNotEmpty) return queue.take(count).toList(growable: false);
    if (normalized.isEmpty) return const [];
    final start = fallbackStartIdx.clamp(0, normalized.length - 1);
    final fallback = <String>[];
    for (var i = start; i < normalized.length && fallback.length < count; i++) {
      fallback.add(normalized[i].marker!);
    }
    for (var i = 0; i < start && fallback.length < count; i++) {
      fallback.add(normalized[i].marker!);
    }
    return fallback;
  }

  ({List<String> queue, Map<String, DecisionSignal> signalByMarker})
      buildRecoveryQueueForLesson({
    required String lessonLocalId,
    required String topic,
    required List<AuxRoomItem> items,
  }) {
    var state = readState(lessonLocalId);
    final normalized = normalizeItems(items);
    if (state.curriculum == null) {
      state = state.copyWith(
        curriculum: StudentCurriculum(
          topic: topic,
          totalItems: normalized.length,
          generatedAt: DateTime.now().millisecondsSinceEpoch,
          provisional: false,
          items: normalized
              .map((item) => CurriculumItem(marker: item.marker!, text: item.text!))
              .toList(growable: false),
        ),
      );
    }
    final queue = aux_state.buildRecoveryQueue(state);
    final aux = aux_state.ensureAuxRooms(state);
    final signalByMarker = <String, DecisionSignal>{};
    for (final entry in aux_state.pendingMapOf(aux)) {
      if (entry['status'] == 'pending') {
        signalByMarker[(entry['marker'] ?? '').toString()] =
            DecisionSignalValue.fromValue(entry['signal']);
      }
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    writeState(state.copyWith(
      auxRooms: aux,
      events: [
        ...state.events,
        StudentLearningEvent(
          type: 'RECOVERY_QUEUE_PREPARED',
          ts: now,
          payload: {'queueLength': queue.length},
        ),
      ],
    ));
    return (queue: queue, signalByMarker: signalByMarker);
  }

  Future<PreparedAuxRoomQuestion> prepareAuxRoomQuestion({
    required String lessonLocalId,
    required AuxRoomMode mode,
    required AuxRoomProfile profile,
    required List<AuxRoomItem> items,
    required String? marker,
    required DecisionSignal signal,
  }) async {
    final picked =
        marker == null ? null : pickAuxRoomItem(marker, items);
    if (picked == null) {
      return const PreparedAuxRoomQuestion.failed('no item for marker');
    }
    final result = await t02Caller.call(
      lessonLocalId: lessonLocalId,
      mode: mode,
      profile: profile,
      marker: picked.marker!,
      item: picked.text!,
      signal: signal,
      confirmEnabled: true,
    );
    if (result.aborted) {
      return PreparedAuxRoomQuestion.failed(result.reason ?? 'aborted');
    }
    final content = result.conteudo;
    if (content == null ||
        content.options[AnswerLetter.A]?.isEmpty != false ||
        content.options[AnswerLetter.B]?.isEmpty != false ||
        content.options[AnswerLetter.C]?.isEmpty != false) {
      return const PreparedAuxRoomQuestion.failed('invalid aux room material');
    }
    final eventType = mode == AuxRoomMode.review
        ? 'REVIEW_QUESTION_SHOWN'
        : 'RECOVERY_QUESTION_SHOWN';
    final state = readState(lessonLocalId);
    writeState(
      state.copyWith(
        events: [
          ...state.events,
          StudentLearningEvent(
            type: eventType,
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: {'marker': picked.marker, 'signal': signal.value},
          ),
        ],
      ),
    );
    return PreparedAuxRoomQuestion.ok(AuxRoomContent.fromLesson(content));
  }

  void recordAuxRoomAnswer({
    required String lessonLocalId,
    required String marker,
    required LessonLayer layer,
    required List<AuxRoomItem> items,
    required AuxRoomContent conteudo,
    required AnswerLetter letra,
    required DecisionSignal sinal,
    required String source,
  }) {
    var state = readState(lessonLocalId);
    final attempt = LessonAttempt(
      marker: marker,
      layer: layer,
      letra: letra,
      sinal: sinal,
      correct: letra == conteudo.correctAnswer,
      ts: DateTime.now().millisecondsSinceEpoch,
    );
    state = aux_state.mirrorAttemptToAuxRooms(
      state.copyWith(attempts: [...state.attempts, attempt]),
      attempt,
    );
    writeState(state);
  }

  void completeReviewSession(String lessonLocalId) {
    var state = aux_state.advanceReviewCursor(readState(lessonLocalId));
    final review = aux_state.ensureAuxRooms(state)['review'] as Map?;
    state = state.copyWith(
      events: [
        ...state.events,
        StudentLearningEvent(
          type: 'REVIEW_CURSOR_UPDATED',
          ts: DateTime.now().millisecondsSinceEpoch,
          payload: {
            'sequentialCursor': (review?['sequentialCursor'] as num?)?.toInt() ?? 0,
            'currentIndex': (review?['currentIndex'] as num?)?.toInt() ?? 0,
          },
        ),
      ],
    );
    writeState(state);
  }

  void registerRecoveryStarted(String lessonLocalId, List<String> queue) {
    final state = readState(lessonLocalId);
    final now = DateTime.now().millisecondsSinceEpoch;
    writeState(
      state.copyWith(
        events: [
          ...state.events,
          StudentLearningEvent(
            type: 'RECOVERY_REQUIRED',
            ts: now,
            payload: {'pendingCount': queue.length},
          ),
          StudentLearningEvent(
            type: 'RECOVERY_STARTED',
            ts: now,
            payload: {'queue': queue},
          ),
          StudentLearningEvent(
            type: 'FINAL_COMPLETION_BLOCKED_BY_PENDING',
            ts: now,
            payload: {'pendingCount': queue.length},
          ),
        ],
      ),
    );
  }

  bool shouldLessonBlockFinalCompletion(String lessonLocalId) {
    return aux_state.shouldBlockFinalCompletionForRecovery(
      readState(lessonLocalId),
      auxRoomsEnabled: auxRoomsEnabled,
      recoveryRoomEnabled: recoveryRoomEnabled,
    );
  }

  void registerFinalCompletionAllowed(String lessonLocalId) {
    final state = readState(lessonLocalId);
    writeState(
      state.copyWith(
        events: [
          ...state.events,
          StudentLearningEvent(
            type: 'FINAL_COMPLETION_ALLOWED',
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: const {},
          ),
        ],
      ),
    );
  }

  void registerRecoveryCompleted(String lessonLocalId) {
    final state = readState(lessonLocalId);
    writeState(
      state.copyWith(
        events: [
          ...state.events,
          StudentLearningEvent(
            type: 'RECOVERY_COMPLETED',
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: const {},
          ),
        ],
      ),
    );
  }
}
