import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_queue.dart';

class SharedPrefsCloudQueueStorage implements CloudQueueStorage {
  SharedPrefsCloudQueueStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _queueKey = 'sim-student-state-queue-v1';
  static const String _hashKey = 'sim-student-state-queue-hash-v1';

  @override
  Map<String, CloudQueueEntry> readQueue() {
    final raw = _prefs.getString(_queueKey);
    if (raw == null || raw.trim().isEmpty) return {};
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return {};
    }
    if (decoded is! Map) return {};
    final result = <String, CloudQueueEntry>{};
    for (final entry in decoded.entries) {
      final id = entry.key.toString();
      final value = entry.value;
      if (value is! Map) continue;
      final opRaw = value['operation']?.toString();
      final op = opRaw == 'tombstone'
          ? StudentLearningSyncOperation.tombstone
          : StudentLearningSyncOperation.patch;
      result[id] = CloudQueueEntry(
        lessonLocalId: id,
        operation: op,
        pendingSince: (value['pendingSince'] as num?)?.toInt() ?? 0,
        attempts: (value['attempts'] as num?)?.toInt() ?? 0,
        nextRetryAt: (value['nextRetryAt'] as num?)?.toInt() ?? 0,
      );
    }
    return result;
  }

  @override
  void writeQueue(Map<String, CloudQueueEntry> queue) {
    final map = <String, dynamic>{};
    for (final entry in queue.entries) {
      map[entry.key] = {
        'lessonLocalId': entry.value.lessonLocalId,
        'operation': entry.value.operation == StudentLearningSyncOperation.tombstone
            ? 'tombstone'
            : 'patch',
        'pendingSince': entry.value.pendingSince,
        'attempts': entry.value.attempts,
        'nextRetryAt': entry.value.nextRetryAt,
      };
    }
    _prefs.setString(_queueKey, jsonEncode(map));
  }

  @override
  Map<String, String> readLastHashes() {
    final raw = _prefs.getString(_hashKey);
    if (raw == null || raw.trim().isEmpty) return {};
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return {};
    }
    if (decoded is! Map) return {};
    return Map<String, String>.fromEntries(
      decoded.entries.map((e) => MapEntry(e.key.toString(), e.value.toString())),
    );
  }

  @override
  void writeLastHash(String lessonLocalId, String hash) {
    final hashes = readLastHashes();
    hashes[lessonLocalId] = hash;
    _prefs.setString(_hashKey, jsonEncode(hashes));
  }
}
