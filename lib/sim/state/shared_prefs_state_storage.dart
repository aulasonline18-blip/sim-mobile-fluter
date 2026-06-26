import 'package:shared_preferences/shared_preferences.dart';

import 'student_state_store.dart';

class SharedPrefsStudentStateLocalStorage implements StudentStateLocalStorage {
  SharedPrefsStudentStateLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String statePrefix = 'sim-state-v1-';
  static const String eventsPrefix = 'sim-events-v1-';

  @override
  String? readState(String lessonLocalId) {
    return _prefs.getString('$statePrefix$lessonLocalId');
  }

  @override
  void writeState(String lessonLocalId, String encoded) {
    _prefs.setString('$statePrefix$lessonLocalId', encoded);
  }

  @override
  String? readEvents(String lessonLocalId) {
    return _prefs.getString('$eventsPrefix$lessonLocalId');
  }

  @override
  void writeEvents(String lessonLocalId, String encoded) {
    _prefs.setString('$eventsPrefix$lessonLocalId', encoded);
  }
}
