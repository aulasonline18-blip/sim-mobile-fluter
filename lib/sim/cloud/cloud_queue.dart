import 'dart:async';

import 'package:flutter/widgets.dart';

import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'cloud_functions.dart';
import 'supabase_client_contract.dart';

enum StudentLearningSyncOperation { patch, tombstone }

class CloudQueueEntry {
  const CloudQueueEntry({
    required this.lessonLocalId,
    required this.operation,
    required this.pendingSince,
    required this.attempts,
    required this.nextRetryAt,
  });

  final String lessonLocalId;
  final StudentLearningSyncOperation operation;
  final int pendingSince;
  final int attempts;
  final int nextRetryAt;

  CloudQueueEntry copyWith({
    StudentLearningSyncOperation? operation,
    int? pendingSince,
    int? attempts,
    int? nextRetryAt,
  }) {
    return CloudQueueEntry(
      lessonLocalId: lessonLocalId,
      operation: operation ?? this.operation,
      pendingSince: pendingSince ?? this.pendingSince,
      attempts: attempts ?? this.attempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
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

class CloudQueue with WidgetsBindingObserver {
  CloudQueue({
    required this.storage,
    required this.stateService,
    required this.sessionProvider,
    required this.cloudFunctions,
    this.now,
  });

  static const int debounceMs = 1500;
  static const List<int> retryDelaysMs = [2000, 5000, 15000, 60000, 300000];
  static const int maxAttempts = 10;

  final CloudQueueStorage storage;
  final StudentLearningStateService stateService;
  final SupabaseSessionProvider sessionProvider;
  final StudentStateCloudFunctions cloudFunctions;
  final int Function()? now;
  bool draining = false;
  final Map<String, Timer> _retryTimers = {};

  int get _now => now?.call() ?? DateTime.now().millisecondsSinceEpoch;

  void enqueueStudentStateSync({
    required String lessonLocalId,
    StudentLearningSyncOperation operation = StudentLearningSyncOperation.patch,
  }) {
    if (lessonLocalId.isEmpty) return;
    final bag = storage.readQueue();
    final prev = bag[lessonLocalId];
    bag[lessonLocalId] = CloudQueueEntry(
      lessonLocalId: lessonLocalId,
      operation: operation,
      pendingSince: prev?.pendingSince ?? _now,
      attempts: 0,
      nextRetryAt: _now + debounceMs,
    );
    storage.writeQueue(bag);
  }

  Future<void> drainQueue({bool force = true}) async {
    if (draining) return;
    draining = true;
    try {
      final ids = storage.readQueue().keys.toList(growable: false);
      for (final id in ids) {
        await flushOne(id, force: force);
      }
    } finally {
      draining = false;
    }
  }

  Future<void> flushOne(String lessonLocalId, {bool force = false}) async {
    final entry = storage.readQueue()[lessonLocalId];
    if (entry == null) return;
    if (!force && entry.nextRetryAt > _now) return;
    final session = await sessionProvider.currentSession();
    if (session == null) return;
    final snap = stateService.read(lessonLocalId);
    if (snap == null) {
      _scheduleRetry(entry);
      return;
    }
    try {
      if (entry.operation == StudentLearningSyncOperation.tombstone ||
          snap.extra['deletedAt'] != null) {
        await cloudFunctions.deleteStudentStateByLesson(lessonLocalId, session);
        storage.writeLastHash(lessonLocalId, 'tombstone:${snap.updatedAt}');
        _remove(lessonLocalId);
        return;
      }
      final contentHash = stableHash(snap);
      if (storage.readLastHashes()[lessonLocalId] == contentHash) {
        _remove(lessonLocalId);
        return;
      }
      final result = await cloudFunctions.persistStudentState(
        PersistStudentStateInput(
          lessonLocalId: lessonLocalId,
          state: snap,
          clientUpdatedAt: snap.updatedAt,
          clientScore: scoreOfStudentLearningState(snap),
          schemaVersion: snap.stateVersion,
        ),
        session,
      );
      if (result.rejected && result.remoteState != null) {
        stateService.write(mergeStudentLearningStateFromCloud(snap, result.remoteState!));
        enqueueStudentStateSync(lessonLocalId: lessonLocalId);
        return;
      }
      storage.writeLastHash(lessonLocalId, contentHash);
      _remove(lessonLocalId);
    } catch (_) {
      _scheduleRetry(entry);
    }
  }

  Map<String, CloudQueueEntry> getQueueSnapshot() => storage.readQueue();

  void wireCloudQueueLifecycle() {
    WidgetsBinding.instance.addObserver(this);
    Future.delayed(const Duration(seconds: 1), () => drainQueue());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      drainQueue(force: true);
    }
  }

  void _remove(String lessonLocalId) {
    final bag = storage.readQueue()..remove(lessonLocalId);
    storage.writeQueue(bag);
  }

  void _scheduleRetry(CloudQueueEntry entry) {
    final attempts = entry.attempts + 1;
    final delay = retryDelaysMs[
        (attempts - 1).clamp(0, retryDelaysMs.length - 1)];
    final bag = storage.readQueue();
    bag[entry.lessonLocalId] = entry.copyWith(
      attempts: attempts,
      nextRetryAt: _now + delay,
    );
    storage.writeQueue(bag);
    _retryTimers[entry.lessonLocalId]?.cancel();
    _retryTimers[entry.lessonLocalId] = Timer(
      Duration(milliseconds: delay),
      () => flushOne(entry.lessonLocalId, force: false),
    );
  }
}

String stableHash(StudentLearningState state) {
  final json = Map<String, dynamic>.from(state.toJson())
    ..remove('updatedAt')
    ..remove('cacheInfo')
    ..remove('syncInfo');
  final input = json.toString();
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
  final remoteScore = scoreOfStudentLearningState(remote);
  final localScore = scoreOfStudentLearningState(local);
  if (remoteScore > localScore) return remote;
  if (remoteScore == localScore && remote.updatedAt > local.updatedAt) {
    return remote;
  }
  return local;
}
