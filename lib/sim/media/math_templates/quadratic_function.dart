// y = a·x² + b·x + c. Destaca vértice e raízes (Bhaskara) quando reais.
// Port fiel do src/cyber/math-templates/quadratic-function.ts do SIM Web.
import 'dart:math' as math;
import 'shared.dart';

String? renderQuadraticFunction(Map<String, dynamic> p) {
  final ad = p['a'];
  final bd = p['b'];
  final cd = p['c'];
  if (ad is! num || bd is! num || cd is! num) return null;
  final a = ad.toDouble();
  final b = bd.toDouble();
  final c = cd.toDouble();
  if (!a.isFinite || !b.isFinite || !c.isFinite) return null;
  if (a == 0) return null;

  final xv = -b / (2 * a);
  final yv = a * xv * xv + b * xv + c;

  final xMin = (p['x_min'] is num) ? (p['x_min'] as num).toDouble() : math.min(xv - 5, -5.0);
  final xMax = (p['x_max'] is num) ? (p['x_max'] as num).toDouble() : math.max(xv + 5, 5.0);
  if (xMax <= xMin) return null;

  double yFn(double x) => a * x * x + b * x + c;

  const samples = 240;
  final pts = <({double x, double y})>[];
  for (int i = 0; i <= samples; i++) {
    final x = xMin + ((xMax - xMin) * i) / samples;
    pts.add((x: x, y: yFn(x)));
  }

  double yMin = pts.map((pt) => pt.y).reduce(math.min);
  double yMax = pts.map((pt) => pt.y).reduce(math.max);
  yMin = math.min(yMin, math.min(0.0, math.min(yv, c)));
  yMax = math.max(yMax, math.max(0.0, math.max(yv, c)));
  final span = math.max(1.0, yMax - yMin);
  yMin -= span * 0.12;
  yMax += span * 0.20;

  final s = makeScale(xMin, xMax, yMin, yMax);

  final labels = p['labels'] is Map ? p['labels'] as Map : {};
  final xLbl = labels['x']?.toString() ?? 'x';
  final yLbl = labels['y']?.toString() ?? 'y';
  final vertexLbl = labels['vertex']?.toString() ?? 'vertex';
  final rootLbl = labels['root']?.toString() ?? 'root';
  final title = labels['title']?.toString() ?? 'y = a·x² + b·x + c';

  final body = StringBuffer();
  body.write(renderAxes(s, xLabel: xLbl, yLabel: yLbl));

  // Curva
  final pathParts = pts.asMap().entries.map((e) {
    final i = e.key;
    final pt = e.value;
    return '${i == 0 ? 'M' : 'L'}${s.toX(pt.x).toStringAsFixed(2)},${s.toY(pt.y).toStringAsFixed(2)}';
  }).join(' ');
  body.write('<path d="$pathParts" fill="none" stroke="$cyberCurve" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>');

  // Vértice
  if (xv >= xMin && xv <= xMax) {
    final px = s.toX(xv);
    final py = s.toY(yv);
    body.write(highlightPoint(px, py, color: cyberAccent));
    body.write(labelTag(px, py, '$vertexLbl: (${fmt(xv)}, ${fmt(yv)})', color: cyberAccent, anchor: a > 0 ? 'below' : 'above'));
  }

  // Raízes (Bhaskara)
  final delta = b * b - 4 * a * c;
  if (delta >= 0) {
    final sq = math.sqrt(delta);
    final x1 = (-b - sq) / (2 * a);
    final x2 = (-b + sq) / (2 * a);
    for (final xr in [x1, x2]) {
      if (xr >= xMin && xr <= xMax && (xr - xv).abs() > 1e-6) {
        final px = s.toX(xr);
        final py = s.toY(0);
        body.write(highlightPoint(px, py, color: cyberCritical));
        body.write(labelTag(px, py, 'x = ${fmt(xr)}', color: cyberCritical, anchor: 'below'));
      }
    }
  }

  final bSign = b >= 0 ? '+' : '−';
  final cSign = c >= 0 ? '+' : '−';
  body.write(equationBadge('y = ${fmt(a)}·x² $bSign ${fmt(b.abs())}·x $cSign ${fmt(c.abs())}', minW: 140));
  return wrapSvg(title, body.toString());
}
