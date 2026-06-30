import 's12_visual_pipeline.dart';
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

const _paidAmbiguousHints = [
  'foto',
  'photo',
  'fotografia',
  'photograph',
  'realista',
  'realistic',
  'fotorrealista',
  'photorealistic',
  'anatomia',
  'anatomy',
  'órgão',
  'orgao',
  'organ',
  'célula',
  'celula',
  'cell',
  'tecido',
  'tissue',
  'rosto',
  'face',
  'retrato',
  'portrait',
];

VisualN3Result routeVisualCheapN3({
  required VisualN2Result n2,
  String? topic,
  String? visualType,
  String? imagePrompt,
}) {
  if (n2.verdict == VisualVerdict.ai) {
    return VisualN3Result(verdict: VisualVerdict.ai, reason: n2.reason);
  }

  final bag = [topic, visualType, imagePrompt]
      .where((part) => part != null && part.trim().isNotEmpty)
      .join(' ')
      .toLowerCase();
  if (n2.verdict == VisualVerdict.ambiguous &&
      _paidAmbiguousHints.any((hint) => bag.contains(hint))) {
    return const VisualN3Result(
      verdict: VisualVerdict.ai,
      reason: 'N3_AMBIGUOUS_PAID_REALISTIC',
    );
  }

  final svg = _buildCheapDidacticSvg(
    title: topic?.trim().isNotEmpty == true
        ? topic!.trim()
        : imagePrompt?.trim().isNotEmpty == true
        ? imagePrompt!.trim()
        : visualType?.trim().isNotEmpty == true
        ? visualType!.trim()
        : 'Visual da aula',
    subtitle: n2.reason,
  );
  final dataUrl = sanitizeAndEncodeSvg(svg);
  if (dataUrl == null) {
    return const VisualN3Result(
      verdict: VisualVerdict.ai,
      reason: 'N3_SOFTWARE_SVG_FAILED',
    );
  }
  return VisualN3Result(
    verdict: VisualVerdict.svg,
    svgDataUrl: dataUrl,
    reason: n2.verdict == VisualVerdict.svg
        ? 'N3_SOFTWARE_GENERATED_FROM_N2_SVG'
        : 'N3_SOFTWARE_JUDGED_AMBIGUOUS_AS_SVG',
  );
}

String _buildCheapDidacticSvg({
  required String title,
  required String subtitle,
}) {
  final safeTitle = _escapeXml(_shorten(title, 52));
  final safeSubtitle = _escapeXml(_shorten(subtitle, 42));
  return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 360" role="img">
  <rect width="640" height="360" fill="#F8FAFC"/>
  <rect x="40" y="42" width="560" height="276" rx="18" fill="#FFFFFF" stroke="#CBD5E1" stroke-width="2"/>
  <text x="320" y="86" text-anchor="middle" font-family="Arial, sans-serif" font-size="24" font-weight="700" fill="#111827">$safeTitle</text>
  <text x="320" y="116" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" fill="#64748B">$safeSubtitle</text>
  <circle cx="176" cy="214" r="42" fill="#DBEAFE" stroke="#2563EB" stroke-width="3"/>
  <circle cx="320" cy="214" r="42" fill="#DCFCE7" stroke="#16A34A" stroke-width="3"/>
  <circle cx="464" cy="214" r="42" fill="#FEF3C7" stroke="#D97706" stroke-width="3"/>
  <path d="M222 214h52" stroke="#334155" stroke-width="4" stroke-linecap="round"/>
  <path d="M274 214l-12-10v20z" fill="#334155"/>
  <path d="M366 214h52" stroke="#334155" stroke-width="4" stroke-linecap="round"/>
  <path d="M418 214l-12-10v20z" fill="#334155"/>
  <text x="176" y="219" text-anchor="middle" font-family="Arial, sans-serif" font-size="18" font-weight="700" fill="#1E3A8A">1</text>
  <text x="320" y="219" text-anchor="middle" font-family="Arial, sans-serif" font-size="18" font-weight="700" fill="#166534">2</text>
  <text x="464" y="219" text-anchor="middle" font-family="Arial, sans-serif" font-size="18" font-weight="700" fill="#92400E">3</text>
</svg>''';
}

String _shorten(String value, int max) {
  final trimmed = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (trimmed.length <= max) return trimmed;
  return '${trimmed.substring(0, max - 3)}...';
}

String _escapeXml(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
