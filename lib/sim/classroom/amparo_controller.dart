import '../state/student_learning_state.dart';

class AmparoController {
  const AmparoController();

  static const int amparoThreshold = 3;

  StudentLearningState applyIfNeeded({
    required StudentLearningState state,
    required bool correct,
    required int ts,
  }) {
    if (correct) return state;
    final progress = state.progress;
    if (progress == null) return state;
    if (progress.erros < amparoThreshold) return state;

    final curriculum = state.curriculum;
    final idx = progress.itemIdx;
    final marker = curriculum != null && idx >= 0 && idx < curriculum.items.length
        ? curriculum.items[idx].marker
        : '';
    final newAmparoLvl = (progress.amparoLvl + 1).clamp(1, 3);
    final event = StudentLearningEvent(
      type: 'AMPARO_TRIGGERED',
      ts: ts,
      payload: {
        'marker': marker,
        'layer': progress.layer.value,
        'amparoLvl': newAmparoLvl,
        'errosAtTrigger': progress.erros,
      },
    );
    return state.copyWith(
      progress: progress.copyWith(
        amparoLvl: newAmparoLvl,
        erros: 0,
      ),
      events: [...state.events, event],
    );
  }
}
