import '../state/student_learning_state.dart';
import 'placement_blocks.dart';

enum PlacementStatus {
  idle,
  choosing,
  intro,
  running,
  scoring,
  done,
  skipped,
}

class PlacementState {
  const PlacementState({
    required this.status,
    required this.blocks,
    required this.answers,
    required this.result,
    required this.startMarker,
    required this.index,
    required this.source,
    required this.limited,
    required this.startedAt,
    required this.finishedAt,
    required this.updatedAt,
  });

  final PlacementStatus status;
  final List<PlacementBlock> blocks;
  final List<PlacementAnswer> answers;
  final PlacementResult? result;
  final String? startMarker;
  final int index;
  final String? source;
  final bool limited;
  final int? startedAt;
  final int? finishedAt;
  final int? updatedAt;

  factory PlacementState.empty() => const PlacementState(
        status: PlacementStatus.idle,
        blocks: [],
        answers: [],
        result: null,
        startMarker: null,
        index: 0,
        source: null,
        limited: false,
        startedAt: null,
        finishedAt: null,
        updatedAt: null,
      );

  PlacementState copyWith({
    PlacementStatus? status,
    List<PlacementBlock>? blocks,
    List<PlacementAnswer>? answers,
    PlacementResult? result,
    String? startMarker,
    int? index,
    String? source,
    bool? limited,
    int? startedAt,
    int? finishedAt,
    int? updatedAt,
    bool clearResult = false,
    bool clearStartMarker = false,
  }) {
    return PlacementState(
      status: status ?? this.status,
      blocks: blocks ?? this.blocks,
      answers: answers ?? this.answers,
      result: clearResult ? null : result ?? this.result,
      startMarker: clearStartMarker ? null : startMarker ?? this.startMarker,
      index: index ?? this.index,
      source: source ?? this.source,
      limited: limited ?? this.limited,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  JsonMap toJson() => {
        'status': status.name,
        'blocks': blocks.map((block) => block.toJson()).toList(),
        'answers': answers.map((answer) => answer.toJson()).toList(),
        'result': result?.toJson(),
        'start_marker': startMarker,
        'index': index,
        'source': source,
        'limited': limited,
        'started_at': startedAt,
        'finished_at': finishedAt,
        'updated_at': updatedAt,
      };

  factory PlacementState.fromJson(JsonMap json) => PlacementState(
        status: PlacementStatus.values.firstWhere(
          (status) => status.name == json['status'],
          orElse: () => PlacementStatus.idle,
        ),
        blocks: (json['blocks'] as List? ?? const [])
            .whereType<Map>()
            .map((block) => PlacementBlock.fromJson(JsonMap.from(block)))
            .toList(),
        answers: (json['answers'] as List? ?? const [])
            .whereType<Map>()
            .map((answer) => PlacementAnswer.fromJson(JsonMap.from(answer)))
            .toList(),
        result: json['result'] is Map
            ? PlacementResult.fromJson(JsonMap.from(json['result'] as Map))
            : null,
        startMarker: json['start_marker'] as String?,
        index: (json['index'] as num?)?.toInt() ?? 0,
        source: json['source'] as String?,
        limited: json['limited'] == true,
        startedAt: (json['started_at'] as num?)?.toInt(),
        finishedAt: (json['finished_at'] as num?)?.toInt(),
        updatedAt: (json['updated_at'] as num?)?.toInt(),
      );
}
