// MIRROR OF: src/core/S04_SignalTracker.ts (Web, source of truth)
// Fachada read-only — deriva sinais de StudentLearningStateService.
// Quem escreve é o executor via appendAttempt. Não há recordSignal aqui.
import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';

class SignalRecord {
  const SignalRecord({
    required this.itemId,
    required this.s1,
    required this.s2,
    required this.s3,
    required this.total,
  });

  final String itemId;
  final int s1;
  final int s2;
  final int s3;
  final int total;

  Map<String, int> toJson() =>
      {'s1': s1, 's2': s2, 's3': s3, 'total': total};
}

class SignalDistribution {
  const SignalDistribution({
    required this.s1,
    required this.s2,
    required this.s3,
    required this.total,
  });

  final int s1;
  final int s2;
  final int s3;
  final int total;
}

class SignalTracker {
  SignalTracker(this._service);

  final StudentLearningStateService _service;

  /// Retorna o estado com updatedAt mais recente (estado "ativo").
  StudentLearningState? _getActive() {
    final ids = _service.listLessonIds();
    if (ids.isEmpty) return null;
    StudentLearningState? best;
    for (final id in ids) {
      final s = _service.read(id);
      if (s == null) continue;
      if (best == null || s.updatedAt > best.updatedAt) best = s;
    }
    return best;
  }

  /// Todos os sinais derivados de state.attempts da aula ativa.
  List<SignalRecord> getAll() {
    final state = _getActive();
    if (state == null) return const [];
    return _buildRecords(state.attempts);
  }

  /// Sinais de um item específico.
  SignalRecord? getByItem(String itemId) {
    final state = _getActive();
    if (state == null) return null;
    final relevant =
        state.attempts.where((a) => a.marker == itemId).toList();
    if (relevant.isEmpty) return null;
    return _buildRecord(itemId, relevant);
  }

  /// Distribuição agregada: {s1, s2, s3, total} — usada pelo Painel do Pai.
  SignalDistribution distribution() {
    final records = getAll();
    var s1 = 0, s2 = 0, s3 = 0;
    for (final r in records) {
      s1 += r.s1;
      s2 += r.s2;
      s3 += r.s3;
    }
    return SignalDistribution(s1: s1, s2: s2, s3: s3, total: s1 + s2 + s3);
  }

  static List<SignalRecord> _buildRecords(List<LessonAttempt> attempts) {
    final byItem = <String, List<LessonAttempt>>{};
    for (final a in attempts) {
      (byItem[a.marker] ??= []).add(a);
    }
    return byItem.entries
        .map((e) => _buildRecord(e.key, e.value))
        .toList();
  }

  static SignalRecord _buildRecord(
      String itemId, List<LessonAttempt> attempts) {
    var s1 = 0, s2 = 0, s3 = 0;
    for (final a in attempts) {
      switch (a.sinal) {
        case DecisionSignal.one:
          s1++;
        case DecisionSignal.two:
          s2++;
        case DecisionSignal.three:
          s3++;
      }
    }
    return SignalRecord(
        itemId: itemId, s1: s1, s2: s2, s3: s3, total: s1 + s2 + s3);
  }
}
