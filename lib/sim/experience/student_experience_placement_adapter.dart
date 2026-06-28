import '../placement/placement_state.dart';
import '../placement/student_placement_service.dart';
import '../state/student_learning_state.dart';

class PlacementDecision {
  const PlacementDecision({
    required this.enabled,
    required this.placement,
    required this.settled,
  });

  final bool enabled;
  final PlacementState placement;
  final bool settled;
}

class StartPosition {
  const StartPosition({
    required this.itemIndex,
    required this.marker,
    required this.item,
  });

  final int itemIndex;
  final String? marker;
  final CurriculumItem? item;
}

class StudentExperiencePlacementAdapter {
  StudentExperiencePlacementAdapter({
    required this.service,
    required this.enabled,
  });

  final StudentPlacementService service;
  final bool enabled;

  PlacementDecision readPlacementDecision() {
    final placement = service.read();
    return PlacementDecision(
      enabled: enabled,
      placement: placement,
      settled: isPlacementSettled(placement, enabled),
    );
  }

  bool isPlacementSettled(PlacementState placement, bool enabled) {
    return !enabled ||
        placement.status == PlacementStatus.done ||
        placement.status == PlacementStatus.skipped;
  }

  StartPosition resolveStartPosition(
    StudentCurriculum curriculum,
    PlacementState placement,
  ) {
    final rawStartMarker = placement.startMarker?.trim() ?? '';
    final startMarker = enabled && rawStartMarker.isNotEmpty
        ? rawStartMarker
        : null;
    final matchedIndex = startMarker == null
        ? 0
        : curriculum.items.indexWhere(
            (item) => item.marker.trim() == startMarker,
          );
    final itemIndex = matchedIndex >= 0 ? matchedIndex : 0;
    return StartPosition(
      itemIndex: itemIndex,
      marker: curriculum.items.isEmpty
          ? null
          : curriculum.items[itemIndex].marker,
      item: curriculum.items.isEmpty ? null : curriculum.items[itemIndex],
    );
  }
}
