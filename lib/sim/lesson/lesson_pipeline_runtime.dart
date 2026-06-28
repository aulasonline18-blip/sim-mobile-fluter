// MIRROR OF: src/cyber/lesson-orchestrator.ts (two-queue runtime, Web source of truth)
// Part III.4: runImageSequential + runBackgroundText queues
import 'dart:async';

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
