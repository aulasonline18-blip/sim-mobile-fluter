import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';

typedef ReadyWindowWorkerProcessor = Future<List<bool>> Function({
  required String lessonLocalId,
  required String source,
  int? maxSlots,
  bool returnMode,
  int? itemIdx,
  LessonLayer? layer,
  String? marker,
  String? topic,
});

class ReadyWindowWorker {
  ReadyWindowWorker({
    required this.service,
    required this.processor,
  });

  final StudentLearningStateService service;
  final ReadyWindowWorkerProcessor processor;
  final Set<String> _inflight = {};

  Future<List<bool>> drainReadyWindowJobs(String lessonLocalId) async {
    if (_inflight.contains(lessonLocalId)) return const [];
    _inflight.add(lessonLocalId);
    final all = <bool>[];
    try {
      while (true) {
        final state = service.read(lessonLocalId);
        final jobs = List<JsonMap>.from(state?.queuedActions ?? const []);
        final job = _eligibleJob(jobs);
        if (state == null || job == null) break;
        final jobId = job['job_id'];
        service.mutate(lessonLocalId, (current) {
          return current.copyWith(
            queuedActions: current.queuedActions.map((cur) {
              if (cur['job_id'] != jobId) return cur;
              return {
                ...cur,
                'status': 'running',
                'started_at': DateTime.now().millisecondsSinceEpoch,
                'error': null,
              };
            }).toList(),
          );
        });

        try {
          final payload = JsonMap.from(job['payload'] as Map? ?? const {});
          final result = await processor(
            lessonLocalId: lessonLocalId,
            source: 'job:${job['source']}',
            maxSlots: payload['maxSlots'] as int?,
            returnMode: payload['returnMode'] == true,
            itemIdx: (payload['itemIdx'] as num?)?.toInt(),
            layer: LessonLayerValue.fromValue(payload['layer']),
            marker: payload['marker'] as String?,
            topic: payload['topic'] as String?,
          );
          all.addAll(result);
          service.mutate(lessonLocalId, (current) {
            return current.copyWith(
              queuedActions: current.queuedActions.map((cur) {
                if (cur['job_id'] != jobId) return cur;
                return {
                  ...cur,
                  'status': 'done',
                  'finished_at': DateTime.now().millisecondsSinceEpoch,
                  'error': null,
                };
              }).toList(),
            );
          });
        } catch (error) {
          service.mutate(lessonLocalId, (current) {
            return current.copyWith(
              queuedActions: current.queuedActions.map((cur) {
                if (cur['job_id'] != jobId) return cur;
                return {
                  ...cur,
                  'status': 'failed',
                  'finished_at': DateTime.now().millisecondsSinceEpoch,
                  'error': error.toString(),
                };
              }).toList(),
            );
          });
          break;
        }
      }
      return all;
    } finally {
      _inflight.remove(lessonLocalId);
    }
  }

  JsonMap? _eligibleJob(List<JsonMap> jobs) {
    final queued = jobs
        .where((job) =>
            job['type'] == 'PREPARE_READY_WINDOW' &&
            job['status'] == 'queued')
        .toList();
    queued.sort((a, b) {
      final ap = a['priority'] == 'active' ? 0 : 1;
      final bp = b['priority'] == 'active' ? 0 : 1;
      if (ap != bp) return ap.compareTo(bp);
      return ((a['created_at'] as num?)?.toInt() ?? 0)
          .compareTo((b['created_at'] as num?)?.toInt() ?? 0);
    });
    return queued.isEmpty ? null : queued.first;
  }
}
