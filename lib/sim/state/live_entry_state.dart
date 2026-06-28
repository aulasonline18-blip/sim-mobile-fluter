import 'student_learning_state.dart';
import 'student_learning_state_service.dart';

const _statusRank = <LiveEntryStatus, int>{
  LiveEntryStatus.idle: 0,
  LiveEntryStatus.pedidoRecebido: 1,
  LiveEntryStatus.t00Running: 2,
  LiveEntryStatus.firstItemReady: 3,
  LiveEntryStatus.t02FirstLessonRunning: 4,
  LiveEntryStatus.firstLessonReady: 5,
  LiveEntryStatus.showingFirstLesson: 6,
  LiveEntryStatus.failedT00: 20,
  LiveEntryStatus.failedT02: 21,
  LiveEntryStatus.blockedCredits: 22,
};

bool shouldKeepCurrentEntryStatus(
  LiveEntryStatus current,
  LiveEntryStatus next,
) {
  if (current == next) return false;
  if (current == LiveEntryStatus.firstLessonReady &&
      next == LiveEntryStatus.t02FirstLessonRunning) {
    return true;
  }
  if (current == LiveEntryStatus.showingFirstLesson &&
      next != LiveEntryStatus.failedT00 &&
      next != LiveEntryStatus.failedT02 &&
      next != LiveEntryStatus.blockedCredits) {
    return true;
  }
  final currentRank = _statusRank[current] ?? 0;
  final nextRank = _statusRank[next] ?? 0;
  return currentRank > nextRank && currentRank < 20;
}

LiveEntry readLiveEntryState(
  StudentLearningStateService service,
  String lessonLocalId,
) {
  return service.read(lessonLocalId)?.entry ?? LiveEntry.empty();
}

LiveEntry updateLiveEntryState(
  StudentLearningStateService service,
  String lessonLocalId, {
  required LiveEntryStatus status,
  String? error,
  String? firstItemMarker,
  String? firstLessonMaterialKey,
  int? firstLessonStartedAt,
  int? firstLessonReadyAt,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  late LiveEntry next;
  service.mutate(lessonLocalId, (state) {
    final current = state.entry ?? LiveEntry.empty(now);
    final chosenStatus = shouldKeepCurrentEntryStatus(current.status, status)
        ? current.status
        : status;
    next = current.copyWith(
      status: chosenStatus,
      error: error,
      firstItemMarker: firstItemMarker,
      firstLessonMaterialKey: firstLessonMaterialKey,
      firstLessonStartedAt: firstLessonStartedAt,
      firstLessonReadyAt: firstLessonReadyAt,
      updatedAt: now,
    );
    final event = StudentLearningEvent(
      type: 'PROGRESS_UPDATED',
      ts: now,
      payload: {
        'source': 'studentLiveEntryState',
        'entry_status': next.status.name,
        'first_item_marker': next.firstItemMarker,
        'first_lesson_material_key': next.firstLessonMaterialKey,
      },
    );
    return state.copyWith(entry: next, events: [...state.events, event]);
  });
  return next;
}

String preparedLessonMaterialKey(
  int itemIdx,
  String? marker,
  LessonLayer layer,
) {
  return '${marker ?? ''}::L${layer.value}::${layer.name}';
}

String firstLessonMaterialKey(String? marker) {
  return preparedLessonMaterialKey(0, marker, LessonLayer.l1);
}

String entryLessonMaterialKey(
  int itemIdx,
  String? marker, [
  LessonLayer layer = LessonLayer.l1,
]) {
  return preparedLessonMaterialKey(itemIdx, marker, layer);
}
