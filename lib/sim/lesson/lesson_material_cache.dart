// MIRROR OF: src/cyber/lesson-material-cache.ts (Web, source of truth)
import 'lesson_models.dart';

class _CacheEntry {
  const _CacheEntry({required this.lesson, required this.savedAt});

  final CompleteLesson lesson;
  final int savedAt;
}

class LessonMaterialCache {
  LessonMaterialCache({
    this.maxLessons = 3,
    this.ttlMs = 24 * 60 * 60 * 1000,
  });

  final int maxLessons;
  final int ttlMs;
  final Map<String, _CacheEntry> _memory = {};

  CompleteLesson? peek(String key) {
    final entry = _memory[key];
    if (entry == null) return null;
    if (_isExpired(entry)) {
      _memory.remove(key);
      return null;
    }
    return entry.lesson;
  }

  CompleteLesson? get(String key) {
    final entry = _memory.remove(key);
    if (entry == null) return null;
    if (_isExpired(entry)) return null;
    _memory[key] = entry;
    return entry.lesson;
  }

  void put(String key, CompleteLesson lesson) {
    _memory.removeWhere((_, entry) => _isExpired(entry));
    _memory.remove(key);
    _memory[key] = _CacheEntry(
      lesson: lesson,
      savedAt: DateTime.now().millisecondsSinceEpoch,
    );
    while (_memory.length > maxLessons) {
      _memory.remove(_memory.keys.first);
    }
  }

  bool _isExpired(_CacheEntry entry) {
    return DateTime.now().millisecondsSinceEpoch - entry.savedAt > ttlMs;
  }
}
