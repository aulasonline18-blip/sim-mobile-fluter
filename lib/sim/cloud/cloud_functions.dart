import '../state/student_learning_state.dart';
import 'supabase_client_contract.dart';

class PersistStudentStateInput {
  const PersistStudentStateInput({
    required this.lessonLocalId,
    required this.state,
    required this.clientUpdatedAt,
    required this.clientScore,
    this.schemaVersion = 1,
  });

  final String lessonLocalId;
  final StudentLearningState state;
  final int clientUpdatedAt;
  final int clientScore;
  final int schemaVersion;

  JsonMap toJson() => {
        'lessonLocalId': lessonLocalId,
        'state': state.toJson(),
        'clientUpdatedAt': clientUpdatedAt,
        'clientScore': clientScore,
        'schemaVersion': schemaVersion,
      };
}

class PersistStudentStateResult {
  const PersistStudentStateResult.accepted({
    required this.lessonLocalId,
    required this.highWaterMark,
    required this.schemaVersion,
    this.updatedAt,
  })  : rejected = false,
        remoteState = null,
        remoteHighWaterMark = null,
        remoteUpdatedAt = null;

  const PersistStudentStateResult.rejectedRegression({
    required this.remoteState,
    required this.remoteHighWaterMark,
    this.remoteUpdatedAt,
  })  : rejected = true,
        lessonLocalId = '',
        highWaterMark = 0,
        schemaVersion = 1,
        updatedAt = null;

  final bool rejected;
  final String lessonLocalId;
  final int highWaterMark;
  final int schemaVersion;
  final String? updatedAt;
  final StudentLearningState? remoteState;
  final int? remoteHighWaterMark;
  final String? remoteUpdatedAt;
}

class StudentStateRow {
  const StudentStateRow({
    required this.lessonLocalId,
    required this.state,
    required this.highWaterMark,
    required this.schemaVersion,
    this.updatedAt,
  });

  final String lessonLocalId;
  final StudentLearningState? state;
  final int highWaterMark;
  final int schemaVersion;
  final String? updatedAt;
}

class StudentStateSummaryRow {
  const StudentStateSummaryRow({
    required this.lessonLocalId,
    required this.tema,
    required this.idioma,
    required this.nivel,
    required this.totalItens,
    required this.itemIdx,
    required this.layer,
    required this.concluidos,
    required this.finalizada,
    required this.deleted,
    this.lessonCloudId,
    this.createdAt,
    this.updatedAt,
    this.markerAtual,
  });

  final String lessonLocalId;
  final String? lessonCloudId;
  final String tema;
  final String idioma;
  final String nivel;
  final String? createdAt;
  final String? updatedAt;
  final int totalItens;
  final int itemIdx;
  final int layer;
  final int concluidos;
  final bool finalizada;
  final String? markerAtual;
  final bool deleted;
}

abstract interface class StudentStateCloudFunctions {
  Future<PersistStudentStateResult> persistStudentState(
    PersistStudentStateInput input,
    SupabaseSession session,
  );

  Future<List<StudentStateRow>> listStudentStates(SupabaseSession session);

  Future<List<StudentStateSummaryRow>> listStudentStateSummaries(
    SupabaseSession session,
  );

  Future<StudentStateRow?> getStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  );

  Future<void> deleteStudentStateByLesson(
    String lessonLocalId,
    SupabaseSession session,
  );
}

int scoreOfStudentLearningState(StudentLearningState? state) {
  if (state == null) return -1;
  final progress = state.progress;
  final current = state.current;
  final curriculumSize = state.curriculum?.items.length ?? 0;
  final attempts = state.attempts.length;
  final eventCount = state.events.length;
  final reviewCount = _auxQueueCount(state.auxRooms, 'review');
  final recoveryCount = _auxQueueCount(state.auxRooms, 'recovery');
  final highWater = (state.extra['highWaterMark'] as num?)?.toInt();
  final progressScore = progress == null
      ? 0
      : progress.mainAdvances * 100000 +
          progress.itemIdx * 1000 +
          progress.layer.value * 100 +
          progress.concluidos.length * 50;
  final currentScore =
      current == null ? 0 : current.itemIdx * 1000 + current.layer.value * 100;
  return [
        highWater ?? 0,
        progressScore,
        currentScore,
      ].reduce((a, b) => a > b ? a : b) +
      curriculumSize * 10 +
      attempts * 5 +
      eventCount +
      reviewCount * 2 +
      recoveryCount * 3;
}

int _auxQueueCount(JsonMap? auxRooms, String key) {
  if (auxRooms == null) return 0;
  final room = auxRooms[key];
  if (room is Map) {
    final entries = room['entries'];
    if (entries is List) return entries.length;
    final queue = room['queue'];
    if (queue is List) return queue.length;
    final pending = room['pendingMap'];
    if (pending is Map) return pending.length;
  }
  final queue = auxRooms['${key}_queue'];
  if (queue is List) return queue.length;
  return 0;
}

StudentStateSummaryRow? summarizeStudentStateRow(StudentStateRow row) {
  final state = row.state;
  if (state == null) return null;
  final profile = state.profile;
  final curriculum = state.curriculum;
  final progress = state.progress;
  final current = state.current;
  final itemIdx = progress?.itemIdx ?? current?.itemIdx ?? 0;
  final items = curriculum?.items ?? const <CurriculumItem>[];
  final deleted = state.extra['deletedAt'] != null ||
      (state.extra['syncInfo'] is Map &&
          (state.extra['syncInfo'] as Map)['deletedAt'] != null);
  return StudentStateSummaryRow(
    lessonLocalId: row.lessonLocalId,
    lessonCloudId: state.lessonCloudId,
    tema: profile.objetivo ?? curriculum?.topic ?? 'Aula SIM',
    idioma: profile.language ?? profile.stableLang ?? '',
    nivel: profile.nivel ?? profile.academicLevel ?? 'incerto',
    createdAt: state.createdAt > 0
        ? DateTime.fromMillisecondsSinceEpoch(state.createdAt).toIso8601String()
        : null,
    updatedAt: row.updatedAt ??
        (state.updatedAt > 0
            ? DateTime.fromMillisecondsSinceEpoch(state.updatedAt)
                .toIso8601String()
            : null),
    totalItens: items.length > (progress?.totalItems ?? 0)
        ? items.length
        : progress?.totalItems ?? 0,
    itemIdx: itemIdx < 0 ? 0 : itemIdx,
    layer: progress?.layer.value ?? current?.layer.value ?? 1,
    concluidos: [
      progress?.mainAdvances ?? 0,
      progress?.concluidos.length ?? 0,
    ].reduce((a, b) => a > b ? a : b),
    finalizada: state.extra['finalizada'] == true,
    markerAtual: current?.marker ??
        (itemIdx >= 0 && itemIdx < items.length ? items[itemIdx].marker : null),
    deleted: deleted,
  );
}
