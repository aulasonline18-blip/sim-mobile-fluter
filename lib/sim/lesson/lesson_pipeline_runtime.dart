// MIRROR OF: src/cyber/lesson-pipeline-runtime.ts (Web, source of truth)
// Part III.4: runImageSequential + runBackgroundText queues
// D2.2: ensureFirstLessonPrepared + ensureLessonWindow (janela de 3 aulas)
import 'dart:async';

import 'lesson_material_cache.dart';
import 'lesson_models.dart';
import 'lesson_orchestrator.dart';

/// Sequential image queue — runs at most one image fetch at a time.
/// Dart translation of Web's runImageSequential (Planta-Mãe III.4).
class ImageSequentialQueue {
  Future<void> _chain = Future.value();

  Future<T> run<T>(Future<T> Function() fn) {
    final next = _chain.then((_) => fn());
    _chain = next.then((_) {}).catchError((_) {});
    return next;
  }
}

/// Background text semaphore — allows at most 2 concurrent background fetches.
/// Dart translation of Web's runBackgroundText (Planta-Mãe III.4).
class BackgroundTextSemaphore {
  static const int _maxConcurrent = 2;

  int _active = 0;
  final List<Completer<void>> _waiters = [];

  Future<T> run<T>(Future<T> Function() fn) async {
    if (_active >= _maxConcurrent) {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future;
    }
    _active++;
    try {
      return await fn();
    } finally {
      _active--;
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      }
    }
  }
}

// ── D2.2 ─────────────────────────────────────────────────────────────────────

/// Garante que o material da primeira aula está pronto antes de abrir a sala.
/// Mirror de ensureFirstLessonPrepared (src/cyber/lesson-pipeline-runtime.ts).
Future<CompleteLesson?> ensureFirstLessonPrepared({
  required LessonOrchestrator orchestrator,
  required LessonMaterialCache cache,
  required CompleteLessonParams params,
}) async {
  final key = lessonKeyFor(params);
  final cached = cache.peek(key);
  if (cached != null) return cached;
  try {
    return await orchestrator.prefetchCompleteLesson(params, priority: 'active');
  } catch (_) {
    return null;
  }
}

/// Mantém janela de N aulas pré-carregadas (lei: 3 aulas constante).
/// Mirror de ensureLessonWindow (src/cyber/lesson-pipeline-runtime.ts).
Future<void> ensureLessonWindow({
  required LessonOrchestrator orchestrator,
  required LessonMaterialCache cache,
  required List<CompleteLessonParams> window,
  int maxSlots = 3,
}) async {
  final needed = window.take(maxSlots).toList();
  await Future.wait(
    needed.map((params) async {
      final key = lessonKeyFor(params);
      if (cache.peek(key) != null) return;
      try {
        await orchestrator.prefetchCompleteLesson(params, priority: 'background');
      } catch (_) {
        // best-effort: erros individuais não bloqueiam a janela
      }
    }),
    eagerError: false,
  );
}
