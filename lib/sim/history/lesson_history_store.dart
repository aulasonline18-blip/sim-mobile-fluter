import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../state/student_learning_state.dart';
import '../state/student_learning_state_persistence.dart';

typedef JsonMap = Map<String, dynamic>;

const lessonHistoryIndexKey = 'sim.lesson_history.index.v1';
const activeLessonHistoryKey = 'sim.lesson_history.active.v1';

class LessonHistoryEntry {
  const LessonHistoryEntry({
    required this.lessonLocalId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.progressPercent,
    required this.status,
    required this.userId,
    required this.deleted,
    this.deletedAt,
    this.deletedBy,
    this.tombstoneVersion = 0,
    this.highWaterMark = 0,
    this.eventCount = 0,
    this.lastMarker,
    this.layer,
  });

  final String lessonLocalId;
  final String title;
  final int createdAt;
  final int updatedAt;
  final int progressPercent;
  final String status;
  final String? userId;
  final bool deleted;
  final int? deletedAt;
  final String? deletedBy;
  final int tombstoneVersion;
  final int highWaterMark;
  final int eventCount;
  final String? lastMarker;
  final String? layer;

  JsonMap toJson() => {
        'lessonLocalId': lessonLocalId,
        'title': title,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'progressPercent': progressPercent,
        'status': status,
        'userId': userId,
        'deleted': deleted,
        'deletedAt': deletedAt,
        'deletedBy': deletedBy,
        'tombstoneVersion': tombstoneVersion,
        'highWaterMark': highWaterMark,
        'eventCount': eventCount,
        'lastMarker': lastMarker,
        'layer': layer,
      };

  factory LessonHistoryEntry.fromJson(JsonMap json) => LessonHistoryEntry(
        lessonLocalId: (json['lessonLocalId'] ?? '').toString(),
        title: (json['title'] ?? 'Aula sem nome').toString(),
        createdAt: (json['createdAt'] as num?)?.toInt() ?? 0,
        updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
        progressPercent:
            ((json['progressPercent'] as num?)?.toInt() ?? 0).clamp(0, 100),
        status: (json['status'] ?? 'em_andamento').toString(),
        userId: json['userId'] as String?,
        deleted: json['deleted'] == true,
        deletedAt: (json['deletedAt'] as num?)?.toInt(),
        deletedBy: json['deletedBy'] as String?,
        tombstoneVersion: (json['tombstoneVersion'] as num?)?.toInt() ?? 0,
        highWaterMark: (json['highWaterMark'] as num?)?.toInt() ?? 0,
        eventCount: (json['eventCount'] as num?)?.toInt() ?? 0,
        lastMarker: json['lastMarker'] as String?,
        layer: json['layer'] as String?,
      );

  LessonHistoryEntry copyWith({
    String? title,
    int? updatedAt,
    int? progressPercent,
    String? status,
    bool? deleted,
    int? deletedAt,
    String? deletedBy,
    int? tombstoneVersion,
    int? highWaterMark,
    int? eventCount,
    String? lastMarker,
    String? layer,
  }) {
    return LessonHistoryEntry(
      lessonLocalId: lessonLocalId,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      progressPercent: progressPercent ?? this.progressPercent,
      status: status ?? this.status,
      userId: userId,
      deleted: deleted ?? this.deleted,
      deletedAt: deletedAt ?? this.deletedAt,
      deletedBy: deletedBy ?? this.deletedBy,
      tombstoneVersion: tombstoneVersion ?? this.tombstoneVersion,
      highWaterMark: highWaterMark ?? this.highWaterMark,
      eventCount: eventCount ?? this.eventCount,
      lastMarker: lastMarker ?? this.lastMarker,
      layer: layer ?? this.layer,
    );
  }
}

class LessonBackupEnvelope {
  const LessonBackupEnvelope({
    required this.schemaVersion,
    required this.appVersion,
    required this.exportedAt,
    required this.userId,
    required this.activeLessonLocalId,
    required this.lessons,
    required this.states,
  });

  final int schemaVersion;
  final String appVersion;
  final int exportedAt;
  final String? userId;
  final String? activeLessonLocalId;
  final List<LessonHistoryEntry> lessons;
  final List<StudentLearningState> states;

  JsonMap toJson() => {
        'schemaVersion': schemaVersion,
        'appVersion': appVersion,
        'exportedAt': exportedAt,
        'userId': userId,
        'activeLessonLocalId': activeLessonLocalId,
        'lessons': lessons.map((lesson) => lesson.toJson()).toList(),
        'states': states.map((state) => state.toJson()).toList(),
      };

  factory LessonBackupEnvelope.fromJson(JsonMap json) => LessonBackupEnvelope(
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
        appVersion: (json['appVersion'] ?? '').toString(),
        exportedAt: (json['exportedAt'] as num?)?.toInt() ?? 0,
        userId: json['userId'] as String?,
        activeLessonLocalId: json['activeLessonLocalId'] as String?,
        lessons: (json['lessons'] as List? ?? const [])
            .whereType<Map>()
            .map((entry) => LessonHistoryEntry.fromJson(JsonMap.from(entry)))
            .where((entry) => entry.lessonLocalId.isNotEmpty)
            .toList(),
        states: (json['states'] as List? ?? const [])
            .whereType<Map>()
            .map((state) => StudentLearningState.fromJson(JsonMap.from(state)))
            .where((state) => state.lessonLocalId.isNotEmpty)
            .toList(),
      );
}

class LessonHistoryStore {
  LessonHistoryStore(this._prefs, this._statePersistence);

  final SharedPreferences _prefs;
  final StudentLearningStatePersistence _statePersistence;

  static Future<LessonHistoryStore> create() async {
    final prefs = await SharedPreferences.getInstance();
    return LessonHistoryStore(
      prefs,
      SharedPreferencesStudentLearningStatePersistence(prefs),
    );
  }

  Future<List<LessonHistoryEntry>> readEntries({
    bool includeDeleted = false,
  }) async {
    final raw = _prefs.getString(lessonHistoryIndexKey);
    final decoded = raw == null ? null : jsonDecode(raw);
    final entries = decoded is List
        ? decoded
            .whereType<Map>()
            .map((entry) => LessonHistoryEntry.fromJson(JsonMap.from(entry)))
            .where((entry) => entry.lessonLocalId.isNotEmpty)
            .toList()
        : <LessonHistoryEntry>[];

    final states = await _statePersistence.readAll();
    final byId = {for (final entry in entries) entry.lessonLocalId: entry};
    var changed = false;
    for (final state in states) {
      final entry = entryFromState(
        state,
        previous: byId[state.lessonLocalId],
      );
      if (byId[state.lessonLocalId]?.toJson().toString() !=
          entry.toJson().toString()) {
        byId[state.lessonLocalId] = entry;
        changed = true;
      }
    }
    final merged = byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (changed) await _writeEntries(merged);
    return includeDeleted
        ? merged
        : merged.where((entry) => !entry.deleted).toList(growable: false);
  }

  Future<void> saveState(StudentLearningState state) async {
    await _statePersistence.write(state);
    final entries = await readEntries(includeDeleted: true);
    final byId = {for (final entry in entries) entry.lessonLocalId: entry};
    byId[state.lessonLocalId] = entryFromState(
      state,
      previous: byId[state.lessonLocalId],
    );
    await _writeEntries(byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
  }

  Future<StudentLearningState?> readState(String lessonLocalId) {
    return _statePersistence.read(lessonLocalId);
  }

  Future<String?> readActiveLessonLocalId() async {
    return _prefs.getString(activeLessonHistoryKey);
  }

  Future<void> setActiveLessonLocalId(String lessonLocalId) async {
    await _prefs.setString(activeLessonHistoryKey, lessonLocalId);
  }

  Future<void> renameLesson(String lessonLocalId, String title) async {
    final clean = title.trim();
    if (clean.isEmpty) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final state = await _statePersistence.read(lessonLocalId);
    if (state != null) {
      await _statePersistence.write(
        state.copyWith(
          updatedAt: now,
          events: [
            ...state.events,
            StudentLearningEvent(
              type: 'LESSON_RENAMED',
              ts: now,
              payload: {'lessonLocalId': lessonLocalId, 'title': clean},
            ),
          ],
          extra: {...state.extra, 'displayName': clean},
        ),
      );
    }
    final entries = await readEntries(includeDeleted: true);
    await _writeEntries([
      for (final entry in entries)
        entry.lessonLocalId == lessonLocalId
            ? entry.copyWith(title: clean, updatedAt: now)
            : entry,
    ]);
  }

  Future<void> tombstoneLesson(
    String lessonLocalId, {
    required String? userId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final state = await _statePersistence.read(lessonLocalId);
    if (state != null) {
      await _statePersistence.write(
        state.copyWith(
          updatedAt: now,
          events: [
            ...state.events,
            StudentLearningEvent(
              type: 'LESSON_TOMBSTONED',
              ts: now,
              payload: {
                'lessonLocalId': lessonLocalId,
                'deletedAt': now,
                'deletedBy': userId,
                'financialDataDeleted': false,
              },
            ),
          ],
          extra: {
            ...state.extra,
            'deleted': true,
            'deletedAt': now,
            'deletedBy': userId,
            'tombstoneVersion':
                ((state.extra['tombstoneVersion'] as num?)?.toInt() ?? 0) + 1,
          },
        ),
      );
    }
    final entries = await readEntries(includeDeleted: true);
    await _writeEntries([
      for (final entry in entries)
        entry.lessonLocalId == lessonLocalId
            ? entry.copyWith(
                deleted: true,
                deletedAt: now,
                deletedBy: userId,
                updatedAt: now,
                tombstoneVersion: entry.tombstoneVersion + 1,
                status: 'apagada',
              )
            : entry,
    ]);
  }

  Future<LessonBackupEnvelope> exportBackup({String? userId}) async {
    final entries = await readEntries(includeDeleted: true);
    final states = <StudentLearningState>[];
    for (final entry in entries) {
      final state = await _statePersistence.read(entry.lessonLocalId);
      if (state != null) states.add(state);
    }
    return LessonBackupEnvelope(
      schemaVersion: 1,
      appVersion: '1.0.0',
      exportedAt: DateTime.now().millisecondsSinceEpoch,
      userId: userId,
      activeLessonLocalId: await readActiveLessonLocalId(),
      lessons: entries,
      states: states,
    );
  }

  Future<void> importBackup(
    LessonBackupEnvelope backup, {
    required String? currentUserId,
  }) async {
    if (backup.schemaVersion != 1) {
      throw const FormatException('Versao de backup incompativel.');
    }
    if (backup.states.isEmpty) {
      throw const FormatException('Backup sem estado de aula.');
    }
    if (backup.userId != null &&
        currentUserId != null &&
        backup.userId != currentUserId) {
      throw const FormatException('Backup pertence a outro usuario.');
    }
    final existing = await readEntries(includeDeleted: true);
    final byId = {for (final entry in existing) entry.lessonLocalId: entry};
    for (final state in backup.states) {
      await _statePersistence.write(state);
      byId[state.lessonLocalId] = entryFromState(
        state,
        previous: byId[state.lessonLocalId],
      );
    }
    for (final entry in backup.lessons) {
      final current = byId[entry.lessonLocalId];
      if (current == null || entry.updatedAt >= current.updatedAt) {
        byId[entry.lessonLocalId] = entry;
      }
    }
    await _writeEntries(byId.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)));
    final active = backup.activeLessonLocalId;
    if (active != null && active.trim().isNotEmpty) {
      await setActiveLessonLocalId(active);
    }
  }

  Future<void> _writeEntries(List<LessonHistoryEntry> entries) async {
    await _prefs.setString(
      lessonHistoryIndexKey,
      jsonEncode(entries.map((entry) => entry.toJson()).toList()),
    );
  }
}

LessonHistoryEntry entryFromState(
  StudentLearningState state, {
  LessonHistoryEntry? previous,
}) {
  final progress = state.progress;
  final current = state.current;
  final total = progress?.totalItems ?? state.curriculum?.items.length ?? 0;
  final idx = progress?.itemIdx ?? current?.itemIdx ?? 0;
  final pct = total <= 0 ? 0 : ((idx / total) * 100).clamp(0, 100).round();
  final deletedAt = (state.extra['deletedAt'] as num?)?.toInt();
  final title = (state.extra['displayName'] ??
          state.extra['title'] ??
          state.profile.targetTopic ??
          state.profile.objetivo ??
          previous?.title ??
          'Aula ${state.lessonLocalId}')
      .toString();
  final completed =
      pct >= 100 || state.extra['entryStatus']?.toString() == 'completed';
  final status = deletedAt != null
      ? 'apagada'
      : completed
          ? 'concluida'
          : 'em_andamento';
  return LessonHistoryEntry(
    lessonLocalId: state.lessonLocalId,
    title: title.trim().isEmpty ? 'Aula ${state.lessonLocalId}' : title.trim(),
    createdAt: state.createdAt,
    updatedAt: state.updatedAt,
    progressPercent: pct,
    status: status,
    userId: state.userId,
    deleted: deletedAt != null || state.extra['deleted'] == true,
    deletedAt: deletedAt,
    deletedBy: state.extra['deletedBy'] as String?,
    tombstoneVersion: (state.extra['tombstoneVersion'] as num?)?.toInt() ?? 0,
    highWaterMark: state.updatedAt,
    eventCount: state.events.length,
    lastMarker: current?.marker,
    layer: current?.layer.name,
  );
}
