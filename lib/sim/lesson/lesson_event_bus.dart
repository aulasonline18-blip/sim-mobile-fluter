// MIRROR OF: src/cyber/lesson-event-bus.ts (Web, source of truth)
import 'lesson_models.dart';

typedef LessonListener = void Function(CompleteLesson lesson);

class LessonEventBus {
  final Map<String, Set<LessonListener>> _subscribers = {};

  void Function() subscribe(String key, LessonListener listener) {
    final set = _subscribers.putIfAbsent(key, () => <LessonListener>{});
    set.add(listener);
    return () {
      set.remove(listener);
      if (set.isEmpty) _subscribers.remove(key);
    };
  }

  void notify(String key, CompleteLesson lesson) {
    final set = _subscribers[key];
    if (set == null) return;
    for (final listener in List<LessonListener>.from(set)) {
      try {
        listener(lesson);
      } catch (_) {
        // isolate listener failures so other subscribers still receive the event
      }
    }
  }
}
