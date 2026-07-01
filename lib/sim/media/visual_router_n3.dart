import 'package:flutter/foundation.dart';

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
  } catch (error, stackTrace) {
    final shortError = _shortVisualN3Error(error);
    if (kDebugMode) {
      debugPrint('[VISUAL_N3_FAIL] $shortError');
      debugPrintStack(stackTrace: stackTrace, label: 'VISUAL_N3_FAIL');
    }
    return VisualN3Result(
      verdict: VisualVerdict.ai,
      reason: 'N3_HTTP_FAILED: $shortError',
    );
  }
}

String _shortVisualN3Error(Object error) {
  final text = error.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= 200) return text;
  return text.substring(0, 200);
}
