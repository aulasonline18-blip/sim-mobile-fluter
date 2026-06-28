import 'package:shared_preferences/shared_preferences.dart';

import 'student_state_store.dart';

class SharedPrefsStudentStateLocalStorage implements StudentStateLocalStorage {
  SharedPrefsStudentStateLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  // Keys must match Web's studentLearningState.store.ts exactly (Planta-Mãe I.6)
  static const String _stateKeyPrefix = 'sim-student-learning-state-v1:lesson:';
  static const String _eventsKeyPrefix = 'sim-events-v1-';
  // Legacy prefix used before I.6 migration — kept for read fallback
  static const String _legacyStatePrefix = 'sim-state-v1-';
  static const String indexKey = 'sim-student-learning-state-v1:index-v2';

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
    _updateIndex(lessonLocalId);
  }

  @override
  String? readEvents(String lessonLocalId) {
    return _prefs.getString('$_eventsKeyPrefix$lessonLocalId');
  }

  @override
  void writeEvents(String lessonLocalId, String encoded) {
    _prefs.setString('$_eventsKeyPrefix$lessonLocalId', encoded);
  }

  List<String> readIndex() {
    final raw = _prefs.getStringList(indexKey);
    return raw ?? const [];
  }

  void _updateIndex(String lessonLocalId) {
    final ids = readIndex().toSet()..add(lessonLocalId);
    _prefs.setStringList(indexKey, ids.toList());
  }
}
