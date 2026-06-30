// MIRROR OF: src/sim/state/studentLearningState.store.ts (Web, source of truth)
import 'dart:convert';

import 'student_learning_state.dart';

enum StateConflictResolution { local, cloud, equal }

class CanonicalLearningEvent {
  const CanonicalLearningEvent({
    required this.eventId,
    required this.type,
    required this.lessonLocalId,
    required this.payload,
    required this.createdAt,
    required this.source,
    required this.schemaVersion,
    this.userId,
    this.stateVersionBefore,
    this.stateVersionAfter,
  });

  final String eventId;
  final String type;
  final String lessonLocalId;
  final String? userId;
  final JsonMap payload;
  final int createdAt;
  final String source;
  final int schemaVersion;
  final int? stateVersionBefore;
  final int? stateVersionAfter;

  StudentLearningEvent toLegacyEvent() => StudentLearningEvent(
    type: type,
    ts: createdAt,
    payload: {
      ...payload,
      'event_id': eventId,
      'lesson_local_id': lessonLocalId,
      'user_id': userId,
      'source': source,
      'schema_version': schemaVersion,
      'state_version_before': stateVersionBefore,
      'state_version_after': stateVersionAfter,
    },
  );

  JsonMap toJson() => {
    'event_id': eventId,
    'type': type,
    'lesson_local_id': lessonLocalId,
    'user_id': userId,
    'payload': payload,
    'created_at': createdAt,
    'source': source,
    'schema_version': schemaVersion,
    'state_version_before': stateVersionBefore,
    'state_version_after': stateVersionAfter,
  };

  factory CanonicalLearningEvent.fromJson(JsonMap json) {
    return CanonicalLearningEvent(
      eventId: (json['event_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      lessonLocalId: (json['lesson_local_id'] ?? '').toString(),
      userId: json['user_id'] as String?,
      payload: json['payload'] is Map
          ? JsonMap.from(json['payload'] as Map)
          : const {},
      createdAt:
          (json['created_at'] as num?)?.toInt() ??
          (json['ts'] as num?)?.toInt() ??
          0,
      source: (json['source'] ?? 'unknown').toString(),
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      stateVersionBefore: (json['state_version_before'] as num?)?.toInt(),
      stateVersionAfter: (json['state_version_after'] as num?)?.toInt(),
    );
  }
}

abstract interface class StudentStateLocalStorage {
  String? readState(String lessonLocalId);
  void writeState(String lessonLocalId, String encoded);
  String? readEvents(String lessonLocalId);
  void writeEvents(String lessonLocalId, String encoded);
  List<String> listStateIds();
}

class MemoryStudentStateLocalStorage implements StudentStateLocalStorage {
  final Map<String, String> states = {};
  final Map<String, String> events = {};

  @override
  String? readEvents(String lessonLocalId) => events[lessonLocalId];

  @override
  String? readState(String lessonLocalId) => states[lessonLocalId];

  @override
  List<String> listStateIds() => states.keys.toList(growable: false);

  @override
  void writeEvents(String lessonLocalId, String encoded) {
    events[lessonLocalId] = encoded;
  }

  @override
  void writeState(String lessonLocalId, String encoded) {
    states[lessonLocalId] = encoded;
  }
}

abstract interface class StudentStateCloudStorage {
  Future<StudentLearningState?> loadCloud(String lessonLocalId);
  Future<void> persistCloud(StudentLearningState state);
}

class MemoryStudentStateCloudStorage implements StudentStateCloudStorage {
  final Map<String, StudentLearningState> states = {};

  @override
  Future<StudentLearningState?> loadCloud(String lessonLocalId) async {
    return states[lessonLocalId];
  }

  @override
  Future<void> persistCloud(StudentLearningState state) async {
    states[state.lessonLocalId] = state;
  }
}

class StudentStateStore {
  StudentStateStore({
    required this.local,
    this.cloud,
    int Function()? now,
    String Function()? idFactory,
  }) : now = now ?? (() => DateTime.now().millisecondsSinceEpoch),
       idFactory = idFactory ?? _defaultId;

  final StudentStateLocalStorage local;
  final StudentStateCloudStorage? cloud;
  final int Function() now;
  final String Function() idFactory;
  final Map<String, StudentLearningState> _memory = {};
  final Map<String, List<CanonicalLearningEvent>> _eventLog = {};

  StudentLearningState readState(String lessonLocalId) {
    final cached = _memory[lessonLocalId];
    if (cached != null) return cached;
    final encoded = local.readState(lessonLocalId);
    if (encoded != null && encoded.trim().isNotEmpty) {
      dynamic decoded;
      try {
        decoded = jsonDecode(encoded);
      } on FormatException {
        decoded = null;
      }
      if (decoded is Map) {
        final state = StudentLearningState.fromJson(JsonMap.from(decoded));
        _memory[lessonLocalId] = state;
        _eventLog[lessonLocalId] = _readEvents(lessonLocalId);
        return state;
      }
    }
    final state = StudentLearningState.empty(
      lessonLocalId: lessonLocalId,
      now: now(),
    );
    writeState(state);
    return state;
  }

  StudentLearningState writeState(StudentLearningState state) {
    final next = state.copyWith(updatedAt: now());
    _memory[next.lessonLocalId] = next;
    local.writeState(next.lessonLocalId, jsonEncode(next.toJson()));
    return next;
  }

  StudentLearningState patchState(
    String lessonLocalId,
    StudentLearningState Function(StudentLearningState state) patch,
  ) {
    return writeState(patch(readState(lessonLocalId)));
  }

  CanonicalLearningEvent mutateWithEvent({
    required String lessonLocalId,
    required String type,
    required JsonMap payload,
    required String source,
    required StudentLearningState Function(
      StudentLearningState state,
      CanonicalLearningEvent event,
    )
    mutate,
    String? userId,
  }) {
    final before = readState(lessonLocalId);
    final beforeRevision = _foundationRevision(before);
    final event = CanonicalLearningEvent(
      eventId: idFactory(),
      type: type,
      lessonLocalId: lessonLocalId,
      userId: userId ?? before.userId,
      payload: {
        ...payload,
        'foundation_revision_before': beforeRevision,
        'foundation_revision_after': beforeRevision + 1,
      },
      createdAt: now(),
      source: source,
      schemaVersion: studentLearningStateSchemaVersion,
      stateVersionBefore: before.stateVersion,
      stateVersionAfter: before.stateVersion,
    );
    final mutated = mutate(before, event);
    final next = _stampFoundationRevision(
      mutated.copyWith(events: [...mutated.events, event.toLegacyEvent()]),
      event,
      beforeRevision + 1,
    );
    _writeCanonicalEvent(event);
    writeState(next);
    return event;
  }

  CanonicalLearningEvent appendEvent({
    required String lessonLocalId,
    required String type,
    required JsonMap payload,
    required String source,
    String? userId,
  }) {
    return mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: type,
      payload: payload,
      source: source,
      userId: userId,
      mutate: (state, _) => state,
    );
  }

  List<CanonicalLearningEvent> getEventLog(String lessonLocalId) {
    return List.unmodifiable(
      _eventLog[lessonLocalId] ?? _readEvents(lessonLocalId),
    );
  }

  List<StudentLearningState> listLocalStates({bool includeDeleted = false}) {
    final ids = {...local.listStateIds(), ..._memory.keys};
    final states = ids.map(readState).where((state) {
      if (includeDeleted) return true;
      return state.extra['deletedAt'] == null &&
          (state.extra['syncInfo'] is! Map ||
              (state.extra['syncInfo'] as Map)['deletedAt'] == null);
    }).toList();
    states.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return states;
  }

  StudentLearningState renameLesson(String lessonLocalId, String name) {
    final clean = name.trim();
    if (clean.isEmpty) return readState(lessonLocalId);
    return writeState(
      readState(lessonLocalId).copyWith(
        profile: readState(lessonLocalId).profile.copyWith(
          objetivo: clean,
          targetTopic: clean,
          sessionGoal: clean,
        ),
        extra: {...readState(lessonLocalId).extra, 'renamedAt': now()},
      ),
    );
  }

  StudentLearningState tombstoneLesson(String lessonLocalId) {
    final ts = now();
    final state = readState(lessonLocalId);
    return writeState(
      state.copyWith(
        extra: {
          ...state.extra,
          'deletedAt': ts,
          'syncInfo': {
            if (state.extra['syncInfo'] is Map)
              ...JsonMap.from(state.extra['syncInfo'] as Map),
            'deletedAt': ts,
            'operation': 'tombstone',
          },
        },
      ),
    );
  }

  StudentLearningState replayEvents({
    required StudentLearningState seed,
    required Iterable<CanonicalLearningEvent> events,
  }) {
    var state = seed;
    final seen = <String>{};
    var revision = _foundationRevision(seed);
    for (final event in events) {
      if (!seen.add(event.eventId)) continue;
      state = _applyKnownEvent(state, event);
      revision += 1;
      state = _stampFoundationRevision(state, event, revision);
    }
    return state.copyWith(
      events: events.map((event) => event.toLegacyEvent()).toList(),
    );
  }

  Future<StudentLearningState> hydrateFromCloud(String lessonLocalId) async {
    final localState = readState(lessonLocalId);
    final remote = await cloud?.loadCloud(lessonLocalId);
    final resolved = syncState(localState, remote);
    writeState(resolved);
    return resolved;
  }

  Future<void> persistCloud(String lessonLocalId) async {
    final target = cloud;
    if (target == null) return;
    await target.persistCloud(readState(lessonLocalId));
  }

  StudentLearningState syncState(
    StudentLearningState localState,
    StudentLearningState? cloudState,
  ) {
    if (cloudState == null) return localState;
    return switch (resolveConflict(localState, cloudState)) {
      StateConflictResolution.local => localState,
      StateConflictResolution.cloud => cloudState,
      StateConflictResolution.equal => _mergeEqual(localState, cloudState),
    };
  }

  StateConflictResolution resolveConflict(
    StudentLearningState localState,
    StudentLearningState cloudState,
  ) {
    final localScore = highWaterMark(localState);
    final cloudScore = highWaterMark(cloudState);
    if (localScore > cloudScore) return StateConflictResolution.local;
    if (cloudScore > localScore) return StateConflictResolution.cloud;
    if (localState.updatedAt > cloudState.updatedAt) {
      return StateConflictResolution.local;
    }
    if (cloudState.updatedAt > localState.updatedAt) {
      return StateConflictResolution.cloud;
    }
    return StateConflictResolution.equal;
  }

  JsonMap exportBackup(String lessonLocalId) {
    final state = readState(lessonLocalId);
    return {
      'kind': 'sim-student-learning-backup',
      'schema_version': studentLearningStateSchemaVersion,
      'exported_at': now(),
      'state': state.toJson(),
      'events': getEventLog(lessonLocalId).map((e) => e.toJson()).toList(),
    };
  }

  JsonMap parseBackupText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) throw const FormatException('backup vazio');
    const begin = 'SIM_CYBER_V1_BEGIN';
    const end = 'SIM_CYBER_V1_END';
    final beginAt = text.indexOf(begin);
    final endAt = text.indexOf(end);
    if (beginAt >= 0 && endAt > beginAt) {
      final encoded = text
          .substring(beginAt + begin.length, endAt)
          .replaceAll(RegExp(r'\s+'), '');
      final decoded = utf8.decode(base64.decode(encoded));
      final parsed = jsonDecode(decoded);
      if (parsed is Map) return JsonMap.from(parsed);
      throw const FormatException('backup invalido');
    }
    final parsed = text.startsWith('{')
        ? jsonDecode(text)
        : jsonDecode(
            utf8.decode(base64.decode(text.replaceAll(RegExp(r'\s+'), ''))),
          );
    if (parsed is Map) return JsonMap.from(parsed);
    throw const FormatException('backup invalido');
  }

  StudentLearningState importBackup(JsonMap backup) {
    if (backup['magic'] == 'SIM_CYBER_BACKUP_V1') {
      return _importCyberBackup(backup);
    }
    final rawState = backup['state'];
    if (rawState is! Map) {
      throw ArgumentError('Backup sem state valido.');
    }
    final state = StudentLearningState.fromJson(JsonMap.from(rawState));
    final rawEvents = backup['events'];
    final events = rawEvents is List
        ? rawEvents
              .whereType<Map>()
              .map(
                (event) => CanonicalLearningEvent.fromJson(JsonMap.from(event)),
              )
              .toList()
        : <CanonicalLearningEvent>[];
    final dedupedEvents = _dedupeEvents(events);
    _eventLog[state.lessonLocalId] = dedupedEvents;
    local.writeEvents(
      state.lessonLocalId,
      jsonEncode(dedupedEvents.map((e) => e.toJson()).toList()),
    );
    return writeState(state);
  }

  StudentLearningState _importCyberBackup(JsonMap backup) {
    final states = backup['studentLearningStates'] is Map
        ? JsonMap.from(backup['studentLearningStates'] as Map)
        : const <String, dynamic>{};
    final lessons = backup['lessons'] is List
        ? backup['lessons'] as List
        : const [];
    StudentLearningState? lastImported;
    final protectedIds = <String>{
      ...states.keys
          .map((key) => key.toString())
          .where((key) => key.isNotEmpty),
      for (final lesson in lessons.whereType<Map>())
        _lessonIdFromCyberLesson(JsonMap.from(lesson)),
    }..removeWhere((id) => id.trim().isEmpty);

    for (final id in protectedIds) {
      final before = _memory[id] ?? _readStateIfExists(id);
      final rawSnapshot = states[id];
      final snapshot = rawSnapshot is Map
          ? StudentLearningState.fromJson(
              JsonMap.from({...rawSnapshot, 'lessonLocalId': id}),
            )
          : null;
      final lesson = lessons
          .whereType<Map>()
          .map((entry) => JsonMap.from(entry))
          .where((entry) => _lessonIdFromCyberLesson(entry) == id)
          .cast<JsonMap?>()
          .firstWhere((entry) => entry != null, orElse: () => null);
      final lessonState = lesson == null
          ? null
          : _stateFromCyberLesson(lesson, id);
      final imported = _mergeBackupStates(lessonState, snapshot);
      if (imported == null) continue;
      final merged = _mergeBackupStates(before, imported) ?? imported;
      lastImported = writeState(
        merged.copyWith(
          lessonLocalId: id,
          profile: merged.profile.copyWith(
            extra: {...merged.profile.extra, 'lessonLocalId': id},
          ),
        ),
      );
    }
    if (lastImported == null) {
      throw ArgumentError('Backup SimWeb sem aulas validas.');
    }
    return lastImported;
  }

  StudentLearningState? _readStateIfExists(String lessonLocalId) {
    final encoded = local.readState(lessonLocalId);
    if (encoded == null || encoded.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(encoded);
      return decoded is Map
          ? StudentLearningState.fromJson(JsonMap.from(decoded))
          : null;
    } catch (_) {
      return null;
    }
  }

  StudentLearningState? _mergeBackupStates(
    StudentLearningState? existing,
    StudentLearningState? incoming,
  ) {
    if (existing == null) return incoming;
    if (incoming == null) return existing;
    return mergeStudentLearningStateFromCloud(existing, incoming);
  }

  String _lessonIdFromCyberLesson(JsonMap lesson) {
    final direct = (lesson['id'] ?? '').toString().trim();
    if (direct.isNotEmpty) return direct;
    final onboarding = lesson['onboarding'];
    if (onboarding is Map) {
      final fromOnboarding = (onboarding['lessonLocalId'] ?? '')
          .toString()
          .trim();
      if (fromOnboarding.isNotEmpty) return fromOnboarding;
    }
    return '';
  }

  StudentLearningState _stateFromCyberLesson(JsonMap lesson, String id) {
    final onboarding = lesson['onboarding'] is Map
        ? JsonMap.from(lesson['onboarding'] as Map)
        : const <String, dynamic>{};
    final rawItems =
        lesson['curriculo'] ?? lesson['curriculum'] ?? lesson['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((raw) {
                final item = JsonMap.from(raw);
                return CurriculumItem(
                  marker: (item['marker'] ?? item['id'] ?? '').toString(),
                  text:
                      (item['text'] ??
                              item['microitem_for_teacher'] ??
                              item['what_student_must_master'] ??
                              item['title'] ??
                              '')
                          .toString(),
                  title: item['title']?.toString(),
                  microitemForTeacher:
                      (item['microitem_for_teacher'] ??
                              item['what_student_must_master'])
                          ?.toString(),
                  extra: item
                    ..removeWhere(
                      (key, _) => {
                        'marker',
                        'id',
                        'text',
                        'title',
                        'microitem_for_teacher',
                        'what_student_must_master',
                      }.contains(key),
                    ),
                );
              })
              .where((item) => item.marker.isNotEmpty && item.text.isNotEmpty)
              .toList()
        : <CurriculumItem>[];
    final now =
        (lesson['updatedAt'] as num?)?.toInt() ??
        (lesson['createdAt'] as num?)?.toInt() ??
        this.now();
    final topic =
        (onboarding['objetivo'] ??
                onboarding['free_text'] ??
                lesson['title'] ??
                lesson['tema'] ??
                'Aula SIM')
            .toString();
    return StudentLearningState.empty(lessonLocalId: id, now: now).copyWith(
      profile: StudentProfile(
        preferredName: onboarding['preferred_name']?.toString(),
        language: onboarding['language']?.toString(),
        stableLang: (onboarding['stable_lang'] ?? onboarding['stableLang'])
            ?.toString(),
        objetivo: topic,
        nivel: onboarding['nivel']?.toString(),
        academicLevel:
            (onboarding['academic_level'] ?? onboarding['academicLevel'])
                ?.toString(),
        targetTopic: (onboarding['target_topic'] ?? topic).toString(),
        sessionGoal: topic,
        extra: onboarding,
      ),
      curriculum: items.isEmpty
          ? null
          : StudentCurriculum(
              topic: topic,
              totalItems: items.length,
              generatedAt: now,
              provisional: false,
              items: items,
            ),
      progress: items.isEmpty
          ? null
          : LessonProgress(
              itemIdx: 0,
              layer: LessonLayer.l1,
              erros: 0,
              amparoLvl: 0,
              historia: const [],
              mainAdvances: 0,
              concluidos: const [],
              pendentesMarkers: items.map((item) => item.marker).toList(),
              totalItems: items.length,
              pctAvanco: 0,
            ),
      current: items.isEmpty
          ? null
          : LessonCurrent(
              itemIdx: 0,
              marker: items.first.marker,
              layer: LessonLayer.l1,
              amparoLvl: 0,
            ),
    );
  }

  int highWaterMark(StudentLearningState state) {
    final progress = state.progress;
    final current = state.current;
    final itemIdx = progress?.itemIdx ?? current?.itemIdx ?? 0;
    final layer = progress?.layer ?? current?.layer ?? LessonLayer.l1;
    final mainAdvances = progress?.mainAdvances ?? 0;
    return mainAdvances * 100000 +
        itemIdx * 1000 +
        layer.value * 100 +
        state.attempts.length;
  }

  List<CanonicalLearningEvent> _readEvents(String lessonLocalId) {
    final encoded = local.readEvents(lessonLocalId);
    if (encoded == null || encoded.trim().isEmpty) return const [];
    dynamic decoded;
    try {
      decoded = jsonDecode(encoded);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    return _dedupeEvents(
      decoded.whereType<Map>().map(
        (event) => CanonicalLearningEvent.fromJson(JsonMap.from(event)),
      ),
    );
  }

  List<CanonicalLearningEvent> _dedupeEvents(
    Iterable<CanonicalLearningEvent> events,
  ) {
    final byId = <String, CanonicalLearningEvent>{};
    for (final event in events) {
      if (event.eventId.trim().isEmpty) continue;
      byId.putIfAbsent(event.eventId, () => event);
    }
    final sorted = byId.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return sorted;
  }

  void _writeCanonicalEvent(CanonicalLearningEvent event) {
    final lessonLocalId = event.lessonLocalId;
    final events = [
      ...(_eventLog[lessonLocalId] ?? _readEvents(lessonLocalId)),
      event,
    ];
    final dedupedEvents = _dedupeEvents(events);
    _eventLog[lessonLocalId] = dedupedEvents;
    local.writeEvents(
      lessonLocalId,
      jsonEncode(dedupedEvents.map((e) => e.toJson()).toList()),
    );
  }

  int _foundationRevision(StudentLearningState state) {
    final foundation = state.extra['foundation'] is Map
        ? JsonMap.from(state.extra['foundation'] as Map)
        : const <String, dynamic>{};
    return (foundation['revision'] as num?)?.toInt() ?? state.events.length;
  }

  StudentLearningState _stampFoundationRevision(
    StudentLearningState state,
    CanonicalLearningEvent event,
    int revision,
  ) {
    final foundation = state.extra['foundation'] is Map
        ? JsonMap.from(state.extra['foundation'] as Map)
        : <String, dynamic>{};
    return state.copyWith(
      extra: {
        ...state.extra,
        'foundation': {
          ...foundation,
          'revision': revision,
          'last_event_id': event.eventId,
          'last_event_type': event.type,
          'last_event_at': event.createdAt,
        },
      },
    );
  }

  StudentLearningState _applyKnownEvent(
    StudentLearningState state,
    CanonicalLearningEvent event,
  ) {
    if (event.type == 'IDENTITY_BOUND') {
      return state.copyWith(
        userId: event.userId ?? event.payload['user_id']?.toString(),
        extra: {
          ...state.extra,
          'identity': {
            ...event.payload,
            'bound_at': event.createdAt,
            'event_id': event.eventId,
          },
        },
      );
    }
    if (event.type == 'IDENTITY_DETACHED') {
      final identity = state.extra['identity'] is Map
          ? JsonMap.from(state.extra['identity'] as Map)
          : <String, dynamic>{};
      return state.copyWith(
        extra: {
          ...state.extra,
          'identity': {
            ...identity,
            'status': 'detached',
            'detached_at': event.createdAt,
            'detach_reason': event.payload['reason']?.toString(),
            'event_id': event.eventId,
          },
        },
      );
    }
    if (event.type == 'OBJECTIVE_SUBMITTED') {
      final objetivo = event.payload['objetivo']?.toString();
      final language = event.payload['language']?.toString();
      return state.copyWith(
        profile: state.profile.copyWith(
          objetivo: objetivo,
          language: language,
          stableLang: language,
        ),
      );
    }
    if (event.type == 'ANSWER_SUBMITTED') {
      final attempt = event.payload['attempt'];
      if (attempt is Map) {
        return state.copyWith(
          attempts: [
            ...state.attempts,
            LessonAttempt.fromJson(JsonMap.from(attempt)),
          ],
        );
      }
    }
    if (event.type == 'MASTERY_EVALUATED') {
      final marker = event.payload['marker_id']?.toString();
      final status = event.payload['status']?.toString();
      if (marker == null || marker.isEmpty || status == null) return state;
      final truth = JsonMap.from(
        state.extra['truth'] is Map ? state.extra['truth'] as Map : const {},
      );
      final consolidation = JsonMap.from(
        truth['item_consolidation_status'] is Map
            ? truth['item_consolidation_status'] as Map
            : const {},
      );
      consolidation[marker] = status;
      return state.copyWith(
        extra: {
          ...state.extra,
          'truth': {...truth, 'item_consolidation_status': consolidation},
        },
      );
    }
    if (event.type == 'SYNC_STARTED' ||
        event.type == 'SYNC_COMPLETED' ||
        event.type == 'SYNC_FAILED') {
      final sync = state.extra['sync'] is Map
          ? JsonMap.from(state.extra['sync'] as Map)
          : <String, dynamic>{};
      final status =
          event.payload['status']?.toString() ??
          switch (event.type) {
            'SYNC_STARTED' => 'pending',
            'SYNC_COMPLETED' => 'synced',
            _ => 'failed',
          };
      return state.copyWith(
        extra: {
          ...state.extra,
          'sync': {
            ...sync,
            'status': status,
            'updated_at': event.createdAt,
            'event_id': event.eventId,
            if (event.payload['direction'] != null)
              'direction': event.payload['direction'],
            if (event.payload['error'] != null) 'error': event.payload['error'],
          },
        },
      );
    }
    return state;
  }

  StudentLearningState _mergeEqual(
    StudentLearningState localState,
    StudentLearningState cloudState,
  ) {
    final attempts = <String, LessonAttempt>{};
    for (final attempt in [...cloudState.attempts, ...localState.attempts]) {
      attempts[_attemptKey(attempt)] = attempt;
    }
    final events = <String, StudentLearningEvent>{};
    for (final event in [...cloudState.events, ...localState.events]) {
      final id = event.payload['event_id']?.toString();
      events[id?.isNotEmpty == true ? id! : '${event.type}:${event.ts}'] =
          event;
    }
    return localState.copyWith(
      attempts: attempts.values.toList()..sort((a, b) => a.ts.compareTo(b.ts)),
      events: events.values.toList()..sort((a, b) => a.ts.compareTo(b.ts)),
      updatedAt: localState.updatedAt > cloudState.updatedAt
          ? localState.updatedAt
          : cloudState.updatedAt,
    );
  }

  String _attemptKey(LessonAttempt attempt) {
    return [
      attempt.marker,
      attempt.layer.value,
      attempt.letra.name,
      attempt.sinal.value,
      attempt.correct,
      attempt.ts,
    ].join('|');
  }

  static String _defaultId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    return 'evt-$now';
  }
}
