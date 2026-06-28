// Gráfico velocidade × tempo (MRU/MRUV). v(t) = v0 + a·t
// Port fiel do src/cyber/math-templates/kinematics-vt.ts do SIM Web.
import 'dart:math' as math;
import 'shared.dart';

String? renderKinematicsVT(Map<String, dynamic> p) {
  final v0d = p['v0'];
  final ad = p['a'];
  if (v0d is! num || ad is! num) return null;
  final v0 = v0d.toDouble();
  final a = ad.toDouble();
  if (!v0.isFinite || !a.isFinite) return null;

  double tMax;
  final tMaxRaw = p['t_max'];
  if (tMaxRaw is num && tMaxRaw.toDouble() > 0) {
    tMax = tMaxRaw.toDouble();
  } else {
    tMax = math.max(10.0, (v0 != 0 && a != 0) ? (v0 / a).abs() * 2 : 10.0);
  }
  if (tMax <= 0 || tMax > 1e4) return null;

  final vFinal = v0 + a * tMax;
  final ys = [0.0, v0, vFinal];
  double yMin = ys.reduce(math.min);
  double yMax = ys.reduce(math.max);
  final ySpan = math.max(1.0, yMax - yMin);
  yMin -= ySpan * 0.15;
  yMax += ySpan * 0.20;

  final s = makeScale(0, tMax, yMin, yMax);
  final p0x = s.toX(0); final p0y = s.toY(v0);
  final pFx = s.toX(tMax); final pFy = s.toY(vFinal);

  double? tVzero;
  if (a != 0) {
    final t = -v0 / a;
    if (t > 1e-9 && t < tMax - 1e-9) tVzero = t;
  }

  final labels = p['labels'] is Map ? p['labels'] as Map : {};
  final time = labels['time']?.toString() ?? 't (s)';
  final velocity = labels['velocity']?.toString() ?? 'v (m/s)';
  final vZeroLabel = labels['v_zero']?.toString() ?? 'v = 0';
  final vInitial = labels['v_initial']?.toString() ?? 'v₀';
  final title = labels['title']?.toString() ?? 'v × t';

  final lineColor = a == 0 ? cyberCurveAlt : (a > 0 ? cyberCurve : cyberAccent);
  final body = StringBuffer();
  body.write(renderAxes(s, xLabel: time, yLabel: velocity));
  body.write('<line x1="${p0x.toStringAsFixed(2)}" y1="${p0y.toStringAsFixed(2)}" x2="${pFx.toStringAsFixed(2)}" y2="${pFy.toStringAsFixed(2)}" stroke="$lineColor" stroke-width="3" stroke-linecap="round"/>');
  body.write(highlightPoint(p0x, p0y, color: cyberAccent));
  body.write(labelTag(p0x, p0y, '$vInitial = ${fmt(v0)}', color: cyberAccent, anchor: 'right'));

  if (tVzero != null) {
    final px = s.toX(tVzero);
    final py = s.toY(0);
    body.write(highlightPoint(px, py, color: cyberCritical));
    body.write(labelTag(px, py, '$vZeroLabel → t = ${fmt(tVzero)}s', color: cyberCritical, anchor: 'below'));
  }

  final sign = a >= 0 ? '+' : '−';
  body.write(equationBadge('v(t) = ${fmt(v0)} $sign ${fmt(a.abs())}·t'));
  return wrapSvg(title, body.toString());
}
