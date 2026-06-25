import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'cloud_functions.dart';
import 'supabase_client_contract.dart';

enum StudentLearningSyncOperation {
  patch,
  syncState,
  syncEvent,
  syncSnapshot,
  tombstone,
}

class CloudQueueEntry {
  const CloudQueueEntry({
    required this.lessonLocalId,
    required this.operation,
    required this.pendingSince,
    required this.attempts,
    required this.nextRetryAt,
    required this.jobId,
    required this.idempotencyKey,
    required this.status,
    this.eventId,
    this.snapshotVersion,
  });

  final String lessonLocalId;
  final StudentLearningSyncOperation operation;
  final int pendingSince;
  final int attempts;
  final int nextRetryAt;
  final String jobId;
  final String idempotencyKey;
  final String status;
  final String? eventId;
  final int? snapshotVersion;

  CloudQueueEntry copyWith({
    StudentLearningSyncOperation? operation,
    int? pendingSince,
    int? attempts,
    int? nextRetryAt,
    String? jobId,
    String? idempotencyKey,
    String? status,
    String? eventId,
    int? snapshotVersion,
  }) {
    return CloudQueueEntry(
      lessonLocalId: lessonLocalId,
      operation: operation ?? this.operation,
      pendingSince: pendingSince ?? this.pendingSince,
      attempts: attempts ?? this.attempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      jobId: jobId ?? this.jobId,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      status: status ?? this.status,
      eventId: eventId ?? this.eventId,
      snapshotVersion: snapshotVersion ?? this.snapshotVersion,
    );
  }

  JsonMap toJson() => {
        'lessonLocalId': lessonLocalId,
        'operation': operation.name,
        'pendingSince': pendingSince,
        'attempts': attempts,
        'nextRetryAt': nextRetryAt,
        'jobId': jobId,
        'idempotencyKey': idempotencyKey,
        'status': status,
        if (eventId != null) 'eventId': eventId,
        if (snapshotVersion != null) 'snapshotVersion': snapshotVersion,
      };

  static CloudQueueEntry fromJson(JsonMap json) {
    final operationName = json['operation'] as String? ?? 'patch';
    final operation = StudentLearningSyncOperation.values.firstWhere(
      (value) => value.name == operationName,
      orElse: () => StudentLearningSyncOperation.patch,
    );
    final lessonLocalId = json['lessonLocalId'] as String? ?? '';
    final pendingSince = (json['pendingSince'] as num?)?.toInt() ?? 0;
    final eventId = json['eventId'] as String?;
    final snapshotVersion = (json['snapshotVersion'] as num?)?.toInt();
    final key = json['idempotencyKey'] as String? ??
        _buildIdempotencyKey(
          operation: operation,
          lessonLocalId: lessonLocalId,
          eventId: eventId,
          snapshotVersion: snapshotVersion,
        );
    return CloudQueueEntry(
      lessonLocalId: lessonLocalId,
      operation: operation,
      pendingSince: pendingSince,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      nextRetryAt: (json['nextRetryAt'] as num?)?.toInt() ?? pendingSince,
      jobId: json['jobId'] as String? ?? key,
      idempotencyKey: key,
      status: json['status'] as String? ?? 'pending',
      eventId: eventId,
      snapshotVersion: snapshotVersion,
    );
  }
}

abstract interface class CloudQueueStorage {
  Map<String, CloudQueueEntry> readQueue();
  void writeQueue(Map<String, CloudQueueEntry> queue);
  Map<String, String> readLastHashes();
  void writeLastHash(String lessonLocalId, String hash);
}

class MemoryCloudQueueStorage implements CloudQueueStorage {
  Map<String, CloudQueueEntry> queue = {};
  Map<String, String> hashes = {};

  @override
  Map<String, CloudQueueEntry> readQueue() => Map.of(queue);

  @override
  void writeQueue(Map<String, CloudQueueEntry> queue) {
    this.queue = Map.of(queue);
  }

  @override
  Map<String, String> readLastHashes() => Map.of(hashes);

  @override
  void writeLastHash(String lessonLocalId, String hash) {
    hashes[lessonLocalId] = hash;
  }
}

class SharedPreferencesCloudQueueStorage implements CloudQueueStorage {
  SharedPreferencesCloudQueueStorage(this.preferences);

  static const queueKey = 'sim.cloud_queue.v1';
  static const hashesKey = 'sim.cloud_queue.hashes.v1';

  final SharedPreferences preferences;

  @override
  Map<String, CloudQueueEntry> readQueue() {
    final raw = preferences.getString(queueKey);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(
          key.toString(),
          CloudQueueEntry.fromJson(JsonMap.from(value as Map)),
        ),
      );
    } catch (_) {
      return {};
    }
  }

  @override
  void writeQueue(Map<String, CloudQueueEntry> queue) {
    preferences.setString(
      queueKey,
      jsonEncode(queue.map((key, value) => MapEntry(key, value.toJson()))),
    );
  }

  @override
  Map<String, String> readLastHashes() {
    final raw = preferences.getString(hashesKey);
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((key, value) => MapEntry(key.toString(), '$value'));
    } catch (_) {
      return {};
    }
  }

  @override
  void writeLastHash(String lessonLocalId, String hash) {
    final hashes = readLastHashes()..[lessonLocalId] = hash;
    preferences.setString(hashesKey, jsonEncode(hashes));
  }
}

class CloudQueue {
  CloudQueue({
    required this.storage,
    required this.stateService,
    required this.sessionProvider,
    required this.cloudFunctions,
    this.now,
  });

  static const int debounceMs = 1500;
  static const List<int> retryDelaysMs = [2000, 5000, 15000];
  static const int maxAttempts = 3;

  final CloudQueueStorage storage;
  final StudentLearningStateService stateService;
  final SupabaseSessionProvider sessionProvider;
  final StudentStateCloudFunctions cloudFunctions;
  final int Function()? now;
  bool draining = false;

  int get _now => now?.call() ?? DateTime.now().millisecondsSinceEpoch;

  void enqueueStudentStateSync({
    required String lessonLocalId,
    StudentLearningSyncOperation operation = StudentLearningSyncOperation.patch,
    String? eventId,
    int? snapshotVersion,
  }) {
    if (lessonLocalId.isEmpty) return;
    final effectiveOperation = operation == StudentLearningSyncOperation.patch
        ? StudentLearningSyncOperation.syncState
        : operation;
    final idempotencyKey = _buildIdempotencyKey(
      operation: effectiveOperation,
      lessonLocalId: lessonLocalId,
      eventId: eventId,
      snapshotVersion: snapshotVersion,
    );
    final queueKey = eventId == null && snapshotVersion == null
        ? lessonLocalId
        : idempotencyKey;
    final bag = storage.readQueue();
    final prev = bag[queueKey];
    bag[queueKey] = CloudQueueEntry(
      lessonLocalId: lessonLocalId,
      operation: effectiveOperation,
      pendingSince: prev?.pendingSince ?? _now,
      attempts: 0,
      nextRetryAt: _now + debounceMs,
      jobId: prev?.jobId ?? 'job-${_now.toRadixString(36)}-$queueKey',
      idempotencyKey: idempotencyKey,
      status: 'pending',
      eventId: eventId,
      snapshotVersion: snapshotVersion,
    );
    storage.writeQueue(bag);
  }

  Future<void> drainQueue({bool force = true}) async {
    if (draining) return;
    draining = true;
    try {
      final keys = storage.readQueue().keys.toList(growable: false);
      keys.sort((a, b) {
        final left = storage.readQueue()[a];
        final right = storage.readQueue()[b];
        return _priorityOf(left?.operation)
            .compareTo(_priorityOf(right?.operation));
      });
      for (final key in keys) {
        await flushOne(key, force: force);
      }
    } finally {
      draining = false;
    }
  }

  Future<void> flushOne(String queueKey, {bool force = false}) async {
    final entry = storage.readQueue()[queueKey] ??
        storage.readQueue()[_legacyKey(queueKey)];
    if (entry == null) return;
    if (!force && entry.nextRetryAt > _now) return;
    final session = await sessionProvider.currentSession();
    if (session == null) return;
    final snap = stateService.read(entry.lessonLocalId);
    if (snap == null) {
      _scheduleRetry(entry);
      return;
    }
    try {
      final snapshot = _snapshotState(snap, entry);
      if (entry.operation == StudentLearningSyncOperation.tombstone ||
          _isTombstone(snapshot)) {
        await cloudFunctions.deleteStudentStateByLesson(
          entry.lessonLocalId,
          session,
        );
        storage.writeLastHash(
          entry.lessonLocalId,
          'tombstone:${snapshot.extra['deletedAt'] ?? snapshot.updatedAt}',
        );
        _removeEntry(entry);
        return;
      }
      final contentHash = stableHash(snapshot);
      if (storage.readLastHashes()[entry.lessonLocalId] == contentHash) {
        _removeEntry(entry);
        return;
      }
      final result = await cloudFunctions.persistStudentState(
        PersistStudentStateInput(
          lessonLocalId: entry.lessonLocalId,
          state: snapshot,
          clientUpdatedAt: snapshot.updatedAt,
          clientScore: scoreOfStudentLearningState(snapshot),
          schemaVersion: snapshot.stateVersion,
        ),
        session,
      );
      if (result.rejected && result.remoteState != null) {
        final merged = mergeStudentLearningStateFromCloud(
          snapshot,
          result.remoteState!,
        );
        stateService.write(
          _appendEvent(
            merged,
            merged.lessonLocalId,
            'SYNC_CONFLICT_RESOLVED',
            {
              'source': scoreOfStudentLearningState(merged) >=
                      scoreOfStudentLearningState(snapshot)
                  ? 'remote_or_equal'
                  : 'local',
              'remoteHighWaterMark': result.remoteHighWaterMark,
              'blockedRegression': identical(merged, snapshot),
            },
          ),
        );
        enqueueStudentStateSync(lessonLocalId: entry.lessonLocalId);
        return;
      }
      storage.writeLastHash(entry.lessonLocalId, contentHash);
      _removeEntry(entry);
    } catch (_) {
      _scheduleRetry(entry);
    }
  }

  Future<List<StudentLearningState>> pullCloudSnapshots() async {
    final session = await sessionProvider.currentSession();
    if (session == null) return const [];
    final rows = await cloudFunctions.listStudentStates(session);
    final restored = <StudentLearningState>[];
    for (final row in rows) {
      final remote = row.state;
      if (remote == null || row.lessonLocalId.isEmpty) continue;
      final local = stateService.read(row.lessonLocalId);
      final merged = local == null
          ? _appendEvent(
              remote,
              row.lessonLocalId,
              'SNAPSHOT_RESTORED',
              {'source': 'cloud', 'highWaterMark': row.highWaterMark},
            )
          : mergeStudentLearningStateFromCloud(local, remote);
      if (local != null && !identical(merged, remote) && _isTombstone(local)) {
        enqueueStudentStateSync(
          lessonLocalId: local.lessonLocalId,
          operation: StudentLearningSyncOperation.tombstone,
        );
      }
      stateService.write(
        _appendEvent(
          merged,
          row.lessonLocalId,
          'SYNC_CONFLICT_RESOLVED',
          {
            'source': local == null ? 'remote' : 'anti_regression_merge',
            'remoteHighWaterMark': row.highWaterMark,
          },
        ),
      );
      restored.add(stateService.read(row.lessonLocalId) ?? merged);
    }
    return restored;
  }

  Map<String, CloudQueueEntry> getQueueSnapshot() => storage.readQueue();

  void wireCloudQueueLifecycle() {}

  void _removeEntry(CloudQueueEntry entry) {
    final bag = storage.readQueue()..remove(_storageKeyFor(entry));
    storage.writeQueue(bag);
  }

  void _scheduleRetry(CloudQueueEntry entry) {
    final attempts = entry.attempts + 1;
    if (attempts > maxAttempts) {
      final bag = storage.readQueue();
      bag[_storageKeyFor(entry)] =
          entry.copyWith(attempts: attempts, status: 'pending');
      storage.writeQueue(bag);
      return;
    }
    final delay =
        retryDelaysMs[(attempts - 1).clamp(0, retryDelaysMs.length - 1)];
    final bag = storage.readQueue();
    bag[_storageKeyFor(entry)] = entry.copyWith(
      attempts: attempts,
      nextRetryAt: _now + delay,
      status: 'pending',
    );
    storage.writeQueue(bag);
  }

  StudentLearningState _snapshotState(
    StudentLearningState state,
    CloudQueueEntry entry,
  ) {
    final version = entry.snapshotVersion ??
        (state.extra['snapshotVersion'] as num?)?.toInt() ??
        state.events.length;
    return _appendEvent(
      state.copyWith(
        extra: {
          ...state.extra,
          'syncInfo': {
            ...(state.extra['syncInfo'] is Map
                ? JsonMap.from(state.extra['syncInfo'] as Map)
                : const <String, dynamic>{}),
            'version': state.stateVersion,
            'snapshotVersion': version,
            'deviceId': state.extra['deviceId'] ?? 'flutter-android',
            'highWaterMark': scoreOfStudentLearningState(state),
            'eventCount': state.events.length,
            'queueSize': storage.readQueue().length,
            'lastQueuedAt': entry.pendingSince,
            'idempotencyKey': entry.idempotencyKey,
          },
          'highWaterMark': scoreOfStudentLearningState(state),
          'snapshotVersion': version,
        },
      ),
      state.lessonLocalId,
      'SNAPSHOT_CREATED',
      {
        'snapshotVersion': version,
        'jobId': entry.jobId,
        'operation': entry.operation.name,
      },
    );
  }
}

String _storageKeyFor(CloudQueueEntry entry) {
  return entry.eventId == null && entry.snapshotVersion == null
      ? entry.lessonLocalId
      : entry.idempotencyKey;
}

String stableHash(StudentLearningState state) {
  final json = Map<String, dynamic>.from(state.toJson())
    ..remove('updatedAt')
    ..remove('cacheInfo')
    ..remove('syncInfo');
  final input = jsonEncode(json);
  var hash = 5381;
  for (final unit in input.codeUnits) {
    hash = ((hash << 5) + hash) ^ unit;
  }
  return (hash & 0xffffffff).toRadixString(36);
}

StudentLearningState mergeStudentLearningStateFromCloud(
  StudentLearningState local,
  StudentLearningState remote,
) {
  if (_isTombstone(local) && !_isNewerThan(remote, local)) return local;
  if (_isTombstone(remote) && !_isNewerThan(local, remote)) return remote;
  final remoteScore = scoreOfStudentLearningState(remote);
  final localScore = scoreOfStudentLearningState(local);
  final remoteEvents = remote.events.length;
  final localEvents = local.events.length;
  if (remoteScore > localScore) return remote;
  if (localScore > remoteScore) return local;
  if (remoteEvents > localEvents) return remote;
  if (localEvents > remoteEvents) return local;
  if (remote.updatedAt > local.updatedAt) return remote;
  return local;
}

StudentLearningState _appendEvent(
  StudentLearningState state,
  String lessonLocalId,
  String type,
  JsonMap payload,
) {
  return state.copyWith(
    lessonLocalId: lessonLocalId,
    events: [
      ...state.events,
      StudentLearningEvent(
        type: type,
        ts: DateTime.now().millisecondsSinceEpoch,
        payload: payload,
      ),
    ],
  );
}

String _buildIdempotencyKey({
  required StudentLearningSyncOperation operation,
  required String lessonLocalId,
  String? eventId,
  int? snapshotVersion,
}) {
  return [
    operation.name,
    lessonLocalId,
    if (eventId != null) eventId,
    if (snapshotVersion != null) snapshotVersion,
  ].join(':');
}

String _legacyKey(String key) =>
    key.split(':').length > 1 ? key.split(':')[1] : key;

int _priorityOf(StudentLearningSyncOperation? operation) {
  switch (operation) {
    case StudentLearningSyncOperation.patch:
    case StudentLearningSyncOperation.syncState:
      return 0;
    case StudentLearningSyncOperation.syncEvent:
      return 1;
    case StudentLearningSyncOperation.syncSnapshot:
      return 2;
    case StudentLearningSyncOperation.tombstone:
      return -1;
    case null:
      return 3;
  }
}

bool _isTombstone(StudentLearningState state) {
  return state.extra['deletedAt'] != null ||
      state.extra['deleted'] == true ||
      (state.extra['syncInfo'] is Map &&
          (state.extra['syncInfo'] as Map)['deletedAt'] != null);
}

bool _isNewerThan(StudentLearningState left, StudentLearningState right) {
  final leftWater = (left.extra['highWaterMark'] as num?)?.toInt() ??
      scoreOfStudentLearningState(left);
  final rightWater = (right.extra['highWaterMark'] as num?)?.toInt() ??
      scoreOfStudentLearningState(right);
  if (leftWater != rightWater) return leftWater > rightWater;
  if (left.events.length != right.events.length) {
    return left.events.length > right.events.length;
  }
  return left.updatedAt > right.updatedAt;
}
