import 's12_visual_pipeline.dart' show sanitizeAndEncodeSvg;
import 'math_templates/math_templates.dart';
import 'visual_router_n2.dart';

/// Last zero-cost renderer before paid image offer.
///
/// This is deliberately conservative: it only draws when N2 already classified
/// the request as a software/SVG case or when the textual request is a known
/// deterministic graph. It never calls paid AI and never handles organic/photo
/// subjects.
String? renderLocalVisualFallback({
  required VisualN2Result n2,
  String? topic,
  String? visualType,
  String? imagePrompt,
}) {
  final text = [
    topic,
    visualType,
    imagePrompt,
  ].where((v) => v != null && v.trim().isNotEmpty).join(' ').toLowerCase();
  if (text.trim().isEmpty) return null;
  if (n2.verdict == VisualVerdict.ai) return null;
  if (n2.verdict == VisualVerdict.ambiguous && !_hasDeterministicGraph(text)) {
    return null;
  }

  return _renderQuadraticIfPossible(text) ??
      _renderLinearIfPossible(text) ??
      _renderUnitCircleIfPossible(text) ??
      _renderFlowOrConceptSvg(text, topic: topic, visualType: visualType);
}

bool _hasDeterministicGraph(String text) {
  return _containsAny(text, const [
    'parábola',
    'parabola',
    'quadratic',
    'quadrática',
    'quadratica',
    'função',
    'funcao',
    'function',
    'gráfico',
    'grafico',
    'graph',
    'linear',
    'reta',
    'círculo unitário',
    'circulo unitario',
    'unit circle',
  ]);
}

String? _renderQuadraticIfPossible(String text) {
  if (!_containsAny(text, const [
    'parábola',
    'parabola',
    'quadratic',
    'quadrática',
    'quadratica',
    'função quadrática',
    'funcao quadratica',
  ])) {
    return null;
  }

  final a =
      _containsAny(text, const [
        'baixo',
        'downward',
        'concave down',
        'concavidade para baixo',
      ])
      ? -1
      : 1;
  final c = _extractYIntercept(text) ?? 0;
  return tryRenderMathTemplate({
    'math_template': {
      'name': 'quadratic_function',
      'params': {
        'a': a,
        'b': 0,
        'c': c,
        'x_min': -5,
        'x_max': 5,
        'labels': {
          'title': 'Parábola',
          'vertex': 'vértice',
          'x': 'x',
          'y': 'y',
        },
      },
    },
  });
}

String? _renderLinearIfPossible(String text) {
  if (!_containsAny(text, const [
    'linear',
    'reta',
    'line graph',
    'linear function',
    'função linear',
    'funcao linear',
  ])) {
    return null;
  }
  return tryRenderMathTemplate({
    'math_template': {
      'name': 'linear_function',
      'params': {
        'm': _containsAny(text, const ['decrescente', 'negative slope'])
            ? -1
            : 1,
        'b': _extractYIntercept(text) ?? 0,
        'x_min': -5,
        'x_max': 5,
        'labels': {'title': 'Função linear', 'x': 'x', 'y': 'y'},
      },
    },
  });
}

String? _renderUnitCircleIfPossible(String text) {
  if (!_containsAny(text, const [
    'círculo unitário',
    'circulo unitario',
    'unit circle',
  ])) {
    return null;
  }
  return tryRenderMathTemplate({
    'math_template': {
      'name': 'unit_circle',
      'params': {
        'angle_deg': _extractAngle(text) ?? 45,
        'labels': {'title': 'Círculo unitário'},
      },
    },
  });
}

String? _renderFlowOrConceptSvg(
  String text, {
  String? topic,
  String? visualType,
}) {
  final title = _escapeSvgLabel(_bestTitle(topic, visualType));
  final isGraph = _containsAny(text, const [
    'gráfico',
    'grafico',
    'graph',
    'chart',
    'eixo',
    'axis',
    'coordinate',
    'coordenada',
  ]);
  if (isGraph) {
    return sanitizeAndEncodeSvg('''
<svg width="800" height="500" viewBox="0 0 800 500" xmlns="http://www.w3.org/2000/svg">
  <rect width="800" height="500" fill="#FFFFFF"/>
  <text x="400" y="42" text-anchor="middle" font-family="Arial, sans-serif" font-size="24" font-weight="700" fill="#0F172A">$title</text>
  <g stroke="#CBD5E1" stroke-width="1">
    <line x1="90" y1="100" x2="90" y2="410"/>
    <line x1="190" y1="100" x2="190" y2="410"/>
    <line x1="290" y1="100" x2="290" y2="410"/>
    <line x1="390" y1="100" x2="390" y2="410"/>
    <line x1="490" y1="100" x2="490" y2="410"/>
    <line x1="590" y1="100" x2="590" y2="410"/>
    <line x1="690" y1="100" x2="690" y2="410"/>
    <line x1="70" y1="130" x2="720" y2="130"/>
    <line x1="70" y1="210" x2="720" y2="210"/>
    <line x1="70" y1="290" x2="720" y2="290"/>
    <line x1="70" y1="370" x2="720" y2="370"/>
  </g>
  <line x1="70" y1="370" x2="730" y2="370" stroke="#111827" stroke-width="3"/>
  <line x1="390" y1="80" x2="390" y2="420" stroke="#111827" stroke-width="3"/>
  <path d="M110 340 C220 260 300 235 390 230 C505 225 590 180 690 100" fill="none" stroke="#111827" stroke-width="6" stroke-linecap="round"/>
  <circle cx="390" cy="230" r="9" fill="#111827"/>
  <text x="405" y="222" font-family="Arial, sans-serif" font-size="18" fill="#111827">ponto-chave</text>
</svg>''');
  }

  return sanitizeAndEncodeSvg('''
<svg width="800" height="500" viewBox="0 0 800 500" xmlns="http://www.w3.org/2000/svg">
  <rect width="800" height="500" fill="#FFFFFF"/>
  <text x="400" y="50" text-anchor="middle" font-family="Arial, sans-serif" font-size="24" font-weight="700" fill="#0F172A">$title</text>
  <g font-family="Arial, sans-serif" font-size="20" font-weight="700" fill="#0F172A" stroke="#111827" stroke-width="3">
    <rect x="80" y="180" width="170" height="90" rx="18" fill="#F8FAFC"/>
    <rect x="315" y="180" width="170" height="90" rx="18" fill="#F8FAFC"/>
    <rect x="550" y="180" width="170" height="90" rx="18" fill="#F8FAFC"/>
    <text x="165" y="232" text-anchor="middle">1</text>
    <text x="400" y="232" text-anchor="middle">2</text>
    <text x="635" y="232" text-anchor="middle">3</text>
  </g>
  <g stroke="#111827" stroke-width="4" fill="none" stroke-linecap="round" stroke-linejoin="round">
    <path d="M260 225 H300"/>
    <path d="M292 215 L305 225 L292 235"/>
    <path d="M495 225 H535"/>
    <path d="M527 215 L540 225 L527 235"/>
  </g>
  <text x="400" y="340" text-anchor="middle" font-family="Arial, sans-serif" font-size="19" fill="#475569">diagrama esquemático gerado por software</text>
</svg>''');
}

bool _containsAny(String text, List<String> values) {
  return values.any((value) => text.contains(value));
}

num? _extractYIntercept(String text) {
  final pair = RegExp(
    r'\(\s*0\s*,\s*(-?\d+(?:[\.,]\d+)?)\s*\)',
  ).firstMatch(text);
  if (pair != null) return _parseNum(pair.group(1));
  final yIntercept = RegExp(
    r'(?:intercepto\s*y|intercept\s*y|y-intercept)[^\d-]{0,20}(-?\d+(?:[\.,]\d+)?)',
  ).firstMatch(text);
  if (yIntercept != null) return _parseNum(yIntercept.group(1));
  return null;
}

num? _extractAngle(String text) {
  final match = RegExp(
    r'(-?\d+(?:[\.,]\d+)?)\s*(?:°|graus|degrees|deg)',
  ).firstMatch(text);
  return match == null ? null : _parseNum(match.group(1));
}

num? _parseNum(String? value) {
  if (value == null) return null;
  return num.tryParse(value.replaceAll(',', '.'));
}

String _bestTitle(String? topic, String? visualType) {
  final raw =
      (topic?.trim().isNotEmpty == true ? topic : visualType) ??
      'Visual da aula';
  final oneLine = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (oneLine.length <= 56) return oneLine;
  return '${oneLine.substring(0, 53)}...';
}

String _escapeSvgLabel(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
