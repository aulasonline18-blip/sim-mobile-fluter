import 'placement_blocks.dart';
import 'placement_state.dart';
import 'student_placement_service.dart';

class PlacementStoreState {
  const PlacementStoreState({
    this.pretestStatus,
    this.pretestBlocks,
    this.pretestAnswers,
    this.pretestResult,
    this.startMarker,
    this.pretestIndex,
    this.pretestSource,
    this.pretestLimited,
    this.pretestStartedAt,
    this.pretestFinishedAt,
  });

  final PlacementStatus? pretestStatus;
  final List<PlacementBlock>? pretestBlocks;
  final List<PlacementAnswer>? pretestAnswers;
  final PlacementResult? pretestResult;
  final String? startMarker;
  final int? pretestIndex;
  final String? pretestSource;
  final bool? pretestLimited;
  final int? pretestStartedAt;
  final int? pretestFinishedAt;
}

class PlacementStore {
  PlacementStore(this.service);

  final StudentPlacementService service;

  PlacementState readPlacement() => service.read();

  void writePlacement(PlacementStoreState patch) {
    final current = service.read();
    service.update(
      current.copyWith(
        status: patch.pretestStatus,
        blocks: patch.pretestBlocks,
        answers: patch.pretestAnswers,
        result: patch.pretestResult,
        startMarker: patch.startMarker,
        index: patch.pretestIndex,
        source: patch.pretestSource,
        limited: patch.pretestLimited,
        startedAt: patch.pretestStartedAt,
        finishedAt: patch.pretestFinishedAt,
        clearResult: patch.pretestResult == null &&
            patch.pretestStatus == PlacementStatus.running,
        clearStartMarker: patch.startMarker == null &&
            (patch.pretestStatus == PlacementStatus.running ||
                patch.pretestStatus == PlacementStatus.skipped),
      ),
    );
  }

  void resetPlacement() => service.reset();

  String? readStartMarker() => service.readStartMarker();
}
