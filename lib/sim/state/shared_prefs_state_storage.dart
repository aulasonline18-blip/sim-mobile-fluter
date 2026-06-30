import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'student_state_store.dart';

class SharedPrefsStudentStateLocalStorage implements StudentStateLocalStorage {
  SharedPrefsStudentStateLocalStorage(this._prefs, {this.activeLessonLocalId});

  final SharedPreferences _prefs;

  // Set by the caller to protect the active lesson from LRU eviction (I.7)
  String? activeLessonLocalId;

  // Keys must match Web's studentLearningState.store.ts exactly (Planta-Mãe I.6)
  static const String _stateKeyPrefix = 'sim-student-learning-state-v1:lesson:';
  static const String _eventsKeyPrefix = 'sim-events-v1-';
  // Legacy prefix used before I.6 migration — kept for read fallback
  static const String _legacyStatePrefix = 'sim-state-v1-';
  static const String indexKey = 'sim-student-learning-state-v1:index-v2';
  // I.7: keep at most this many recent lessons in local storage
  static const int _keepRecentLessons = 24;

  String _stateKey(String lessonLocalId) =>
      '$_stateKeyPrefix${Uri.encodeComponent(lessonLocalId)}';

  @override
  String? readState(String lessonLocalId) {
    final v = _prefs.getString(_stateKey(lessonLocalId));
    if (v != null) return v;
    // Migrate from legacy key on first read
    return _prefs.getString('$_legacyStatePrefix$lessonLocalId');
  }

  @override
  void writeState(String lessonLocalId, String encoded) {
    _prefs.setString(_stateKey(lessonLocalId), encoded);
    _updateIndexAndReclaim(lessonLocalId);
  }

  @override
  String? readEvents(String lessonLocalId) {
    return _prefs.getString('$_eventsKeyPrefix$lessonLocalId');
  }

  @override
  void writeEvents(String lessonLocalId, String encoded) {
    _prefs.setString('$_eventsKeyPrefix$lessonLocalId', encoded);
  }

  @override
  List<String> listStateIds() => readIndex();

  List<String> readIndex() {
    final raw = _prefs.getStringList(indexKey);
    return raw ?? const [];
  }

  void _updateIndexAndReclaim(String lessonLocalId) {
    final ids = readIndex().toSet()..add(lessonLocalId);
    if (ids.length <= _keepRecentLessons) {
      _prefs.setStringList(indexKey, ids.toList());
      return;
    }
    // I.7: LRU reclaim — remove excess lessons by updatedAt ascending
    // Protected: the lesson being written + the active lesson
    final protected = <String>{lessonLocalId};
    if (activeLessonLocalId != null) protected.add(activeLessonLocalId!);

    final removable = ids.where((id) => !protected.contains(id)).toList();
    // Sort by updatedAt ascending (oldest first) using stored state
    removable.sort((a, b) {
      final aTs = _readUpdatedAt(a);
      final bTs = _readUpdatedAt(b);
      return aTs.compareTo(bTs);
    });

    final excess = ids.length - _keepRecentLessons;
    final toRemove = removable.take(excess).toSet();
    for (final id in toRemove) {
      _prefs.remove(_stateKey(id));
      ids.remove(id);
    }
    _prefs.setStringList(indexKey, ids.toList());
  }

  int _readUpdatedAt(String lessonLocalId) {
    final raw = _prefs.getString(_stateKey(lessonLocalId));
    if (raw == null) return 0;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return (decoded['updatedAt'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }
}
