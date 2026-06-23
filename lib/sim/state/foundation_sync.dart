import 'student_learning_state.dart';
import 'student_state_store.dart';

enum FoundationSyncStatus { pending, synced, failed }

class FoundationSyncRecorder {
  const FoundationSyncRecorder({required this.store});

  final StudentStateStore store;

  CanonicalLearningEvent recordPending({
    required String lessonLocalId,
    required String direction,
    String source = 'foundation-sync-recorder',
  }) {
    return _record(
      lessonLocalId: lessonLocalId,
      type: 'SYNC_STARTED',
      status: FoundationSyncStatus.pending,
      direction: direction,
      source: source,
    );
  }

  CanonicalLearningEvent recordCompleted({
    required String lessonLocalId,
    required String direction,
    String source = 'foundation-sync-recorder',
  }) {
    return _record(
      lessonLocalId: lessonLocalId,
      type: 'SYNC_COMPLETED',
      status: FoundationSyncStatus.synced,
      direction: direction,
      source: source,
    );
  }

  CanonicalLearningEvent recordFailed({
    required String lessonLocalId,
    required String direction,
    required String message,
    String source = 'foundation-sync-recorder',
  }) {
    return _record(
      lessonLocalId: lessonLocalId,
      type: 'SYNC_FAILED',
      status: FoundationSyncStatus.failed,
      direction: direction,
      source: source,
      error: message,
    );
  }

  CanonicalLearningEvent _record({
    required String lessonLocalId,
    required String type,
    required FoundationSyncStatus status,
    required String direction,
    required String source,
    String? error,
  }) {
    final payload = <String, dynamic>{
      'status': status.name,
      'direction': direction,
    };
    if (error != null) payload['error'] = error;
    return store.mutateWithEvent(
      lessonLocalId: lessonLocalId,
      type: type,
      source: source,
      payload: payload,
      mutate: (state, event) {
        final sync = state.extra['sync'] is Map
            ? JsonMap.from(state.extra['sync'] as Map)
            : <String, dynamic>{};
        final nextSync = <String, dynamic>{
          ...sync,
          'status': status.name,
          'direction': direction,
          'updated_at': event.createdAt,
          'event_id': event.eventId,
        };
        if (error != null) nextSync['error'] = error;
        return state.copyWith(extra: {...state.extra, 'sync': nextSync});
      },
    );
  }
}
