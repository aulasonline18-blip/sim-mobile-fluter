class GenerateLessonImageRequest {
  const GenerateLessonImageRequest({
    required this.prompt,
    required this.lessonKey,
    this.aspectRatio = '1:1',
  });

  final String prompt;
  final String lessonKey;
  final String aspectRatio;

  String get normalizedAspectRatio {
    const allowed = {'1:1', '16:9', '9:16', '4:3', '3:4'};
    return allowed.contains(aspectRatio) ? aspectRatio : '1:1';
  }

  GenerateLessonImageRequest normalized() => GenerateLessonImageRequest(
        prompt: prompt.trim().length > 4000
            ? prompt.trim().substring(0, 4000)
            : prompt.trim(),
        lessonKey: lessonKey.trim().length > 160
            ? lessonKey.trim().substring(0, 160)
            : lessonKey.trim(),
        aspectRatio: normalizedAspectRatio,
      );
}

class GenerateLessonImageResponse {
  const GenerateLessonImageResponse({required this.dataUrl});

  final String dataUrl;
}

const String lessonImageModelPath = 'google/nano-banana-pro';
const int lessonImageRequestTimeoutMs = 60000;
const int lessonImageRateLimitWindowMs = 60000;
const int lessonImageRateLimitMaxPerWindow = 10;
const int lessonImageCircuitFailThreshold = 5;
const int lessonImageCircuitOpenMs = 60000;
