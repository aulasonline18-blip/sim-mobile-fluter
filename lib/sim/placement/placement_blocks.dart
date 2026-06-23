import '../state/student_learning_state.dart';

class PlacementChoice {
  const PlacementChoice({
    required this.id,
    required this.label,
    required this.correct,
  });

  final String id;
  final String label;
  final bool correct;

  JsonMap toJson() => {
        'id': id,
        'label': label,
        'correct': correct,
      };

  factory PlacementChoice.fromJson(JsonMap json) => PlacementChoice(
        id: (json['id'] ?? '').toString(),
        label: (json['label'] ?? '').toString(),
        correct: json['correct'] == true,
      );
}

class PlacementBlock {
  const PlacementBlock({
    required this.id,
    required this.marker,
    required this.prompt,
    required this.choices,
  });

  final String id;
  final String marker;
  final String prompt;
  final List<PlacementChoice> choices;

  JsonMap toJson() => {
        'id': id,
        'marker': marker,
        'prompt': prompt,
        'choices': choices.map((choice) => choice.toJson()).toList(),
      };

  factory PlacementBlock.fromJson(JsonMap json) => PlacementBlock(
        id: (json['id'] ?? '').toString(),
        marker: (json['marker'] ?? '').toString(),
        prompt: (json['prompt'] ?? '').toString(),
        choices: (json['choices'] as List? ?? const [])
            .whereType<Map>()
            .map((choice) => PlacementChoice.fromJson(JsonMap.from(choice)))
            .toList(),
      );
}

class PlacementAnswer {
  const PlacementAnswer({
    required this.blockId,
    required this.marker,
    required this.choiceId,
    required this.correct,
    required this.answeredAt,
  });

  final String blockId;
  final String marker;
  final String choiceId;
  final bool correct;
  final int answeredAt;

  JsonMap toJson() => {
        'block_id': blockId,
        'marker': marker,
        'choice_id': choiceId,
        'correct': correct,
        'answered_at': answeredAt,
      };

  factory PlacementAnswer.fromJson(JsonMap json) => PlacementAnswer(
        blockId: (json['block_id'] ?? '').toString(),
        marker: (json['marker'] ?? '').toString(),
        choiceId: (json['choice_id'] ?? '').toString(),
        correct: json['correct'] == true,
        answeredAt: (json['answered_at'] as num?)?.toInt() ?? 0,
      );
}

class PlacementResult {
  const PlacementResult({
    required this.startMarker,
    required this.masteredMarkers,
    required this.uncertainMarkers,
    required this.failedMarkers,
    required this.scoredAt,
  });

  final String startMarker;
  final List<String> masteredMarkers;
  final List<String> uncertainMarkers;
  final List<String> failedMarkers;
  final int scoredAt;

  JsonMap toJson() => {
        'start_marker': startMarker,
        'mastered_markers': masteredMarkers,
        'uncertain_markers': uncertainMarkers,
        'failed_markers': failedMarkers,
        'scored_at': scoredAt,
      };

  factory PlacementResult.fromJson(JsonMap json) => PlacementResult(
        startMarker: (json['start_marker'] ?? '').toString(),
        masteredMarkers: (json['mastered_markers'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
        uncertainMarkers: (json['uncertain_markers'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
        failedMarkers: (json['failed_markers'] as List? ?? const [])
            .map((value) => value.toString())
            .toList(),
        scoredAt: (json['scored_at'] as num?)?.toInt() ?? 0,
      );
}

List<PlacementBlock> createPretestBlocks(List<CurriculumItem> items) {
  return items.take(3).toList().asMap().entries.map((entry) {
    final index = entry.key;
    final item = entry.value;
    return PlacementBlock(
      id: 'pre-${index + 1}',
      marker: item.marker,
      prompt: item.text,
      choices: [
        PlacementChoice(
          id: 'pre-${index + 1}-a',
          label: 'placement_fallback_mastered',
          correct: true,
        ),
        PlacementChoice(
          id: 'pre-${index + 1}-b',
          label: 'placement_fallback_not_yet',
          correct: false,
        ),
      ],
    );
  }).toList();
}

PlacementResult? scorePlacement(
  List<PlacementBlock> blocks,
  List<PlacementAnswer> answers, {
  int? now,
}) {
  if (blocks.isEmpty || answers.isEmpty) return null;
  final markerOrder = blocks.map((block) => block.marker).toList();
  final answerByMarker = {
    for (final answer in answers) answer.marker: answer,
  };
  final mastered = <String>[];
  final failed = <String>[];
  final uncertain = <String>[];

  for (final marker in markerOrder) {
    final answer = answerByMarker[marker];
    if (answer == null) {
      uncertain.add(marker);
    } else if (answer.correct) {
      mastered.add(marker);
    } else {
      failed.add(marker);
    }
  }

  String? startMarker;
  if (failed.isNotEmpty) {
    startMarker = failed.first;
  } else {
    final lastCorrect = mastered.isEmpty ? null : mastered.last;
    final lastCorrectIdx =
        lastCorrect == null ? -1 : markerOrder.indexOf(lastCorrect);
    final nextIdx = lastCorrectIdx + 1;
    startMarker = nextIdx >= 0 && nextIdx < markerOrder.length
        ? markerOrder[nextIdx]
        : lastCorrect;
  }
  if (startMarker == null || startMarker.isEmpty) return null;

  return PlacementResult(
    startMarker: startMarker,
    masteredMarkers: mastered,
    uncertainMarkers: uncertain,
    failedMarkers: failed,
    scoredAt: now ?? DateTime.now().millisecondsSinceEpoch,
  );
}
