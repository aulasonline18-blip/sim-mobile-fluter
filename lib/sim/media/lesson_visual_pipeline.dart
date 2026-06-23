import 'blueprint_prompt.dart';
import 'lesson_visual_models.dart';

abstract interface class LessonImageClient {
  Future<String?> generateLessonImage({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
  });
}

class LessonVisualTrigger {
  const LessonVisualTrigger({
    this.teacherPrompt,
    this.needsImage = false,
    this.renderStrategy,
    this.mathTemplate,
    this.colorLegend = const [],
  });

  final String? teacherPrompt;
  final bool needsImage;
  final String? renderStrategy;
  final Object? mathTemplate;
  final List<BlueprintColorLegendItem> colorLegend;

  factory LessonVisualTrigger.fromJson(Object? value) {
    if (value is! Map) return const LessonVisualTrigger();
    final needs = value['needs_image'] == true || value['needsImage'] == true;
    return LessonVisualTrigger(
      teacherPrompt: value['teacher_prompt']?.toString() ??
          value['teacherPrompt']?.toString() ??
          value['prompt']?.toString(),
      needsImage: needs,
      renderStrategy:
          value['render_strategy']?.toString() ?? value['renderStrategy']?.toString(),
      mathTemplate: value['math_template'],
      colorLegend: colorLegendFromJson(value['color_legend']),
    );
  }
}

class LessonVisualPipeline {
  LessonVisualPipeline({required this.imageClient});

  final LessonImageClient imageClient;

  Future<String?> renderMathTemplateVisual(Object? visualTrigger) async {
    final trigger = LessonVisualTrigger.fromJson(visualTrigger);
    if (trigger.mathTemplate == null) return null;
    return null;
  }

  Future<String?> fetchPaidLessonImage(String prompt, String lessonKey) async {
    if (prompt.trim().isEmpty) return null;
    final dataUrl = await imageClient.generateLessonImage(
      prompt: prompt,
      lessonKey: lessonKey,
      aspectRatio: '1:1',
    );
    if (!isUsableImageDataUrl(dataUrl)) return null;
    return dataUrl;
  }

  String buildPromptForTrigger({
    required String topic,
    required LessonVisualTrigger trigger,
    String? lang,
  }) {
    final teacherPrompt = trigger.teacherPrompt ?? '';
    if (trigger.colorLegend.length >= 2) {
      return buildNaturalImagePrompt(
        topic: topic,
        teacherPrompt: teacherPrompt,
        lang: lang,
        colorLegend: trigger.colorLegend,
      );
    }
    return buildNaturalImagePrompt(
      topic: topic,
      teacherPrompt: teacherPrompt,
      lang: lang,
    );
  }
}
