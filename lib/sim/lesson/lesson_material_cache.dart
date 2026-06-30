// MIRROR OF: src/cyber/lesson-material-cache.ts (Web, source of truth)
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'lesson_content_validator.dart';
import 'lesson_models.dart';

const String _kCacheKey = 'sim-lesson-text-cache-v1';
const int _kMaxMemoryLessons = 3;
const int _kLessonTtlMs = 86400000; // 24h

class _CacheEntry {
  const _CacheEntry({required this.lesson, required this.savedAt});

  final CompleteLesson lesson;
  final int savedAt;
}

class LessonMaterialCache {
  LessonMaterialCache({int? maxLessons, int? ttlMs})
    : maxLessons = maxLessons ?? _kMaxMemoryLessons,
      ttlMs = ttlMs ?? _kLessonTtlMs;

  final int maxLessons;
  final int ttlMs;
  final Map<String, _CacheEntry> _memory = {};

  // Deve ser chamado no boot antes de usar o cache.
  // Lê sim-lesson-text-cache-v1, descarta entradas expiradas, popula _memory.
  Future<void> hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      hydrateFromPreferences(prefs);
    } catch (_) {}
  }

  void hydrateFromPreferences(SharedPreferences prefs) {
    final raw = prefs.getString(_kCacheKey);
    if (raw == null || raw.trim().isEmpty) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return;
    }
    if (decoded is! Map) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final entry in decoded.entries) {
      final key = entry.key as String;
      final value = entry.value;
      if (value is! Map) continue;
      final savedAt = (value['savedAt'] as num?)?.toInt() ?? 0;
      if (now - savedAt > ttlMs) continue;
      final lessonRaw = value['lesson'];
      if (lessonRaw is! Map) continue;
      final lesson = _lessonFromJson(Map<String, dynamic>.from(lessonRaw));
      if (lesson == null) continue;
      _memory[key] = _CacheEntry(lesson: lesson, savedAt: savedAt);
    }
    while (_memory.length > maxLessons) {
      _memory.remove(_memory.keys.first);
    }
  }

  // Peek sem promover LRU — não altera ordem de evicção.
  CompleteLesson? peek(String key) {
    final entry = _memory[key];
    if (entry == null) return null;
    if (_isExpired(entry)) {
      _memory.remove(key);
      return null;
    }
    return entry.lesson;
  }

  CompleteLesson? peekCachedLesson(String key) => peek(key);

  // get promove LRU (remove e reinserida no final).
  CompleteLesson? get(String key) {
    final entry = _memory.remove(key);
    if (entry == null) return null;
    if (_isExpired(entry)) return null;
    _memory[key] = entry;
    return entry.lesson;
  }

  Future<CompleteLesson?> getCachedLesson(String key) async => get(key);

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
    _persist();
  }

  // Persiste _memory em SharedPreferences, strip de imagem para manter leve.
  void _persist() {
    unawaited(
      Future(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final payload = <String, dynamic>{};
          for (final entry in _memory.entries) {
            payload[entry.key] = {
              'savedAt': entry.value.savedAt,
              'lesson': _lessonToJsonNoImage(entry.value.lesson),
            };
          }
          await prefs.setString(_kCacheKey, jsonEncode(payload));
        } catch (_) {}
      }),
    );
  }

  bool _isExpired(_CacheEntry entry) {
    return DateTime.now().millisecondsSinceEpoch - entry.savedAt > ttlMs;
  }

  static Map<String, dynamic> _lessonToJsonNoImage(CompleteLesson lesson) {
    return {
      'conteudo': lesson.conteudo.toJson(),
      'imagem': null,
      'audioText': lesson.audioText,
    };
  }

  static CompleteLesson? _lessonFromJson(Map<String, dynamic> json) {
    try {
      final conteudoRaw = json['conteudo'];
      if (conteudoRaw is! Map) return null;
      final conteudo = _lessonContentFromJson(
        Map<String, dynamic>.from(conteudoRaw),
      );
      if (conteudo == null) return null;
      return CompleteLesson(
        conteudo: conteudo,
        imagem: null,
        audioText: json['audioText'] as String? ?? conteudo.audioText,
      );
    } catch (_) {
      return null;
    }
  }

  static LessonContent? _lessonContentFromJson(Map<String, dynamic> json) {
    try {
      return validatedLessonContentFromJson(json);
    } catch (_) {
      return null;
    }
  }
}
