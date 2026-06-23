import 'cloud_queue.dart';

class StudentLearningSync {
  const StudentLearningSync(this.queue);

  final CloudQueue queue;

  void enqueue({
    required String lessonLocalId,
    required StudentLearningSyncOperation operation,
  }) {
    queue.enqueueStudentStateSync(
      lessonLocalId: lessonLocalId,
      operation: operation,
    );
  }

  void enqueuePatch(String lessonLocalId) {
    queue.enqueueStudentStateSync(lessonLocalId: lessonLocalId);
  }

  void enqueueTombstone(String lessonLocalId) {
    queue.enqueueStudentStateSync(
      lessonLocalId: lessonLocalId,
      operation: StudentLearningSyncOperation.tombstone,
    );
  }

  Future<void> drain() => queue.drainQueue();

  void wireLifecycle() => queue.wireCloudQueueLifecycle();

  Map<String, CloudQueueEntry> debugSnapshot() => queue.getQueueSnapshot();
}
