// y = a·x + b. Destaca intercepto y (0,b) e raiz x = -b/a (quando a≠0).
// Port fiel do src/cyber/math-templates/linear-function.ts do SIM Web.
import 'dart:math' as math;
import 'shared.dart';

String? renderLinearFunction(Map<String, dynamic> p) {
  final ad = p['a'];
  final bd = p['b'];
  if (ad is! num || bd is! num) return null;
  final a = ad.toDouble();
  final b = bd.toDouble();
  if (!a.isFinite || !b.isFinite) return null;

  final xMin = (p['x_min'] is num) ? (p['x_min'] as num).toDouble() : -10.0;
  final xMax = (p['x_max'] is num) ? (p['x_max'] as num).toDouble() : 10.0;
  if (xMax <= xMin) return null;

  double yFn(double x) => a * x + b;
  final yLeft = yFn(xMin);
  final yRight = yFn(xMax);

  final ys = [0.0, b, yLeft, yRight];
  double yMin = ys.reduce(math.min);
  double yMax = ys.reduce(math.max);
  final span = math.max(1.0, yMax - yMin);
  yMin -= span * 0.15;
  yMax += span * 0.20;

  final s = makeScale(xMin, xMax, yMin, yMax);

  final labels = p['labels'] is Map ? p['labels'] as Map : {};
  final xLbl = labels['x']?.toString() ?? 'x';
  final yLbl = labels['y']?.toString() ?? 'y';
  final rootLbl = labels['root']?.toString() ?? 'root';
  final title = labels['title']?.toString() ?? 'y = a·x + b';

  final body = StringBuffer();
  body.write(renderAxes(s, xLabel: xLbl, yLabel: yLbl));

  // Reta
  body.write('<line x1="${s.toX(xMin).toStringAsFixed(2)}" y1="${s.toY(yLeft).toStringAsFixed(2)}" x2="${s.toX(xMax).toStringAsFixed(2)}" y2="${s.toY(yRight).toStringAsFixed(2)}" stroke="$cyberCurve" stroke-width="3" stroke-linecap="round"/>');

  // Intercepto y = (0, b)
  if (xMin <= 0 && xMax >= 0) {
    final px = s.toX(0);
    final py = s.toY(b);
    body.write(highlightPoint(px, py, color: cyberAccent));
    body.write(labelTag(px, py, '(0, ${fmt(b)})', color: cyberAccent, anchor: 'right'));
  }

  // Raiz x = -b/a
  if (a != 0) {
    final xr = -b / a;
    if (xr >= xMin && xr <= xMax) {
      final px = s.toX(xr);
      final py = s.toY(0);
      body.write(highlightPoint(px, py, color: cyberCritical));
      body.write(labelTag(px, py, '$rootLbl: x = ${fmt(xr)}', color: cyberCritical, anchor: 'below'));
    }
  }

  final sign = b >= 0 ? '+' : '−';
  body.write(equationBadge('y = ${fmt(a)}·x $sign ${fmt(b.abs())}'));
  return wrapSvg(title, body.toString());
}
