import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';
import 'placement_blocks.dart';
import 'placement_state.dart';

class StudentPlacementService {
  StudentPlacementService({
    required this.stateService,
    required this.lessonLocalId,
  });

  final StudentLearningStateService stateService;
  final String lessonLocalId;

  PlacementState read() {
    final state = stateService.read(lessonLocalId);
    if (state?.placement != null) {
      return PlacementState.fromJson(state!.placement!);
    }
    return _fromLegacyProfile(state?.profile.toJson());
  }

  PlacementState update(PlacementState patch) {
    return _writePlacementPatch(patch, 'PLACEMENT_UPDATED');
  }

  PlacementState reset() {
    return _writePlacementPatch(PlacementState.empty(), 'PLACEMENT_RESET');
  }

  String? readStartMarker() => read().startMarker;

  PlacementState _writePlacementPatch(
    PlacementState patch,
    String eventType,
  ) {
    late PlacementState next;
    stateService.mutate(lessonLocalId, (state) {
      final current = state.placement == null
          ? _fromLegacyProfile(state.profile.toJson())
          : PlacementState.fromJson(state.placement!);
      next = _merge(current, patch).copyWith(
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      return state.copyWith(
        placement: next.toJson(),
        profile: _mirrorLegacyProfileFields(state.profile, next),
        events: [
          ...state.events,
          StudentLearningEvent(
            type: eventType,
            ts: DateTime.now().millisecondsSinceEpoch,
            payload: {
              'status': next.status.name,
              'index': next.index,
              'answers': next.answers.length,
              'start_marker': next.startMarker,
              'source': next.source,
              'limited': next.limited,
            },
          ),
        ],
      );
    });
    return next;
  }

  PlacementState _merge(PlacementState current, PlacementState patch) {
    return current.copyWith(
      status: patch.status,
      blocks: patch.blocks,
      answers: patch.answers,
      result: patch.result,
      startMarker: patch.startMarker,
      index: patch.index,
      source: patch.source,
      limited: patch.limited,
      startedAt: patch.startedAt,
      finishedAt: patch.finishedAt,
      clearResult: patch.result == null &&
          (patch.status == PlacementStatus.running ||
              patch.status == PlacementStatus.idle),
      clearStartMarker: patch.startMarker == null &&
          (patch.status == PlacementStatus.running ||
              patch.status == PlacementStatus.idle ||
              patch.status == PlacementStatus.skipped),
    );
  }

  PlacementState _fromLegacyProfile(JsonMap? profile) {
    final base = PlacementState.empty();
    if (profile == null) return base;
    final blocks = profile['pretest_blocks'];
    final answers = profile['pretest_answers'];
    final result = profile['pretest_result'];
    return PlacementState(
      status: PlacementStatus.values.firstWhere(
        (status) => status.name == profile['pretest_status'],
        orElse: () => base.status,
      ),
      blocks: blocks is List
          ? blocks
              .whereType<Map>()
              .map((block) => PlacementBlock.fromJson(JsonMap.from(block)))
              .toList()
          : base.blocks,
      answers: answers is List
          ? answers
              .whereType<Map>()
              .map((answer) => PlacementAnswer.fromJson(JsonMap.from(answer)))
              .toList()
          : base.answers,
      result: result is Map ? PlacementResult.fromJson(JsonMap.from(result)) : null,
      startMarker: profile['start_marker'] as String?,
      index: (profile['pretest_index'] as num?)?.toInt() ?? base.index,
      source: profile['pretest_source'] as String?,
      limited: profile['pretest_limited'] == true,
      startedAt: (profile['pretest_started_at'] as num?)?.toInt(),
      finishedAt: (profile['pretest_finished_at'] as num?)?.toInt(),
      updatedAt: null,
    );
  }

  StudentProfile _mirrorLegacyProfileFields(
    StudentProfile profile,
    PlacementState placement,
  ) {
    return profile.copyWith(
      extra: {
        ...profile.extra,
        'pretest_status': placement.status.name,
        'pretest_blocks': placement.blocks.map((block) => block.toJson()).toList(),
        'pretest_answers':
            placement.answers.map((answer) => answer.toJson()).toList(),
        'pretest_result': placement.result?.toJson(),
        'start_marker': placement.startMarker,
        'pretest_index': placement.index,
        'pretest_source': placement.source,
        'pretest_limited': placement.limited,
        'pretest_started_at': placement.startedAt,
        'pretest_finished_at': placement.finishedAt,
      },
    );
  }
}
