// Círculo trigonométrico unitário. Ângulo em graus, com sin/cos/tan opcionais.
// Port fiel do src/cyber/math-templates/unit-circle.ts do SIM Web.
import 'dart:math' as math;
import 'shared.dart';

String? renderUnitCircle(Map<String, dynamic> p) {
  final angd = p['angle_deg'];
  if (angd is! num) return null;
  final angleRaw = angd.toDouble();
  if (!angleRaw.isFinite) return null;

  final angle = ((angleRaw % 360) + 360) % 360;
  final rad = angle * math.pi / 180;

  const cx = canvasW / 2.0;
  const cy = canvasH / 2.0 + 10;
  const r = 170.0;

  final px = cx + r * math.cos(rad);
  final py = cy - r * math.sin(rad);
  final sinV = math.sin(rad);
  final cosV = math.cos(rad);
  final tanV = math.cos(rad).abs() < 1e-10 ? null : math.tan(rad);

  final labels = p['labels'] is Map ? p['labels'] as Map : {};
  final angleLbl = labels['angle']?.toString() ?? 'θ';
  final sinLbl = labels['sin']?.toString() ?? 'sin';
  final cosLbl = labels['cos']?.toString() ?? 'cos';
  final tanLbl = labels['tan']?.toString() ?? 'tan';
  final title = labels['title']?.toString() ?? '$angleLbl = ${_fmtAngle(angle)}°';

  final body = StringBuffer();

  // Eixos
  body.write('<line x1="${cx - r - 30}" y1="$cy" x2="${cx + r + 30}" y2="$cy" stroke="$cyberAxis" stroke-width="1.5"/>');
  body.write('<line x1="$cx" y1="${cy - r - 30}" x2="$cx" y2="${cy + r + 30}" stroke="$cyberAxis" stroke-width="1.5"/>');
  body.write('<polygon points="${cx + r + 30},$cy ${cx + r + 20},${cy - 5} ${cx + r + 20},${cy + 5}" fill="$cyberAxis"/>');
  body.write('<polygon points="$cx,${cy - r - 30} ${cx - 5},${cy - r - 20} ${cx + 5},${cy - r - 20}" fill="$cyberAxis"/>');

  // Ticks
  body.write('<text x="${cx + r + 4}" y="${cy + 18}" fill="$cyberGhost" font-family="$cyberMonoFont" font-size="11">1</text>');
  body.write('<text x="${cx - r - 12}" y="${cy + 18}" fill="$cyberGhost" font-family="$cyberMonoFont" font-size="11">-1</text>');
  body.write('<text x="${cx + 8}" y="${cy - r - 4}" fill="$cyberGhost" font-family="$cyberMonoFont" font-size="11">1</text>');
  body.write('<text x="${cx + 8}" y="${cy + r + 14}" fill="$cyberGhost" font-family="$cyberMonoFont" font-size="11">-1</text>');

  // Círculo unitário
  body.write('<circle cx="$cx" cy="$cy" r="$r" fill="none" stroke="$cyberCurveAlt" stroke-width="2" stroke-opacity="0.7"/>');

  // Arco do ângulo
  const arcR = 38.0;
  final arcEndX = cx + arcR * math.cos(rad);
  final arcEndY = cy - arcR * math.sin(rad);
  final largeArc = angle > 180 ? 1 : 0;
  body.write('<path d="M ${cx + arcR} $cy A $arcR $arcR 0 $largeArc 0 ${arcEndX.toStringAsFixed(2)} ${arcEndY.toStringAsFixed(2)}" fill="none" stroke="$cyberAccent" stroke-width="2"/>');

  final midRad = rad / 2;
  final lblX = cx + (arcR + 18) * math.cos(midRad);
  final lblY = cy - (arcR + 18) * math.sin(midRad);
  body.write('<text x="${lblX.toStringAsFixed(2)}" y="${lblY.toStringAsFixed(2)}" fill="$cyberAccent" font-family="$cyberMonoFont" font-size="13" font-weight="700" text-anchor="middle" dominant-baseline="middle">${escapeXml(angleLbl)}</text>');

  // Raio até o ponto
  body.write('<line x1="$cx" y1="$cy" x2="${px.toStringAsFixed(2)}" y2="${py.toStringAsFixed(2)}" stroke="$cyberCurve" stroke-width="2.5"/>');

  // Cosseno
  final showCos = p['show_cos'] != false;
  if (showCos) {
    body.write('<line x1="$cx" y1="$cy" x2="${px.toStringAsFixed(2)}" y2="$cy" stroke="$cyberCurveAlt" stroke-width="3" stroke-linecap="round"/>');
    final midX = (cx + px) / 2;
    body.write(labelTag(midX, cy + 18, '$cosLbl = ${_fmtTrig(cosV)}', color: cyberCurveAlt));
  }

  // Seno
  final showSin = p['show_sin'] != false;
  if (showSin) {
    body.write('<line x1="${px.toStringAsFixed(2)}" y1="$cy" x2="${px.toStringAsFixed(2)}" y2="${py.toStringAsFixed(2)}" stroke="$cyberAccent" stroke-width="3" stroke-linecap="round"/>');
    final midY = (cy + py) / 2;
    body.write(labelTag(px + 60, midY, '$sinLbl = ${_fmtTrig(sinV)}', color: cyberAccent));
  }

  // Tangente
  final showTan = p['show_tan'] == true;
  if (showTan && tanV != null && tanV.abs() < 20) {
    final tx = cx + r;
    final ty = cy - r * tanV;
    body.write('<line x1="$tx" y1="$cy" x2="$tx" y2="${ty.toStringAsFixed(2)}" stroke="$cyberCritical" stroke-width="3" stroke-linecap="round"/>');
    body.write(labelTag(tx + 14, (cy + ty) / 2, '$tanLbl = ${_fmtTrig(tanV)}', color: cyberCritical, anchor: 'right'));
  }

  // Ponto no círculo
  body.write(highlightPoint(px, py, color: cyberCritical));
  body.write(labelTag(px, py, '(${_fmtTrig(cosV)}, ${_fmtTrig(sinV)})', color: cyberLabel, anchor: (angle < 90 || angle > 270) ? 'right' : 'left'));

  // Centro
  body.write('<circle cx="$cx" cy="$cy" r="3" fill="$cyberAxis"/>');

  return wrapSvg(title, body.toString());
}

String _fmtTrig(double n) {
  if (!n.isFinite) return '—';
  final r = (n * 1000).round() / 1000;
  if (r == r.roundToDouble()) return r.toInt().toString();
  return _trimZ(r.toStringAsFixed(3));
}

String _fmtAngle(double n) {
  final r = n.round();
  return r.toString();
}

String _trimZ(String s) {
  if (!s.contains('.')) return s;
  s = s.replaceAll(RegExp(r'0+$'), '');
  if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  return s;
}
