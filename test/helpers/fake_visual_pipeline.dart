import 'package:sim_mobile/sim/media/lesson_visual_pipeline.dart';

class FakeNoopImageClient implements LessonImageClient {
  const FakeNoopImageClient();

  @override
  Future<String?> generateLessonImage({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
    String? acceptedOfferId,
    String? idempotencyKey,
  }) async {
    return null;
  }
}

class FakeVisualRouterClient implements LessonVisualRouterClient {
  const FakeVisualRouterClient({this.svgDataUrl});

  final String? svgDataUrl;

  @override
  Future<VisualN3Result> routeVisual({
    required VisualN2Result n2,
    String? topic,
    String? visualType,
    String? imagePrompt,
  }) async {
    if (svgDataUrl != null) {
      return VisualN3Result(
        verdict: VisualVerdict.svg,
        reason: 'TEST_N3_SVG',
        svgDataUrl: svgDataUrl,
      );
    }
    return const VisualN3Result(
      verdict: VisualVerdict.ai,
      reason: 'TEST_N3_AI',
    );
  }
}

LessonVisualPipeline fakeVisualPipeline({String? svgDataUrl}) {
  return LessonVisualPipeline(
    imageClient: const FakeNoopImageClient(),
    visualRouterClient: FakeVisualRouterClient(svgDataUrl: svgDataUrl),
  );
}
