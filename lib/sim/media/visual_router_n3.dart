import 'visual_router_n2.dart';

class VisualN3Result {
  const VisualN3Result({
    required this.verdict,
    required this.reason,
    this.svgDataUrl,
  });

  final VisualVerdict verdict;
  final String reason;
  final String? svgDataUrl;
}

abstract interface class LessonVisualRouterClient {
  Future<VisualN3Result> routeVisual({
    required VisualN2Result n2,
    String? topic,
    String? visualType,
    String? imagePrompt,
  });
}

Future<VisualN3Result> routeVisualCheapN3({
  required LessonVisualRouterClient client,
  required VisualN2Result n2,
  String? topic,
  String? visualType,
  String? imagePrompt,
}) async {
  if (n2.verdict == VisualVerdict.ai) {
    return VisualN3Result(verdict: VisualVerdict.ai, reason: n2.reason);
  }
  try {
    return await client.routeVisual(
      n2: n2,
      topic: topic,
      visualType: visualType,
      imagePrompt: imagePrompt,
    );
  } catch (_) {
    return const VisualN3Result(
      verdict: VisualVerdict.ai,
      reason: 'N3_HTTP_FAILED',
    );
  }
}
