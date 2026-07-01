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

  final title = topic?.trim().isNotEmpty == true
      ? topic!.trim()
      : imagePrompt?.trim().isNotEmpty == true
      ? imagePrompt!.trim()
      : visualType?.trim().isNotEmpty == true
      ? visualType!.trim()
      : 'Visual da aula';
  final svg = _buildDomainDidacticSvg(
    bag: bag,
    title: title,
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

String _buildDomainDidacticSvg({
  required String bag,
  required String title,
  required String subtitle,
}) {
  if (_hasAny(bag, const [
    'newton',
    'força',
    'forca',
    'force',
    'velocidade',
    'velocity',
    'aceleração',
    'aceleracao',
    'acceleration',
  ])) {
    return _buildPhysicsSvg(title: title, subtitle: subtitle);
  }
  if (_hasAny(bag, const [
    'função',
    'funcao',
    'function',
    'gráfico',
    'grafico',
    'graph',
    'equação',
    'equation',
    'coordenada',
    'coordinate',
  ])) {
    return _buildGraphSvg(title: title, subtitle: subtitle);
  }
  if (_hasAny(bag, const [
    'verbo',
    'verb',
    'sintaxe',
    'syntax',
    'conjugação',
    'conjugacao',
    'conjugation',
    'gramática',
    'grammar',
  ])) {
    return _buildLanguageSvg(title: title, subtitle: subtitle);
  }
  if (_hasAny(bag, const [
    'comparação',
    'comparacao',
    'comparison',
    'versus',
    ' vs ',
    'antes e depois',
    'before and after',
  ])) {
    return _buildComparisonSvg(title: title, subtitle: subtitle);
  }
  return _buildCheapDidacticSvg(title: title, subtitle: subtitle);
}

bool _hasAny(String bag, List<String> hints) {
  return hints.any((hint) => bag.contains(hint));
}

String _buildPhysicsSvg({required String title, required String subtitle}) {
  final safeTitle = _escapeXml(_shorten(title, 52));
  final safeSubtitle = _escapeXml(_shorten(subtitle, 42));
  return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 360" role="img">
  <rect width="640" height="360" fill="#F8FAFC"/>
  <text x="320" y="48" text-anchor="middle" font-family="Arial, sans-serif" font-size="24" font-weight="700" fill="#111827">$safeTitle</text>
  <text x="320" y="76" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" fill="#64748B">$safeSubtitle</text>
  <line x1="80" y1="270" x2="560" y2="270" stroke="#94A3B8" stroke-width="3"/>
  <rect x="250" y="188" width="140" height="82" rx="10" fill="#DBEAFE" stroke="#2563EB" stroke-width="3"/>
  <text x="320" y="236" text-anchor="middle" font-family="Arial, sans-serif" font-size="18" font-weight="700" fill="#1E3A8A">corpo</text>
  <path d="M390 228h112" stroke="#16A34A" stroke-width="7" stroke-linecap="round"/>
  <path d="M502 228l-20-14v28z" fill="#16A34A"/>
  <text x="455" y="205" text-anchor="middle" font-family="Arial, sans-serif" font-size="18" font-weight="700" fill="#166534">F</text>
  <path d="M250 228H138" stroke="#EF4444" stroke-width="5" stroke-linecap="round" stroke-dasharray="8 8"/>
  <path d="M138 228l20-14v28z" fill="#EF4444"/>
  <text x="184" y="205" text-anchor="middle" font-family="Arial, sans-serif" font-size="16" fill="#991B1B">atrito</text>
</svg>''';
}

String _buildGraphSvg({required String title, required String subtitle}) {
  final safeTitle = _escapeXml(_shorten(title, 52));
  final safeSubtitle = _escapeXml(_shorten(subtitle, 42));
  return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 360" role="img">
  <rect width="640" height="360" fill="#FFFFFF"/>
  <text x="320" y="42" text-anchor="middle" font-family="Arial, sans-serif" font-size="23" font-weight="700" fill="#111827">$safeTitle</text>
  <text x="320" y="68" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" fill="#64748B">$safeSubtitle</text>
  <g stroke="#E5E7EB" stroke-width="1">
    <path d="M110 95v210M170 95v210M230 95v210M290 95v210M350 95v210M410 95v210M470 95v210M530 95v210"/>
    <path d="M90 125h460M90 165h460M90 205h460M90 245h460M90 285h460"/>
  </g>
  <path d="M90 285h470" stroke="#111827" stroke-width="3"/>
  <path d="M110 305V90" stroke="#111827" stroke-width="3"/>
  <path d="M125 270C205 238 260 210 320 185C380 160 445 132 535 105" fill="none" stroke="#2563EB" stroke-width="5"/>
  <circle cx="320" cy="185" r="7" fill="#EF4444"/>
  <text x="540" y="304" font-family="Arial, sans-serif" font-size="18" fill="#111827">x</text>
  <text x="88" y="104" font-family="Arial, sans-serif" font-size="18" fill="#111827">y</text>
</svg>''';
}

String _buildLanguageSvg({required String title, required String subtitle}) {
  final safeTitle = _escapeXml(_shorten(title, 52));
  final safeSubtitle = _escapeXml(_shorten(subtitle, 42));
  return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 360" role="img">
  <rect width="640" height="360" fill="#F8FAFC"/>
  <text x="320" y="48" text-anchor="middle" font-family="Arial, sans-serif" font-size="24" font-weight="700" fill="#111827">$safeTitle</text>
  <text x="320" y="76" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" fill="#64748B">$safeSubtitle</text>
  <rect x="82" y="116" width="476" height="58" rx="12" fill="#FFFFFF" stroke="#CBD5E1" stroke-width="2"/>
  <text x="320" y="153" text-anchor="middle" font-family="Arial, sans-serif" font-size="22" fill="#111827">sujeito  •  verbo  •  complemento</text>
  <path d="M170 190v54h300v-54" fill="none" stroke="#2563EB" stroke-width="3"/>
  <text x="320" y="274" text-anchor="middle" font-family="Arial, sans-serif" font-size="18" font-weight="700" fill="#1E3A8A">estrutura da frase</text>
  <circle cx="170" cy="190" r="7" fill="#2563EB"/>
  <circle cx="320" cy="190" r="7" fill="#2563EB"/>
  <circle cx="470" cy="190" r="7" fill="#2563EB"/>
</svg>''';
}

String _buildComparisonSvg({required String title, required String subtitle}) {
  final safeTitle = _escapeXml(_shorten(title, 52));
  final safeSubtitle = _escapeXml(_shorten(subtitle, 42));
  return '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 360" role="img">
  <rect width="640" height="360" fill="#FFFFFF"/>
  <text x="320" y="46" text-anchor="middle" font-family="Arial, sans-serif" font-size="24" font-weight="700" fill="#111827">$safeTitle</text>
  <text x="320" y="74" text-anchor="middle" font-family="Arial, sans-serif" font-size="13" fill="#64748B">$safeSubtitle</text>
  <rect x="72" y="116" width="210" height="160" rx="18" fill="#DBEAFE" stroke="#2563EB" stroke-width="3"/>
  <rect x="358" y="116" width="210" height="160" rx="18" fill="#DCFCE7" stroke="#16A34A" stroke-width="3"/>
  <text x="177" y="170" text-anchor="middle" font-family="Arial, sans-serif" font-size="22" font-weight="700" fill="#1E3A8A">A</text>
  <text x="463" y="170" text-anchor="middle" font-family="Arial, sans-serif" font-size="22" font-weight="700" fill="#166534">B</text>
  <path d="M292 196h56" stroke="#64748B" stroke-width="4" stroke-linecap="round"/>
  <text x="320" y="226" text-anchor="middle" font-family="Arial, sans-serif" font-size="15" fill="#64748B">compare</text>
</svg>''';
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
