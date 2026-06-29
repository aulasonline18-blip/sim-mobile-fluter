// MIRROR OF: src/core/S04_SignalTracker.ts (Web, source of truth)
import '../state/student_learning_state.dart';

class SignalTracker {
  final Map<String, int> _counts = {};

  String _key(String marker, LessonLayer layer, DecisionSignal sinal) =>
      '$marker|${layer.value}|${sinal.value}';

  void recordSignal({
    required String marker,
    required LessonLayer layer,
    required DecisionSignal sinal,
  }) {
    final key = _key(marker, layer, sinal);
    _counts[key] = (_counts[key] ?? 0) + 1;
  }

  int getSignalCount({
    required String marker,
    required LessonLayer layer,
    required DecisionSignal sinal,
  }) {
    return _counts[_key(marker, layer, sinal)] ?? 0;
  }

  void reset() {
    _counts.clear();
  }
}
