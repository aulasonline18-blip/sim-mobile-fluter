// Gráfico posição × tempo. s(t) = s0 + v0·t + ½·a·t²
// Port fiel do src/cyber/math-templates/kinematics-st.ts do SIM Web.
import 'dart:math' as math;
import 'shared.dart';

String? renderKinematicsST(Map<String, dynamic> p) {
  final s0d = p['s0'];
  final v0d = p['v0'];
  final ad = p['a'];
  if (s0d is! num || v0d is! num || ad is! num) return null;
  final s0 = s0d.toDouble();
  final v0 = v0d.toDouble();
  final a = ad.toDouble();
  if (!s0.isFinite || !v0.isFinite || !a.isFinite) return null;

  final tMaxRaw = p['t_max'];
  final tMax = (tMaxRaw is num && tMaxRaw.toDouble() > 0) ? tMaxRaw.toDouble() : 10.0;
  if (tMax <= 0 || tMax > 1e4) return null;

  double posAt(double t) => s0 + v0 * t + 0.5 * a * t * t;

  const samples = 200;
  final pts = <({double t, double y})>[];
  for (int i = 0; i <= samples; i++) {
    final t = (i / samples) * tMax;
    pts.add((t: t, y: posAt(t)));
  }

  double yMin = pts.map((pt) => pt.y).reduce(math.min);
  double yMax = pts.map((pt) => pt.y).reduce(math.max);
  yMin = math.min(yMin, s0);
  yMax = math.max(yMax, s0);
  if (!yMin.isFinite || !yMax.isFinite) return null;
  final span = math.max(1.0, yMax - yMin);
  yMin -= span * 0.15;
  yMax += span * 0.20;

  final scale = makeScale(0, tMax, yMin, yMax);

  final labels = p['labels'] is Map ? p['labels'] as Map : {};
  final time = labels['time']?.toString() ?? 't (s)';
  final position = labels['position']?.toString() ?? 's (m)';
  final sInitial = labels['s_initial']?.toString() ?? 's₀';
  final title = labels['title']?.toString() ?? 's × t';

  final color = a == 0 ? cyberCurveAlt : cyberCurve;
  final pathParts = pts.asMap().entries.map((e) {
    final i = e.key;
    final pt = e.value;
    final prefix = i == 0 ? 'M' : 'L';
    return '$prefix${scale.toX(pt.t).toStringAsFixed(2)},${scale.toY(pt.y).toStringAsFixed(2)}';
  }).join(' ');

  final body = StringBuffer();
  body.write(renderAxes(scale, xLabel: time, yLabel: position));
  body.write('<path d="$pathParts" fill="none" stroke="$color" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>');

  final px = scale.toX(0);
  final py = scale.toY(s0);
  body.write(highlightPoint(px, py, color: cyberAccent));
  body.write(labelTag(px, py, '$sInitial = ${fmt(s0)}', color: cyberAccent, anchor: 'right'));

  // Equação
  final eq = _buildEq(s0, v0, a);
  body.write(equationBadge(eq));

  return wrapSvg(title, body.toString());
}

String _buildEq(double s0, double v0, double a) {
  final parts = ['s(t) = ${fmt(s0)}'];
  if (v0 != 0) parts.add('${v0 >= 0 ? '+' : '−'} ${fmt(v0.abs())}·t');
  if (a != 0) parts.add('${a >= 0 ? '+' : '−'} ${fmt((0.5 * a).abs())}·t²');
  return parts.join(' ');
}
