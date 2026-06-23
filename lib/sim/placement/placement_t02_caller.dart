import '../modules/pedagogical_module_contracts.dart';
import '../state/student_learning_state.dart';
import 'placement_blocks.dart';
import 'placement_payload.dart';

const String placementAssessmentGuidanceReference =
    'T11_placement_addendum.txt server-side guidance';

class PlacementT02Result {
  const PlacementT02Result({required this.blocks, this.raw});

  final List<PlacementBlock> blocks;
  final Object? raw;
}

class PlacementT02Caller {
  PlacementT02Caller({
    required this.t02Client,
    required this.enabled,
  });

  final T02LessonClient t02Client;
  final bool enabled;

  Future<PlacementT02Result?> callPlacementT02(PlacementContext context) async {
    if (!enabled) return null;
    if (context.curriculumItems.isEmpty) return null;
    final targets = context.curriculumItems.take(3).toList();
    if (targets.isEmpty) return null;

    final itemText = targets
        .map((item) => '${item.marker}: ${item.text}')
        .join('\n');
    final material = await t02Client.placement(
      T02LessonRequest(
        lessonLocalId: 'placement',
        item: itemText,
        lang: context.language,
        academic: context.academicLevel ?? '',
        layer: LessonLayer.l1,
        mode: 'session',
        errCount: 0,
        history: const [],
        marker: targets.map((item) => item.marker).join(','),
        profile: {
          'student_profile_internal': context.studentProfileInternal,
          'guidance_for_T02': placementAssessmentGuidanceReference,
          'target_topic': context.objetivo,
        },
      ),
    );

    final first = targets.first;
    final options = material.options;
    if ((options[AnswerLetter.A] ?? '').isEmpty ||
        (options[AnswerLetter.B] ?? '').isEmpty ||
        (options[AnswerLetter.C] ?? '').isEmpty ||
        material.question.trim().isEmpty) {
      return null;
    }
    final block = PlacementBlock(
      id: 'pre-1',
      marker: first.marker,
      prompt: material.question,
      choices: AnswerLetter.values.map((letter) {
        return PlacementChoice(
          id: 'pre-1-${letter.name.toLowerCase()}',
          label: options[letter] ?? '',
          correct: letter == material.correctAnswer,
        );
      }).toList(),
    );
    return PlacementT02Result(blocks: [block], raw: material);
  }
}
