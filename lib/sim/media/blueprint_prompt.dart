import '../state/student_learning_state.dart';

class BlueprintColorLegendItem {
  const BlueprintColorLegendItem({
    required this.id,
    required this.label,
    required this.color,
  });

  final int id;
  final String label;
  final String color;
}

bool hasUsableColorLegend(Object? legend) {
  if (legend is! List || legend.length < 2 || legend.length > 6) {
    return false;
  }
  return legend.every((item) {
    if (item is BlueprintColorLegendItem) return _isHexColor(item.color);
    if (item is Map) {
      return item['id'] is num &&
          item['label'] is String &&
          item['color'] is String &&
          _isHexColor(item['color'] as String);
    }
    return false;
  });
}

bool _isHexColor(String value) =>
    RegExp(r'^#[0-9A-F]{6}$', caseSensitive: false).hasMatch(value);

const Map<String, String> _langNames = {
  'pt': 'Brazilian Portuguese',
  'pt-BR': 'Brazilian Portuguese',
  'es': 'Spanish',
  'en': 'English',
  'fr': 'French',
  'de': 'German',
  'it': 'Italian',
  'ja': 'Japanese',
  'ko': 'Korean',
  'zh': 'Chinese (Simplified)',
  'ru': 'Russian',
  'ar': 'Arabic',
  'hi': 'Hindi',
  'tr': 'Turkish',
  'nl': 'Dutch',
  'pl': 'Polish',
};

String langDirective(String? lang) {
  final code = (lang ?? '').trim();
  if (code.isEmpty) return '';
  final name = _langNames[code] ?? _langNames[code.split('-').first] ?? code;
  return 'STUDENT LANGUAGE: $name ($code). '
      'If any text, letter, word, number, caption, label, arrow-with-words, '
      'title or watermark appears anywhere in the image — even by accident — '
      'it MUST be written in $name. Writing visible text in English '
      '(or any language other than $name) is strictly forbidden. '
      'Reminder: the preferred outcome is ZERO visible text of any kind.';
}

String naturalLangDirective(String? lang) {
  final code = (lang ?? '').trim();
  if (code.isEmpty) return '';
  final name = _langNames[code] ?? _langNames[code.split('-').first] ?? code;
  return 'STUDENT LANGUAGE: $name ($code). '
      'You may include labels, captions, arrows-with-words or titles inside the image when they help teach. '
      'Any visible text MUST be written in $name. '
      'Writing visible text in English (or any language other than $name) is strictly forbidden.';
}

String buildBlueprintPrompt({
  required String topic,
  required String teacherPrompt,
  required List<BlueprintColorLegendItem> colorLegend,
  String? lang,
}) {
  final legend = colorLegend
      .map((item) => '${item.color} = ${item.label}')
      .join('; ');
  return [
    'Create a cyber-premium didactic blueprint image for a lesson.',
    'Topic: ${topic.isEmpty ? 'the current lesson concept' : topic}.',
    'Teacher intent: $teacherPrompt.',
    'Style: black #000000 background, clean white/cyan technical outlines, flat solid colored regions only, no gradients, no shadows, no 3D, no decorative elements.',
    'Use these exact fill colors for the corresponding visible regions: $legend.',
    'Absolutely no text, no letters, no numbers, no arrows, no labels inside the image. The app will add labels as an overlay.',
    'Make the colored regions large, separated and easy to detect by color. Keep anatomy/science/geometry structurally accurate and pedagogically clean.',
    langDirective(lang),
  ].where((part) => part.isNotEmpty).join(' ');
}

String buildSimpleNoTextPrompt({
  required String topic,
  required String teacherPrompt,
  String? lang,
}) {
  return [
    'Create a clean didactic illustration for a lesson.',
    'Topic: ${topic.isEmpty ? 'the current lesson concept' : topic}.',
    'Teacher intent: $teacherPrompt.',
    'ABSOLUTELY NO TEXT, NO LETTERS, NO WORDS, NO NUMBERS, NO CAPTIONS, NO LABELS, NO ARROWS WITH WORDS, NO TITLES, in ANY language, anywhere inside the image. Visible text of any kind is forbidden.',
    'Style: single focused subject, minimal detail, flat colors, clean white or neutral background, technical/didactic illustration, no cartoon characters, no decorative scenery, no balloons, no multiple panels, no logos, no watermarks.',
    'Keep anatomy/science/geometry structurally accurate and pedagogically clean. The app will overlay any necessary labels on top in the student\'s language.',
    langDirective(lang),
  ].where((part) => part.isNotEmpty).join(' ');
}

String buildNaturalImagePrompt({
  required String topic,
  required String teacherPrompt,
  String? lang,
  List<BlueprintColorLegendItem>? colorLegend,
}) {
  final paletteHint = colorLegend != null && colorLegend.length >= 2
      ? 'If helpful, you may use these colors to highlight key regions (purely a suggestion, not a requirement): ${colorLegend.map((item) => '${item.color} for ${item.label}').join('; ')}.'
      : '';
  return [
    'Create a clear, didactic, visually polished illustration for a lesson.',
    'Topic: ${topic.isEmpty ? 'the current lesson concept' : topic}.',
    'Teacher intent: $teacherPrompt.',
    'Style: rich, didactic, textbook-quality illustration. Choose the rendering style that best teaches the concept (anatomical cross-section, scientific diagram, infographic, technical drawing, realistic illustration — pick what fits). Use color, depth, and detail freely. Avoid cartoonish characters, decorative scenery, balloons, multiple panels, logos, watermarks.',
    'Anatomy, biology, physics and geometry must be structurally accurate and pedagogically clean — no anatomical hallucinations, no impossible structures.',
    paletteHint,
    naturalLangDirective(lang),
  ].where((part) => part.isNotEmpty).join(' ');
}

List<BlueprintColorLegendItem> colorLegendFromJson(Object? value) {
  if (value is! List) return const [];
  return value.whereType<Map>().map((item) {
    return BlueprintColorLegendItem(
      id: (item['id'] as num?)?.toInt() ?? 0,
      label: (item['label'] ?? '').toString(),
      color: (item['color'] ?? '').toString(),
    );
  }).where((item) => _isHexColor(item.color) && item.label.isNotEmpty).toList();
}

JsonMap colorLegendToJson(List<BlueprintColorLegendItem> legend) => {
      'color_legend': legend
          .map((item) => {
                'id': item.id,
                'label': item.label,
                'color': item.color,
              })
          .toList(),
    };
