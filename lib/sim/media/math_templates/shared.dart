// Helpers compartilhados pelos templates matemáticos.
// Port fiel do src/cyber/math-templates/shared.ts do SIM Web.
import 'dart:math' as math;

const cyberBg = '#FFFFFF';
const cyberAxis = '#1a1a1a';
const cyberGrid = 'rgba(0,0,0,0.08)';
const cyberCurve = '#1a1a1a';
const cyberCurveAlt = '#5A6B7B';
const cyberAccent = '#374151';
const cyberCritical = '#111827';
const cyberGhost = 'rgba(0,0,0,0.55)';
const cyberLabel = '#0F172A';
const cyberMonoFont = 'JetBrains Mono, ui-monospace, SFMono-Regular, Menlo, monospace';

const int canvasW = 800;
const int canvasH = 500;
const int plotX0 = 80;
const int plotX1 = 760;
const int plotY0 = 60;
const int plotY1 = 420;
const int plotW = 680; // plotX1 - plotX0
const int plotH = 360; // plotY1 - plotY0

class Scale {
  const Scale({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
  });
  final double xMin, xMax, yMin, yMax;

  double toX(double x) => plotX0 + ((x - xMin) / (xMax - xMin)) * plotW;
  double toY(double y) => plotY1 - ((y - yMin) / (yMax - yMin)) * plotH;
}

Scale makeScale(double xMin, double xMax, double yMin, double yMax) {
  double x0 = xMin, x1 = xMax, y0 = yMin, y1 = yMax;
  if (x1 == x0) x1 = x0 + 1;
  if (y1 == y0) y1 = y0 + 1;
  return Scale(xMin: x0, xMax: x1, yMin: y0, yMax: y1);
}

double niceStep(double range, {int targetTicks = 8}) {
  if (range <= 0) return 1;
  final rough = range / targetTicks;
  final exp = math.log(rough) / math.log(10);
  final pow = math.pow(10, exp.floor()).toDouble();
  final norm = rough / pow;
  double step;
  if (norm < 1.5) step = 1;
  else if (norm < 3) step = 2;
  else if (norm < 7) step = 5;
  else step = 10;
  return step * pow;
}

String escapeXml(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

String fmtNum(double n) {
  if (!n.isFinite) return '—';
  final abs = n.abs();
  if (abs == 0) return '0';
  if (abs >= 100) return n.toStringAsFixed(0);
  if (abs >= 10) return _trimZeros(n.toStringAsFixed(1));
  if (abs >= 1) return _trimZeros(n.toStringAsFixed(2));
  return _trimZeros(n.toStringAsFixed(3));
}

String _trimZeros(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceAll(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}

double _ceilToStep(double value, double step) {
  if (step <= 0) return value;
  return (value / step).ceil() * step;
}

String renderAxes(Scale s, {String? xLabel, String? yLabel}) {
  final xStep = niceStep(s.xMax - s.xMin);
  final yStep = niceStep(s.yMax - s.yMin);
  final parts = <String>[];

  // Grid vertical
  for (double x = _ceilToStep(s.xMin, xStep); x <= s.xMax + 1e-9; x += xStep) {
    final px = s.toX(x);
    parts.add('<line x1="${px.toStringAsFixed(2)}" y1="$plotY0" x2="${px.toStringAsFixed(2)}" y2="$plotY1" stroke="$cyberGrid" stroke-width="1"/>');
  }
  for (double y = _ceilToStep(s.yMin, yStep); y <= s.yMax + 1e-9; y += yStep) {
    final py = s.toY(y);
    parts.add('<line x1="$plotX0" y1="${py.toStringAsFixed(2)}" x2="$plotX1" y2="${py.toStringAsFixed(2)}" stroke="$cyberGrid" stroke-width="1"/>');
  }

  final axisXd = (s.yMin <= 0 && s.yMax >= 0) ? s.toY(0) : plotY1.toDouble();
  final axisYd = (s.xMin <= 0 && s.xMax >= 0) ? s.toX(0) : plotX0.toDouble();
  final ax = axisXd.toStringAsFixed(2);
  final ay = axisYd.toStringAsFixed(2);

  parts.add('<line x1="$plotX0" y1="$ax" x2="$plotX1" y2="$ax" stroke="$cyberAxis" stroke-width="1.8"/>');
  parts.add('<line x1="$ay" y1="$plotY0" x2="$ay" y2="$plotY1" stroke="$cyberAxis" stroke-width="1.8"/>');

  // Setas
  parts.add('<polygon points="$plotX1,$ax ${plotX1 - 10},${(axisXd - 5).toStringAsFixed(2)} ${plotX1 - 10},${(axisXd + 5).toStringAsFixed(2)}" fill="$cyberAxis"/>');
  parts.add('<polygon points="$ay,$plotY0 ${(axisYd - 5).toStringAsFixed(2)},${plotY0 + 10} ${(axisYd + 5).toStringAsFixed(2)},${plotY0 + 10}" fill="$cyberAxis"/>');

  // Ticks eixo X
  for (double x = _ceilToStep(s.xMin, xStep); x <= s.xMax + 1e-9; x += xStep) {
    if (x.abs() < 1e-9 && s.xMin <= 0 && s.xMax >= 0) continue;
    final px = s.toX(x);
    parts.add('<line x1="${px.toStringAsFixed(2)}" y1="${(axisXd - 4).toStringAsFixed(2)}" x2="${px.toStringAsFixed(2)}" y2="${(axisXd + 4).toStringAsFixed(2)}" stroke="$cyberAxis" stroke-width="1.4"/>');
    parts.add('<text x="${px.toStringAsFixed(2)}" y="${(axisXd + 18).toStringAsFixed(2)}" fill="$cyberGhost" font-family="$cyberMonoFont" font-size="11" text-anchor="middle">${fmtNum(x)}</text>');
  }
  // Ticks eixo Y
  for (double y = _ceilToStep(s.yMin, yStep); y <= s.yMax + 1e-9; y += yStep) {
    if (y.abs() < 1e-9 && s.yMin <= 0 && s.yMax >= 0) continue;
    final py = s.toY(y);
    parts.add('<line x1="${(axisYd - 4).toStringAsFixed(2)}" y1="${py.toStringAsFixed(2)}" x2="${(axisYd + 4).toStringAsFixed(2)}" y2="${py.toStringAsFixed(2)}" stroke="$cyberAxis" stroke-width="1.4"/>');
    parts.add('<text x="${(axisYd - 8).toStringAsFixed(2)}" y="${(py + 4).toStringAsFixed(2)}" fill="$cyberGhost" font-family="$cyberMonoFont" font-size="11" text-anchor="end">${fmtNum(y)}</text>');
  }

  if (xLabel != null) {
    parts.add('<text x="${plotX1 + 6}" y="${(axisXd + 4).toStringAsFixed(2)}" fill="$cyberLabel" font-family="$cyberMonoFont" font-size="13" font-weight="600">${escapeXml(xLabel)}</text>');
  }
  if (yLabel != null) {
    parts.add('<text x="${(axisYd - 4).toStringAsFixed(2)}" y="${plotY0 - 12}" fill="$cyberLabel" font-family="$cyberMonoFont" font-size="13" font-weight="600" text-anchor="end">${escapeXml(yLabel)}</text>');
  }

  return parts.join('');
}

String labelTag(double cx, double cy, String text, {String? color, String? bg, String anchor = 'center'}) {
  final c = color ?? cyberLabel;
  final b = bg ?? 'rgba(255,255,255,0.92)';
  const padX = 8.0;
  const h = 22.0;
  const charW = 7.2;
  final w = math.max(28.0, text.length * charW + padX * 2);
  double x = cx - w / 2;
  double y = cy - h / 2;
  if (anchor == 'above') y = cy - h - 12;
  else if (anchor == 'below') y = cy + 12;
  else if (anchor == 'right') { x = cx + 12; y = cy - h / 2; }
  else if (anchor == 'left') { x = cx - w - 12; y = cy - h / 2; }
  return '''
    <g>
      <rect x="${x.toStringAsFixed(2)}" y="${y.toStringAsFixed(2)}" width="${w.toStringAsFixed(2)}" height="${h.toStringAsFixed(2)}" rx="6" ry="6" fill="$b" stroke="$c" stroke-width="1.2" stroke-opacity="0.9"/>
      <text x="${(x + w / 2).toStringAsFixed(2)}" y="${(y + h / 2 + 4).toStringAsFixed(2)}" fill="$c" font-family="$cyberMonoFont" font-size="12" font-weight="600" text-anchor="middle">${escapeXml(text)}</text>
    </g>''';
}

String highlightPoint(double cx, double cy, {String color = cyberCritical}) {
  return '''
    <circle cx="${cx.toStringAsFixed(2)}" cy="${cy.toStringAsFixed(2)}" r="9" fill="$color" fill-opacity="0.15"/>
    <circle cx="${cx.toStringAsFixed(2)}" cy="${cy.toStringAsFixed(2)}" r="5" fill="$color" stroke="#FFFFFF" stroke-width="1.5"/>''';
}

String wrapSvg(String? title, String body) {
  final titleNode = title != null && title.isNotEmpty
      ? '<text x="${canvasW / 2}" y="32" fill="$cyberLabel" font-family="$cyberMonoFont" font-size="16" font-weight="700" text-anchor="middle" letter-spacing="0.5">${escapeXml(title)}</text>'
      : '';
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $canvasW $canvasH" width="100%" height="auto" role="img">\n'
      '  <rect x="0" y="0" width="$canvasW" height="$canvasH" fill="$cyberBg"/>\n'
      '  $titleNode\n'
      '  $body\n'
      '</svg>';
}

String equationBadge(String text, {double minW = 120}) {
  const x = plotX1 - 10.0;
  const y = plotY0 + 6.0;
  final w = math.max(minW, text.length * 8.2 + 24);
  return '''
    <g>
      <rect x="${(x - w).toStringAsFixed(2)}" y="${y.toStringAsFixed(2)}" width="${w.toStringAsFixed(2)}" height="26" rx="6" fill="rgba(255,255,255,0.92)" stroke="$cyberCurve" stroke-width="1.2" stroke-opacity="0.6"/>
      <text x="${(x - w / 2).toStringAsFixed(2)}" y="${(y + 17).toStringAsFixed(2)}" fill="$cyberLabel" font-family="$cyberMonoFont" font-size="12" font-weight="600" text-anchor="middle">${escapeXml(text)}</text>
    </g>''';
}

String fmt(double n) {
  if (!n.isFinite) return '—';
  final r = (n * 100).round() / 100;
  if (r == r.roundToDouble()) return r.toInt().toString();
  return _trimZeros(r.toStringAsFixed(2));
}
