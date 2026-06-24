import 'package:flutter_test/flutter_test.dart';
import 'package:sim_mobile/sim/experience/study_state_resolver.dart';
import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';
import 'package:sim_mobile/sim/state/student_learning_state.dart';

class _NoopImageClient implements LessonImageClient {
  @override
  Future<String?> generateLessonImage({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
  }) async {
    return null;
  }
}

void main() {
  group('live piece translations', () {
    test('normalizes study keys like the live SIM resolver', () {
      expect(
        normalizeStudyKey('Algebra: Funcao do 1o grau!!'),
        'algebra funcao do 1o grau',
      );
      expect(normalizeStudyKey('  FISICA   MECANICA  '), 'fisica mecanica');
      expect(normalizeStudyKey(null), '');
    });

    test('resolves an already prepared study to the aula route', () async {
      final curriculum = const StudentCurriculum(
        topic: 'Algebra',
        totalItems: 1,
        generatedAt: 1000,
        provisional: false,
        items: [
          CurriculumItem(marker: 'M1', text: 'Funcao linear'),
        ],
      );
      final readyKey = preparedLessonMaterialKey(0, 'M1', LessonLayer.l1);
      final state = StudentLearningState.empty(
        lessonLocalId: 'lesson-local-1',
        now: 1000,
      ).copyWith(
        curriculum: curriculum,
        readyLessonMaterials: {
          readyKey: {'text_status': 'ready'},
        },
      );

      final resolution = resolveExistingStudyStateBeforeGeneration(
        ExistingStudyResolverArgs(
          learningState: state,
          curriculum: curriculum,
          placement: null,
          onboarding: const {'objetivo': 'algebra'},
          lessonLocalId: 'lesson-local-1',
          placementEnabled: false,
        ),
      );

      expect(resolution.curriculumMatchesObjective, isTrue);
      expect(resolution.destination, '/cyber/aula');
      expect(resolution.needsLessonGeneration, isFalse);
      expect(
        resolution.readySource,
        ExistingStudyReadySource.readyLessonMaterials,
      );
      expect(resolution.initialItemIndex, 0);
      expect(resolution.initialMarker, 'M1');
    });

    test('renders live math templates through the visual pipeline', () async {
      final pipeline = LessonVisualPipeline(imageClient: _NoopImageClient());
      final svg = await pipeline.renderMathTemplateVisual({
        'math_template': {
          'kind': 'linear_function',
          'params': {
            'm': 2,
            'b': 1,
            'xMin': -2,
            'xMax': 2,
          },
          'labels': {'title': 'Funcao linear'},
        },
      });

      expect(svg, isNotNull);
      expect(svg, contains('<svg'));
      expect(svg, contains('Funcao linear'));
      expect(svg, contains('y = '));
      expect(svg, contains('+ 1'));
    });
  });
}
