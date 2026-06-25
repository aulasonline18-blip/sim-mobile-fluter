import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'student_learning_state.dart';

abstract class StudentLearningStatePersistence {
  Future<StudentLearningState?> read(String lessonLocalId);
  Future<List<StudentLearningState>> readAll();
  Future<void> write(StudentLearningState state);
  Future<void> delete(String lessonLocalId);
}

class SharedPreferencesStudentLearningStatePersistence
    implements StudentLearningStatePersistence {
  SharedPreferencesStudentLearningStatePersistence(this._prefs);

  static const String _idsKey = 'sim.student_learning_state.ids.v1';
  static const String _keyPrefix = 'sim.student_learning_state.v1.';

  final SharedPreferences _prefs;

  static Future<SharedPreferencesStudentLearningStatePersistence>
      create() async {
    final prefs = await SharedPreferences.getInstance();
    return SharedPreferencesStudentLearningStatePersistence(prefs);
  }

  @override
  Future<StudentLearningState?> read(String lessonLocalId) async {
    final raw = _prefs.getString(_keyFor(lessonLocalId));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return StudentLearningState.fromJson(JsonMap.from(decoded));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<StudentLearningState>> readAll() async {
    final ids = _prefs.getStringList(_idsKey) ?? const <String>[];
    final states = <StudentLearningState>[];
    for (final id in ids) {
      final state = await read(id);
      if (state != null) states.add(state);
    }
    return states;
  }

  @override
  Future<void> write(StudentLearningState state) async {
    final ids = _prefs.getStringList(_idsKey) ?? <String>[];
    if (!ids.contains(state.lessonLocalId)) {
      await _prefs.setStringList(_idsKey, [...ids, state.lessonLocalId]);
    }
    await _prefs.setString(
      _keyFor(state.lessonLocalId),
      jsonEncode(state.toJson()),
    );
  }

  @override
  Future<void> delete(String lessonLocalId) async {
    final ids = _prefs.getStringList(_idsKey) ?? <String>[];
    await _prefs.setStringList(
      _idsKey,
      ids.where((id) => id != lessonLocalId).toList(growable: false),
    );
    await _prefs.remove(_keyFor(lessonLocalId));
  }

  String _keyFor(String lessonLocalId) => '$_keyPrefix$lessonLocalId';
}
