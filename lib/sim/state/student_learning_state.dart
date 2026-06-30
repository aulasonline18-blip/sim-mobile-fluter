typedef JsonMap = Map<String, dynamic>;

const int studentLearningStateSchemaVersion = 1;
const String studentLearningStateKey = 'sim-student-learning-state-v1';

enum AnswerLetter { A, B, C }

enum DecisionSignal { one, two, three }

extension DecisionSignalValue on DecisionSignal {
  int get value => switch (this) {
    DecisionSignal.one => 1,
    DecisionSignal.two => 2,
    DecisionSignal.three => 3,
  };

  static DecisionSignal fromValue(Object? value) {
    return switch (value) {
      2 => DecisionSignal.two,
      3 => DecisionSignal.three,
      _ => DecisionSignal.one,
    };
  }
}

enum LessonLayer { l1, l2, l3 }

extension LessonLayerValue on LessonLayer {
  int get value => switch (this) {
    LessonLayer.l1 => 1,
    LessonLayer.l2 => 2,
    LessonLayer.l3 => 3,
  };

  static LessonLayer fromValue(Object? value) {
    return switch (value) {
      2 => LessonLayer.l2,
      3 => LessonLayer.l3,
      _ => LessonLayer.l1,
    };
  }
}

enum CurriculumStatusValue {
  empty,
  initialLoading,
  initialReady,
  streaming,
  partialReady,
  expanding,
  expanded,
  failed,
}

enum LiveEntryStatus {
  idle,
  pedidoRecebido,
  t00Running,
  firstItemReady,
  t02FirstLessonRunning,
  firstLessonReady,
  showingFirstLesson,
  failedT00,
  failedT02,
  blockedCredits,
}

class StudentProfile {
  const StudentProfile({
    this.preferredName,
    this.language,
    this.stableLang,
    this.objetivo,
    this.nivel,
    this.academicLevel,
    this.targetTopic,
    this.sessionGoal,
    this.extra = const {},
  });

  final String? preferredName;
  final String? language;
  final String? stableLang;
  final String? objetivo;
  final String? nivel;
  final String? academicLevel;
  final String? targetTopic;
  final String? sessionGoal;
  final JsonMap extra;

  JsonMap toJson() => {
    ...extra,
    if (preferredName != null) 'preferredName': preferredName,
    if (language != null) 'language': language,
    if (stableLang != null) 'stableLang': stableLang,
    if (objetivo != null) 'objetivo': objetivo,
    if (nivel != null) 'nivel': nivel,
    if (academicLevel != null) 'academicLevel': academicLevel,
    if (targetTopic != null) 'targetTopic': targetTopic,
    if (sessionGoal != null) 'sessionGoal': sessionGoal,
  };

  factory StudentProfile.fromJson(JsonMap json) {
    final extra = JsonMap.of(json)
      ..removeWhere(
        (key, _) => {
          'preferredName',
          'language',
          'stableLang',
          'objetivo',
          'nivel',
          'academicLevel',
          'targetTopic',
          'sessionGoal',
        }.contains(key),
      );
    return StudentProfile(
      preferredName: json['preferredName'] as String?,
      language: json['language'] as String?,
      stableLang: json['stableLang'] as String?,
      objetivo: json['objetivo'] as String?,
      nivel: json['nivel'] as String?,
      academicLevel: json['academicLevel'] as String?,
      targetTopic: json['targetTopic'] as String?,
      sessionGoal: json['sessionGoal'] as String?,
      extra: extra,
    );
  }

  StudentProfile copyWith({
    String? preferredName,
    String? language,
    String? stableLang,
    String? objetivo,
    String? nivel,
    String? academicLevel,
    String? targetTopic,
    String? sessionGoal,
    JsonMap? extra,
  }) {
    return StudentProfile(
      preferredName: preferredName ?? this.preferredName,
      language: language ?? this.language,
      stableLang: stableLang ?? this.stableLang,
      objetivo: objetivo ?? this.objetivo,
      nivel: nivel ?? this.nivel,
      academicLevel: academicLevel ?? this.academicLevel,
      targetTopic: targetTopic ?? this.targetTopic,
      sessionGoal: sessionGoal ?? this.sessionGoal,
      extra: extra ?? this.extra,
    );
  }
}

class CurriculumItem {
  const CurriculumItem({
    required this.marker,
    required this.text,
    this.title,
    this.microitemForTeacher,
    this.extra = const {},
  });

  final String marker;
  final String text;
  final String? title;
  final String? microitemForTeacher;
  final JsonMap extra;

  String get teacherText => microitemForTeacher ?? text;

  JsonMap toJson() => {
    ...extra,
    'marker': marker,
    'text': text,
    if (title != null) 'title': title,
    if (microitemForTeacher != null)
      'microitem_for_teacher': microitemForTeacher,
  };

  factory CurriculumItem.fromJson(JsonMap json) => CurriculumItem(
    marker: (json['marker'] ?? '').toString(),
    text: (json['text'] ?? json['title'] ?? '').toString(),
    title: json['title'] as String?,
    microitemForTeacher: json['microitem_for_teacher'] as String?,
    extra: JsonMap.of(json)
      ..removeWhere(
        (key, _) =>
            {'marker', 'text', 'title', 'microitem_for_teacher'}.contains(key),
      ),
  );
}

class StudentCurriculum {
  const StudentCurriculum({
    required this.topic,
    required this.totalItems,
    required this.generatedAt,
    required this.provisional,
    required this.items,
  });

  final String topic;
  final int totalItems;
  final int? generatedAt;
  final bool provisional;
  final List<CurriculumItem> items;

  JsonMap toJson() => {
    'topic': topic,
    'totalItems': totalItems,
    'generatedAt': generatedAt,
    'provisional': provisional,
    'items': items.map((item) => item.toJson()).toList(),
  };

  factory StudentCurriculum.fromJson(JsonMap json) {
    final items = (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => CurriculumItem.fromJson(JsonMap.from(item)))
        .toList();
    return StudentCurriculum(
      topic: (json['topic'] ?? '').toString(),
      totalItems: (json['totalItems'] as num?)?.toInt() ?? items.length,
      generatedAt: (json['generatedAt'] as num?)?.toInt(),
      provisional: json['provisional'] == true,
      items: items,
    );
  }
}

class StudentCurriculumStatus {
  const StudentCurriculumStatus({
    required this.status,
    required this.expansionStatus,
    required this.updatedAt,
    required this.objectiveKey,
    required this.initialCount,
    required this.totalCount,
    this.error,
  });

  final CurriculumStatusValue status;
  final CurriculumStatusValue expansionStatus;
  final String updatedAt;
  final String objectiveKey;
  final int initialCount;
  final int totalCount;
  final String? error;

  JsonMap toJson() => {
    'status': status.name,
    'expansionStatus': expansionStatus.name,
    'updatedAt': updatedAt,
    'objectiveKey': objectiveKey,
    'initialCount': initialCount,
    'totalCount': totalCount,
    if (error != null) 'error': error,
  };

  factory StudentCurriculumStatus.fromJson(JsonMap json) {
    return StudentCurriculumStatus(
      status: _curriculumStatusFromJson(json['status']),
      expansionStatus: _curriculumStatusFromJson(json['expansionStatus']),
      updatedAt: (json['updatedAt'] ?? '').toString(),
      objectiveKey: (json['objectiveKey'] ?? '').toString(),
      initialCount: (json['initialCount'] as num?)?.toInt() ?? 0,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      error: json['error'] as String?,
    );
  }
}

CurriculumStatusValue _curriculumStatusFromJson(Object? value) {
  final raw = value?.toString() ?? '';
  return CurriculumStatusValue.values.firstWhere(
    (status) => status.name == raw,
    orElse: () => switch (raw) {
      'initial_loading' => CurriculumStatusValue.initialLoading,
      'initial_ready' => CurriculumStatusValue.initialReady,
      'partial_ready' => CurriculumStatusValue.partialReady,
      _ => CurriculumStatusValue.empty,
    },
  );
}

class LessonCurrent {
  const LessonCurrent({
    required this.itemIdx,
    required this.marker,
    required this.layer,
    required this.amparoLvl,
  });

  final int itemIdx;
  final String? marker;
  final LessonLayer layer;
  final int amparoLvl;

  JsonMap toJson() => {
    'itemIdx': itemIdx,
    'marker': marker,
    'layer': layer.value,
    'amparoLvl': amparoLvl,
  };

  factory LessonCurrent.fromJson(JsonMap json) => LessonCurrent(
    itemIdx: (json['itemIdx'] as num?)?.toInt() ?? 0,
    marker: json['marker'] as String?,
    layer: LessonLayerValue.fromValue(json['layer']),
    amparoLvl: (json['amparoLvl'] as num?)?.toInt() ?? 0,
  );
}

class LessonProgress {
  const LessonProgress({
    required this.itemIdx,
    required this.layer,
    required this.erros,
    required this.amparoLvl,
    required this.historia,
    required this.mainAdvances,
    required this.concluidos,
    required this.pendentesMarkers,
    required this.totalItems,
    required this.pctAvanco,
  });

  final int itemIdx;
  final LessonLayer layer;
  final int erros;
  final int amparoLvl;
  final List<String> historia;
  final int mainAdvances;
  final List<String> concluidos;
  final List<String> pendentesMarkers;
  final int totalItems;
  final int pctAvanco;

  LessonProgress copyWith({
    int? itemIdx,
    LessonLayer? layer,
    int? erros,
    int? amparoLvl,
    List<String>? historia,
    int? mainAdvances,
    List<String>? concluidos,
    List<String>? pendentesMarkers,
    int? totalItems,
    int? pctAvanco,
  }) {
    return LessonProgress(
      itemIdx: itemIdx ?? this.itemIdx,
      layer: layer ?? this.layer,
      erros: erros ?? this.erros,
      amparoLvl: amparoLvl ?? this.amparoLvl,
      historia: historia ?? this.historia,
      mainAdvances: mainAdvances ?? this.mainAdvances,
      concluidos: concluidos ?? this.concluidos,
      pendentesMarkers: pendentesMarkers ?? this.pendentesMarkers,
      totalItems: totalItems ?? this.totalItems,
      pctAvanco: pctAvanco ?? this.pctAvanco,
    );
  }

  JsonMap toJson() => {
    'itemIdx': itemIdx,
    'layer': layer.value,
    'erros': erros,
    'amparoLvl': amparoLvl,
    'historia': historia,
    'mainAdvances': mainAdvances,
    'concluidos': concluidos,
    'pendentesMarkers': pendentesMarkers,
    'totalItems': totalItems,
    'pctAvanco': pctAvanco,
  };

  factory LessonProgress.fromJson(JsonMap json) => LessonProgress(
    itemIdx: (json['itemIdx'] as num?)?.toInt() ?? 0,
    layer: LessonLayerValue.fromValue(json['layer']),
    erros: (json['erros'] as num?)?.toInt() ?? 0,
    amparoLvl: (json['amparoLvl'] as num?)?.toInt() ?? 0,
    historia: (json['historia'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(),
    mainAdvances: (json['mainAdvances'] as num?)?.toInt() ?? 0,
    concluidos: (json['concluidos'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(),
    pendentesMarkers: (json['pendentesMarkers'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(),
    totalItems: (json['totalItems'] as num?)?.toInt() ?? 0,
    pctAvanco: (json['pctAvanco'] as num?)?.toInt() ?? 0,
  );
}

class LessonAttempt {
  const LessonAttempt({
    required this.marker,
    required this.layer,
    required this.letra,
    required this.sinal,
    required this.correct,
    required this.ts,
  });

  final String marker;
  final LessonLayer layer;
  final AnswerLetter letra;
  final DecisionSignal sinal;
  final bool correct;
  final int ts;

  JsonMap toJson() => {
    'marker': marker,
    'layer': layer.value,
    'letra': letra.name,
    'sinal': sinal.value,
    'correct': correct,
    'ts': ts,
  };

  factory LessonAttempt.fromJson(JsonMap json) => LessonAttempt(
    marker: (json['marker'] ?? '').toString(),
    layer: LessonLayerValue.fromValue(json['layer']),
    letra: AnswerLetter.values.firstWhere(
      (letter) => letter.name == json['letra'],
      orElse: () => AnswerLetter.A,
    ),
    sinal: DecisionSignalValue.fromValue(json['sinal']),
    correct: json['correct'] == true,
    ts: (json['ts'] as num?)?.toInt() ?? 0,
  );
}

class LiveEntry {
  const LiveEntry({
    required this.status,
    required this.error,
    required this.firstItemMarker,
    required this.firstLessonMaterialKey,
    required this.firstLessonStartedAt,
    required this.firstLessonReadyAt,
    required this.updatedAt,
  });

  final LiveEntryStatus status;
  final String? error;
  final String? firstItemMarker;
  final String? firstLessonMaterialKey;
  final int? firstLessonStartedAt;
  final int? firstLessonReadyAt;
  final int updatedAt;

  factory LiveEntry.empty([int now = 0]) => LiveEntry(
    status: LiveEntryStatus.idle,
    error: null,
    firstItemMarker: null,
    firstLessonMaterialKey: null,
    firstLessonStartedAt: null,
    firstLessonReadyAt: null,
    updatedAt: now,
  );

  LiveEntry copyWith({
    LiveEntryStatus? status,
    String? error,
    String? firstItemMarker,
    String? firstLessonMaterialKey,
    int? firstLessonStartedAt,
    int? firstLessonReadyAt,
    int? updatedAt,
  }) {
    return LiveEntry(
      status: status ?? this.status,
      error: error ?? this.error,
      firstItemMarker: firstItemMarker ?? this.firstItemMarker,
      firstLessonMaterialKey:
          firstLessonMaterialKey ?? this.firstLessonMaterialKey,
      firstLessonStartedAt: firstLessonStartedAt ?? this.firstLessonStartedAt,
      firstLessonReadyAt: firstLessonReadyAt ?? this.firstLessonReadyAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  JsonMap toJson() => {
    'status': status.name,
    'error': error,
    'first_item_marker': firstItemMarker,
    'first_lesson_material_key': firstLessonMaterialKey,
    'first_lesson_started_at': firstLessonStartedAt,
    'first_lesson_ready_at': firstLessonReadyAt,
    'updated_at': updatedAt,
  };

  factory LiveEntry.fromJson(JsonMap json) => LiveEntry(
    status: LiveEntryStatus.values.firstWhere(
      (status) => status.name == json['status'],
      orElse: () => LiveEntryStatus.idle,
    ),
    error: json['error'] as String?,
    firstItemMarker: json['first_item_marker'] as String?,
    firstLessonMaterialKey: json['first_lesson_material_key'] as String?,
    firstLessonStartedAt: (json['first_lesson_started_at'] as num?)?.toInt(),
    firstLessonReadyAt: (json['first_lesson_ready_at'] as num?)?.toInt(),
    updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
  );
}

class StudentLearningEvent {
  const StudentLearningEvent({
    required this.type,
    required this.ts,
    required this.payload,
  });

  final String type;
  final int ts;
  final JsonMap payload;

  JsonMap toJson() => {'type': type, 'ts': ts, 'payload': payload};
}

class StudentMasteryTruth {
  const StudentMasteryTruth({
    this.masteryEvidence = const [],
    this.falseMasteryFlags = const [],
    this.needsRetestFlags = const [],
    this.itemConsolidationStatus = const {},
  });

  final List<JsonMap> masteryEvidence;
  final List<String> falseMasteryFlags;
  final List<String> needsRetestFlags;
  final Map<String, String> itemConsolidationStatus;

  const StudentMasteryTruth.empty() : this();

  JsonMap toJson() => {
    'mastery_evidence': masteryEvidence,
    'false_mastery_flags': falseMasteryFlags,
    'needs_retest_flags': needsRetestFlags,
    'item_consolidation_status': itemConsolidationStatus,
  };

  factory StudentMasteryTruth.fromJson(JsonMap json) {
    return StudentMasteryTruth(
      masteryEvidence: (json['mastery_evidence'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => JsonMap.from(entry))
          .toList(),
      falseMasteryFlags: _stringList(json['false_mastery_flags']),
      needsRetestFlags: _stringList(json['needs_retest_flags']),
      itemConsolidationStatus:
          (json['item_consolidation_status'] as Map? ?? const {}).map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
    );
  }

  factory StudentMasteryTruth.fromLegacy(Object? legacy) {
    if (legacy is Map) {
      return StudentMasteryTruth.fromJson(JsonMap.from(legacy));
    }
    return const StudentMasteryTruth.empty();
  }

  StudentMasteryTruth copyWith({
    List<JsonMap>? masteryEvidence,
    List<String>? falseMasteryFlags,
    List<String>? needsRetestFlags,
    Map<String, String>? itemConsolidationStatus,
  }) {
    return StudentMasteryTruth(
      masteryEvidence: masteryEvidence ?? this.masteryEvidence,
      falseMasteryFlags: falseMasteryFlags ?? this.falseMasteryFlags,
      needsRetestFlags: needsRetestFlags ?? this.needsRetestFlags,
      itemConsolidationStatus:
          itemConsolidationStatus ?? this.itemConsolidationStatus,
    );
  }

  static List<String> _stringList(Object? value) {
    return (value is List ? value : const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
  }
}

class StudentAudioState {
  const StudentAudioState({
    required this.status,
    required this.enabled,
    required this.playing,
    required this.updatedAt,
    this.lessonKey,
    this.language,
    this.voice,
    this.cacheKey,
    this.audioUrlHead,
    this.error,
  });

  final String status;
  final bool enabled;
  final bool playing;
  final int updatedAt;
  final String? lessonKey;
  final String? language;
  final String? voice;
  final String? cacheKey;
  final String? audioUrlHead;
  final String? error;

  factory StudentAudioState.empty([int now = 0]) => StudentAudioState(
    status: 'idle',
    enabled: true,
    playing: false,
    updatedAt: now,
  );

  JsonMap toJson() => {
    'status': status,
    'enabled': enabled,
    'playing': playing,
    'updated_at': updatedAt,
    if (lessonKey != null) 'lesson_key': lessonKey,
    if (language != null) 'language': language,
    if (voice != null) 'voice': voice,
    if (cacheKey != null) 'cache_key': cacheKey,
    if (audioUrlHead != null) 'audio_url_head': audioUrlHead,
    if (error != null) 'error': error,
  };

  factory StudentAudioState.fromJson(JsonMap json) => StudentAudioState(
    status: (json['status'] ?? 'idle').toString(),
    enabled: json['enabled'] != false,
    playing: json['playing'] == true,
    updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
    lessonKey: json['lesson_key'] as String?,
    language: json['language'] as String?,
    voice: json['voice'] as String?,
    cacheKey: json['cache_key'] as String?,
    audioUrlHead: json['audio_url_head'] as String?,
    error: json['error'] as String?,
  );

  StudentAudioState copyWith({
    String? status,
    bool? enabled,
    bool? playing,
    int? updatedAt,
    String? lessonKey,
    String? language,
    String? voice,
    String? cacheKey,
    String? audioUrlHead,
    String? error,
  }) {
    return StudentAudioState(
      status: status ?? this.status,
      enabled: enabled ?? this.enabled,
      playing: playing ?? this.playing,
      updatedAt: updatedAt ?? this.updatedAt,
      lessonKey: lessonKey ?? this.lessonKey,
      language: language ?? this.language,
      voice: voice ?? this.voice,
      cacheKey: cacheKey ?? this.cacheKey,
      audioUrlHead: audioUrlHead ?? this.audioUrlHead,
      error: error ?? this.error,
    );
  }
}

class StudentSyncStatus {
  const StudentSyncStatus({
    required this.status,
    required this.pendingJobs,
    required this.highWaterMark,
    required this.updatedAt,
    this.lastSyncedAt,
    this.lastError,
  });

  final String status;
  final int pendingJobs;
  final int highWaterMark;
  final int updatedAt;
  final int? lastSyncedAt;
  final String? lastError;

  factory StudentSyncStatus.empty([int now = 0]) => StudentSyncStatus(
    status: 'idle',
    pendingJobs: 0,
    highWaterMark: 0,
    updatedAt: now,
  );

  JsonMap toJson() => {
    'status': status,
    'pending_jobs': pendingJobs,
    'high_water_mark': highWaterMark,
    'updated_at': updatedAt,
    if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
    if (lastError != null) 'last_error': lastError,
  };

  factory StudentSyncStatus.fromJson(JsonMap json) => StudentSyncStatus(
    status: (json['status'] ?? 'idle').toString(),
    pendingJobs: (json['pending_jobs'] as num?)?.toInt() ?? 0,
    highWaterMark: (json['high_water_mark'] as num?)?.toInt() ?? 0,
    updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
    lastSyncedAt: (json['last_synced_at'] as num?)?.toInt(),
    lastError: json['last_error'] as String?,
  );

  StudentSyncStatus copyWith({
    String? status,
    int? pendingJobs,
    int? highWaterMark,
    int? updatedAt,
    int? lastSyncedAt,
    String? lastError,
  }) {
    return StudentSyncStatus(
      status: status ?? this.status,
      pendingJobs: pendingJobs ?? this.pendingJobs,
      highWaterMark: highWaterMark ?? this.highWaterMark,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: lastError ?? this.lastError,
    );
  }
}

class StudentLearningState {
  const StudentLearningState({
    required this.stateVersion,
    required this.lessonLocalId,
    required this.lessonCloudId,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
    required this.profile,
    required this.curriculum,
    this.curriculumStatus,
    required this.current,
    required this.progress,
    required this.attempts,
    required this.events,
    required this.entry,
    this.placement,
    this.auxRooms,
    this.currentLessonMaterial,
    this.readyLessonMaterials = const {},
    this.queuedActions = const [],
    this.inflightJobs = const [],
    this.truth = const StudentMasteryTruth.empty(),
    this.audio = const StudentAudioState(
      status: 'idle',
      enabled: true,
      playing: false,
      updatedAt: 0,
    ),
    this.syncStatus,
    this.extra = const {},
  });

  final int stateVersion;
  final String lessonLocalId;
  final String? lessonCloudId;
  final String? userId;
  final int createdAt;
  final int updatedAt;
  final StudentProfile profile;
  final StudentCurriculum? curriculum;
  final StudentCurriculumStatus? curriculumStatus;
  final LessonCurrent? current;
  final LessonProgress? progress;
  final List<LessonAttempt> attempts;
  final List<StudentLearningEvent> events;
  final LiveEntry? entry;
  final JsonMap? placement;
  final JsonMap? auxRooms;
  final JsonMap? currentLessonMaterial;
  final Map<String, JsonMap> readyLessonMaterials;
  final List<JsonMap> queuedActions;
  final List<JsonMap> inflightJobs;
  final StudentMasteryTruth truth;
  final StudentAudioState audio;
  final StudentSyncStatus? syncStatus;
  final JsonMap extra;

  bool get hasCurriculum => curriculum?.items.isNotEmpty == true;

  StudentLearningState copyWith({
    int? stateVersion,
    String? lessonLocalId,
    String? lessonCloudId,
    String? userId,
    int? createdAt,
    int? updatedAt,
    StudentProfile? profile,
    StudentCurriculum? curriculum,
    StudentCurriculumStatus? curriculumStatus,
    LessonCurrent? current,
    LessonProgress? progress,
    List<LessonAttempt>? attempts,
    List<StudentLearningEvent>? events,
    LiveEntry? entry,
    JsonMap? placement,
    JsonMap? auxRooms,
    JsonMap? currentLessonMaterial,
    Map<String, JsonMap>? readyLessonMaterials,
    List<JsonMap>? queuedActions,
    List<JsonMap>? inflightJobs,
    StudentMasteryTruth? truth,
    StudentAudioState? audio,
    StudentSyncStatus? syncStatus,
    JsonMap? extra,
  }) {
    return StudentLearningState(
      stateVersion: stateVersion ?? this.stateVersion,
      lessonLocalId: lessonLocalId ?? this.lessonLocalId,
      lessonCloudId: lessonCloudId ?? this.lessonCloudId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      profile: profile ?? this.profile,
      curriculum: curriculum ?? this.curriculum,
      curriculumStatus: curriculumStatus ?? this.curriculumStatus,
      current: current ?? this.current,
      progress: progress ?? this.progress,
      attempts: attempts ?? this.attempts,
      events: events ?? this.events,
      entry: entry ?? this.entry,
      placement: placement ?? this.placement,
      auxRooms: auxRooms ?? this.auxRooms,
      currentLessonMaterial:
          currentLessonMaterial ?? this.currentLessonMaterial,
      readyLessonMaterials: readyLessonMaterials ?? this.readyLessonMaterials,
      queuedActions: queuedActions ?? this.queuedActions,
      inflightJobs: inflightJobs ?? this.inflightJobs,
      truth: truth ?? this.truth,
      audio: audio ?? this.audio,
      syncStatus: syncStatus ?? this.syncStatus,
      extra: extra ?? this.extra,
    );
  }

  factory StudentLearningState.empty({
    required String lessonLocalId,
    String? userId,
    int? now,
  }) {
    final ts = now ?? DateTime.now().millisecondsSinceEpoch;
    return StudentLearningState(
      stateVersion: studentLearningStateSchemaVersion,
      lessonLocalId: lessonLocalId,
      lessonCloudId: null,
      userId: userId,
      createdAt: ts,
      updatedAt: ts,
      profile: const StudentProfile(),
      curriculum: null,
      curriculumStatus: null,
      current: null,
      progress: null,
      attempts: const [],
      events: const [],
      entry: LiveEntry.empty(ts),
      placement: null,
      auxRooms: null,
      truth: const StudentMasteryTruth.empty(),
      audio: StudentAudioState.empty(ts),
      syncStatus: StudentSyncStatus.empty(ts),
    );
  }

  JsonMap toJson() => {
    ...extra,
    'stateVersion': stateVersion,
    'lessonLocalId': lessonLocalId,
    'lessonCloudId': lessonCloudId,
    'userId': userId,
    'createdAt': createdAt,
    'updatedAt': updatedAt,
    'profile': profile.toJson(),
    'curriculum': curriculum?.toJson(),
    'curriculumStatus': curriculumStatus?.toJson(),
    'current': current?.toJson(),
    'progress': progress?.toJson(),
    'attempts': attempts.map((attempt) => attempt.toJson()).toList(),
    'events': events.map((event) => event.toJson()).toList(),
    'entry': entry?.toJson(),
    'placement': placement,
    'auxRooms': auxRooms,
    'currentLessonMaterial': currentLessonMaterial,
    'readyLessonMaterials': readyLessonMaterials,
    'queuedActions': queuedActions,
    'inflightJobs': inflightJobs,
    'truth_typed': truth.toJson(),
    'audio_typed': audio.toJson(),
    'sync_status_typed': syncStatus?.toJson(),
  };

  factory StudentLearningState.fromJson(JsonMap json) {
    final extra = JsonMap.of(json)
      ..removeWhere(
        (key, _) => {
          'stateVersion',
          'lessonLocalId',
          'lessonCloudId',
          'userId',
          'createdAt',
          'updatedAt',
          'profile',
          'curriculum',
          'curriculumStatus',
          'current',
          'progress',
          'attempts',
          'events',
          'entry',
          'placement',
          'auxRooms',
          'currentLessonMaterial',
          'readyLessonMaterials',
          'queuedActions',
          'inflightJobs',
          'truth_typed',
          'audio_typed',
          'sync_status_typed',
        }.contains(key),
      );
    final ready =
        ((json['readyLessonMaterials'] ?? json['ready_lesson_materials'])
                    as Map? ??
                const {})
            .map(
              (key, value) =>
                  MapEntry(key.toString(), JsonMap.from(value as Map)),
            );
    return StudentLearningState(
      stateVersion:
          (json['stateVersion'] as num?)?.toInt() ??
          studentLearningStateSchemaVersion,
      lessonLocalId: (json['lessonLocalId'] ?? '').toString(),
      lessonCloudId: json['lessonCloudId'] as String?,
      userId: json['userId'] as String?,
      createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      profile: json['profile'] is Map
          ? StudentProfile.fromJson(JsonMap.from(json['profile'] as Map))
          : const StudentProfile(),
      curriculum: json['curriculum'] is Map
          ? StudentCurriculum.fromJson(JsonMap.from(json['curriculum'] as Map))
          : null,
      curriculumStatus: json['curriculumStatus'] is Map
          ? StudentCurriculumStatus.fromJson(
              JsonMap.from(json['curriculumStatus'] as Map),
            )
          : null,
      current: json['current'] is Map
          ? LessonCurrent.fromJson(JsonMap.from(json['current'] as Map))
          : null,
      progress: json['progress'] is Map
          ? LessonProgress.fromJson(JsonMap.from(json['progress'] as Map))
          : null,
      attempts: (json['attempts'] as List? ?? const [])
          .whereType<Map>()
          .map((attempt) => LessonAttempt.fromJson(JsonMap.from(attempt)))
          .toList(),
      events: (json['events'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (event) => StudentLearningEvent(
              type: (event['type'] ?? '').toString(),
              ts: (event['ts'] as num?)?.toInt() ?? 0,
              payload: event['payload'] is Map
                  ? JsonMap.from(event['payload'] as Map)
                  : const {},
            ),
          )
          .toList(),
      entry: json['entry'] is Map
          ? LiveEntry.fromJson(JsonMap.from(json['entry'] as Map))
          : null,
      placement: json['placement'] is Map
          ? JsonMap.from(json['placement'] as Map)
          : null,
      auxRooms: json['auxRooms'] is Map
          ? JsonMap.from(json['auxRooms'] as Map)
          : null,
      currentLessonMaterial:
          (json['currentLessonMaterial'] ?? json['current_lesson_material'])
              is Map
          ? JsonMap.from(
              (json['currentLessonMaterial'] ?? json['current_lesson_material'])
                  as Map,
            )
          : null,
      readyLessonMaterials: ready,
      queuedActions:
          ((json['queuedActions'] ?? json['queued_actions']) as List? ??
                  const [])
              .whereType<Map>()
              .map((entry) => JsonMap.from(entry))
              .toList(),
      inflightJobs:
          ((json['inflightJobs'] ?? json['inflight_jobs']) as List? ?? const [])
              .whereType<Map>()
              .map((entry) => JsonMap.from(entry))
              .toList(),
      truth: json['truth_typed'] is Map
          ? StudentMasteryTruth.fromJson(
              JsonMap.from(json['truth_typed'] as Map),
            )
          : StudentMasteryTruth.fromLegacy(json['truth']),
      audio: json['audio_typed'] is Map
          ? StudentAudioState.fromJson(JsonMap.from(json['audio_typed'] as Map))
          : StudentAudioState.empty((json['updatedAt'] as num?)?.toInt() ?? 0),
      syncStatus: json['sync_status_typed'] is Map
          ? StudentSyncStatus.fromJson(
              JsonMap.from(json['sync_status_typed'] as Map),
            )
          : null,
      extra: extra,
    );
  }
}

// ---------------------------------------------------------------------------
// F1.2 — merge profundo local vs cloud
// ---------------------------------------------------------------------------

String _attemptMergeKey(LessonAttempt a) =>
    '${a.marker}|${a.layer.value}|${a.letra.name}|${a.sinal.value}|${a.correct}|${a.ts}';

List<LessonAttempt> mergeAttempts(
  List<LessonAttempt> existing,
  List<LessonAttempt> incoming,
) {
  final byKey = <String, LessonAttempt>{};
  for (final attempt in [...existing, ...incoming]) {
    byKey.putIfAbsent(_attemptMergeKey(attempt), () => attempt);
  }
  return byKey.values.toList()..sort((a, b) => a.ts.compareTo(b.ts));
}

List<StudentLearningEvent> mergeEvents(
  List<StudentLearningEvent> a,
  List<StudentLearningEvent> b,
) {
  final byKey = <String, StudentLearningEvent>{};
  for (final event in [...a, ...b]) {
    final key = '${event.type}:${event.ts}';
    byKey.putIfAbsent(key, () => event);
  }
  return byKey.values.toList()..sort((x, y) => x.ts.compareTo(y.ts));
}

List<String> mergeConcluidos(List<String> a, List<String> b) {
  final seen = <String>{};
  return [...a, ...b].where(seen.add).toList();
}

int _progressRank(LessonProgress? p) {
  if (p == null) return 0;
  return p.mainAdvances * 100000 + p.itemIdx * 1000 + p.layer.value * 100;
}

StudentLearningState mergeStudentLearningStateFromCloud(
  StudentLearningState local,
  StudentLearningState remote,
) {
  final mergedAttempts = mergeAttempts(local.attempts, remote.attempts);
  final mergedEvents = mergeEvents(local.events, remote.events);
  final lp = local.progress;
  final rp = remote.progress;
  LessonProgress? mergedProgress;
  if (lp != null && rp != null) {
    final mergedConcluidos = mergeConcluidos(lp.concluidos, rp.concluidos);
    final greaterMainAdvances = lp.mainAdvances > rp.mainAdvances
        ? lp.mainAdvances
        : rp.mainAdvances;
    final baseProgress = _progressRank(lp) >= _progressRank(rp) ? lp : rp;
    mergedProgress = baseProgress.copyWith(
      concluidos: mergedConcluidos,
      mainAdvances: greaterMainAdvances,
    );
  } else {
    mergedProgress = lp ?? rp;
  }
  final curriculum = local.curriculum ?? remote.curriculum;
  final base = _progressRank(lp) >= _progressRank(rp) ? local : remote;
  return base.copyWith(
    curriculum: curriculum,
    progress: mergedProgress,
    attempts: mergedAttempts,
    events: mergedEvents,
    updatedAt: local.updatedAt > remote.updatedAt
        ? local.updatedAt
        : remote.updatedAt,
  );
}
