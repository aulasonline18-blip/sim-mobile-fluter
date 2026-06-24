import 'dart:math' as math;

const _canvasW = 800.0;
const _canvasH = 500.0;
const _plotX0 = 80.0;
const _plotX1 = 760.0;
const _plotY0 = 60.0;
const _plotY1 = 420.0;
const _bg = '#FFFFFF';
const _axis = '#1a1a1a';
const _grid = 'rgba(0,0,0,0.08)';
const _curve = '#1a1a1a';
const _curveAlt = '#5A6B7B';
const _accent = '#374151';
const _critical = '#111827';
const _label = '#0F172A';
const _font = 'JetBrains Mono, ui-monospace, SFMono-Regular, Menlo, monospace';

String? tryRenderMathTemplate(Object? visualTrigger) {
  if (visualTrigger is! Map) return null;
  final raw = visualTrigger['math_template'];
  if (raw is! Map) return null;
  final name = raw['name'] ?? raw['kind'];
  final params = raw['params'] ?? raw;
  if (name is! String || params is! Map) return null;
  try {
    final p = Map<String, dynamic>.from(params);
    if (raw['labels'] is Map && p['labels'] == null) {
      p['labels'] = raw['labels'];
    }
    return switch (name) {
      'kinematics_vt' => _renderKinematicsVT(p),
      'kinematics_st' => _renderKinematicsST(p),
      'linear_function' => _renderLinearFunction(p),
      'quadratic_function' => _renderQuadraticFunction(p),
      'unit_circle' => _renderUnitCircle(p),
      _ => null,
    };
  } catch (_) {
    return null;
  }
}

String? _renderKinematicsVT(Map<String, dynamic> p) {
  final v0 = _num(p['v0']);
  final a = _num(p['a']);
  if (v0 == null || a == null) return null;
  final tMax = _positive(p['t_max']) ??
      math.max(10, v0 != 0 && a != 0 ? (v0 / a).abs() * 2 : 10);
  if (tMax <= 0 || tMax > 1e4) return null;
  final vFinal = v0 + a * tMax;
  final range = _range([0, v0, vFinal], top: 0.20, bottom: 0.15);
  final s = _Scale(0, tMax, range.$1, range.$2);
  final labels = _labels(p);
  final time = labels['time'] ?? 't (s)';
  final velocity = labels['velocity'] ?? 'v (m/s)';
  final title = labels['title'] ?? 'v × t';
  final lineColor = a == 0
      ? _curveAlt
      : a > 0
          ? _curve
          : _accent;
  final body = <String>[
    _axes(s, xLabel: time, yLabel: velocity),
    '<line x1="${s.x(0)}" y1="${s.y(v0)}" x2="${s.x(tMax)}" y2="${s.y(vFinal)}" stroke="$lineColor" stroke-width="3" stroke-linecap="round"/>',
    _point(s.x(0), s.y(v0), _accent),
    _tag(s.x(0), s.y(v0), '${labels['v_initial'] ?? 'v0'} = ${_fmt(v0)}',
        color: _accent, anchor: _Anchor.right),
  ];
  if (a != 0) {
    final tZero = -v0 / a;
    if (tZero > 1e-9 && tZero < tMax - 1e-9) {
      body
        ..add(_point(s.x(tZero), s.y(0), _critical))
        ..add(_tag(
          s.x(tZero),
          s.y(0),
          '${labels['v_zero'] ?? 'v = 0'} -> t = ${_fmt(tZero)}s',
          color: _critical,
          anchor: _Anchor.below,
        ));
    }
  }
  body.add(
      _equation('v(t) = ${_fmt(v0)} ${a >= 0 ? '+' : '-'} ${_fmt(a.abs())}·t'));
  return _wrap(title, body.join('\n'));
}

String? _renderKinematicsST(Map<String, dynamic> p) {
  final s0 = _num(p['s0']);
  final v0 = _num(p['v0']);
  final a = _num(p['a']);
  if (s0 == null || v0 == null || a == null) return null;
  final tMax = _positive(p['t_max']) ?? 10;
  if (tMax <= 0 || tMax > 1e4) return null;
  double f(double t) => s0 + v0 * t + 0.5 * a * t * t;
  final points = [
    for (var i = 0; i <= 200; i++) (t: tMax * i / 200, y: f(tMax * i / 200)),
  ];
  final range =
      _range([...points.map((p) => p.y), s0], top: 0.20, bottom: 0.15);
  final scale = _Scale(0, tMax, range.$1, range.$2);
  final labels = _labels(p);
  final path = points
      .asMap()
      .entries
      .map((e) =>
          '${e.key == 0 ? 'M' : 'L'}${scale.x(e.value.t).toStringAsFixed(2)},${scale.y(e.value.y).toStringAsFixed(2)}')
      .join(' ');
  final body = <String>[
    _axes(scale,
        xLabel: labels['time'] ?? 't (s)',
        yLabel: labels['position'] ?? 's (m)'),
    '<path d="$path" fill="none" stroke="${a == 0 ? _curveAlt : _curve}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>',
    _point(scale.x(0), scale.y(s0), _accent),
    _tag(
        scale.x(0), scale.y(s0), '${labels['s_initial'] ?? 's0'} = ${_fmt(s0)}',
        color: _accent, anchor: _Anchor.right),
    _equation(_stEquation(s0, v0, a)),
  ];
  return _wrap(labels['title'] ?? 's × t', body.join('\n'));
}

String? _renderLinearFunction(Map<String, dynamic> p) {
  final a = _num(p['a'] ?? p['m']);
  final b = _num(p['b']);
  if (a == null || b == null) return null;
  final xMin = _num(p['x_min'] ?? p['xMin']) ?? -10;
  final xMax = _num(p['x_max'] ?? p['xMax']) ?? 10;
  if (xMax <= xMin) return null;
  double f(double x) => a * x + b;
  final range = _range([0, b, f(xMin), f(xMax)], top: 0.20, bottom: 0.15);
  final s = _Scale(xMin, xMax, range.$1, range.$2);
  final labels = _labels(p);
  final body = <String>[
    _axes(s, xLabel: labels['x'] ?? 'x', yLabel: labels['y'] ?? 'y'),
    '<line x1="${s.x(xMin)}" y1="${s.y(f(xMin))}" x2="${s.x(xMax)}" y2="${s.y(f(xMax))}" stroke="$_curve" stroke-width="3" stroke-linecap="round"/>',
  ];
  if (xMin <= 0 && xMax >= 0) {
    body
      ..add(_point(s.x(0), s.y(b), _accent))
      ..add(_tag(s.x(0), s.y(b), '(0, ${_fmt(b)})',
          color: _accent, anchor: _Anchor.right));
  }
  if (a != 0) {
    final root = -b / a;
    if (root >= xMin && root <= xMax) {
      body
        ..add(_point(s.x(root), s.y(0), _critical))
        ..add(_tag(
            s.x(root), s.y(0), '${labels['root'] ?? 'root'}: x = ${_fmt(root)}',
            color: _critical, anchor: _Anchor.below));
    }
  }
  body.add(
      _equation('y = ${_fmt(a)}·x ${b >= 0 ? '+' : '-'} ${_fmt(b.abs())}'));
  return _wrap(labels['title'] ?? 'y = a·x + b', body.join('\n'));
}

String? _renderQuadraticFunction(Map<String, dynamic> p) {
  final a = _num(p['a']);
  final b = _num(p['b']);
  final c = _num(p['c']);
  if (a == null || b == null || c == null || a == 0) return null;
  final xv = -b / (2 * a);
  final yv = a * xv * xv + b * xv + c;
  final xMin = _num(p['x_min'] ?? p['xMin']) ?? math.min(xv - 5, -5);
  final xMax = _num(p['x_max'] ?? p['xMax']) ?? math.max(xv + 5, 5);
  if (xMax <= xMin) return null;
  double f(double x) => a * x * x + b * x + c;
  final points = [
    for (var i = 0; i <= 240; i++)
      (x: xMin + (xMax - xMin) * i / 240, y: f(xMin + (xMax - xMin) * i / 240)),
  ];
  final range =
      _range([...points.map((p) => p.y), 0, yv, c], top: 0.20, bottom: 0.12);
  final s = _Scale(xMin, xMax, range.$1, range.$2);
  final labels = _labels(p);
  final path = points
      .asMap()
      .entries
      .map((e) =>
          '${e.key == 0 ? 'M' : 'L'}${s.x(e.value.x).toStringAsFixed(2)},${s.y(e.value.y).toStringAsFixed(2)}')
      .join(' ');
  final body = <String>[
    _axes(s, xLabel: labels['x'] ?? 'x', yLabel: labels['y'] ?? 'y'),
    '<path d="$path" fill="none" stroke="$_curve" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>',
  ];
  if (xv >= xMin && xv <= xMax) {
    body
      ..add(_point(s.x(xv), s.y(yv), _accent))
      ..add(_tag(s.x(xv), s.y(yv),
          '${labels['vertex'] ?? 'vertex'}: (${_fmt(xv)}, ${_fmt(yv)})',
          color: _accent, anchor: a > 0 ? _Anchor.below : _Anchor.above));
  }
  final delta = b * b - 4 * a * c;
  if (delta >= 0) {
    final sq = math.sqrt(delta);
    for (final root in [(-b - sq) / (2 * a), (-b + sq) / (2 * a)]) {
      if (root >= xMin && root <= xMax && (root - xv).abs() > 1e-6) {
        body
          ..add(_point(s.x(root), s.y(0), _critical))
          ..add(_tag(s.x(root), s.y(0), 'x = ${_fmt(root)}',
              color: _critical, anchor: _Anchor.below));
      }
    }
  }
  body.add(_equation(
      'y = ${_fmt(a)}·x² ${b >= 0 ? '+' : '-'} ${_fmt(b.abs())}·x ${c >= 0 ? '+' : '-'} ${_fmt(c.abs())}'));
  return _wrap(labels['title'] ?? 'y = a·x² + b·x + c', body.join('\n'));
}

String? _renderUnitCircle(Map<String, dynamic> p) {
  final angleDeg = _num(p['angle_deg'] ?? p['angleDeg']);
  if (angleDeg == null) return null;
  final angle = ((angleDeg % 360) + 360) % 360;
  final rad = angle * math.pi / 180;
  const cx = _canvasW / 2;
  const cy = _canvasH / 2 + 10;
  const r = 170.0;
  final px = cx + r * math.cos(rad);
  final py = cy - r * math.sin(rad);
  final sinV = math.sin(rad);
  final cosV = math.cos(rad);
  final tanV = cosV == 0 ? null : math.tan(rad);
  final labels = _labels(p);
  final body = <String>[
    '<line x1="${cx - r - 30}" y1="$cy" x2="${cx + r + 30}" y2="$cy" stroke="$_axis" stroke-width="1.5"/>',
    '<line x1="$cx" y1="${cy - r - 30}" x2="$cx" y2="${cy + r + 30}" stroke="$_axis" stroke-width="1.5"/>',
    '<circle cx="$cx" cy="$cy" r="$r" fill="none" stroke="$_curveAlt" stroke-width="2" stroke-opacity="0.7"/>',
    '<line x1="$cx" y1="$cy" x2="${px.toStringAsFixed(2)}" y2="${py.toStringAsFixed(2)}" stroke="$_curve" stroke-width="2.5"/>',
  ];
  if (p['show_cos'] != false) {
    body
      ..add(
          '<line x1="$cx" y1="$cy" x2="${px.toStringAsFixed(2)}" y2="$cy" stroke="$_curveAlt" stroke-width="3" stroke-linecap="round"/>')
      ..add(_tag(
          (cx + px) / 2, cy + 18, '${labels['cos'] ?? 'cos'} = ${_fmt(cosV)}',
          color: _curveAlt));
  }
  if (p['show_sin'] != false) {
    body
      ..add(
          '<line x1="${px.toStringAsFixed(2)}" y1="$cy" x2="${px.toStringAsFixed(2)}" y2="${py.toStringAsFixed(2)}" stroke="$_accent" stroke-width="3" stroke-linecap="round"/>')
      ..add(_tag(
          px + 60, (cy + py) / 2, '${labels['sin'] ?? 'sin'} = ${_fmt(sinV)}',
          color: _accent));
  }
  if (p['show_tan'] == true && tanV != null && tanV.abs() < 20) {
    final tx = cx + r;
    final ty = cy - r * tanV;
    body
      ..add(
          '<line x1="$tx" y1="$cy" x2="$tx" y2="${ty.toStringAsFixed(2)}" stroke="$_critical" stroke-width="3" stroke-linecap="round"/>')
      ..add(_tag(
          tx + 14, (cy + ty) / 2, '${labels['tan'] ?? 'tan'} = ${_fmt(tanV)}',
          color: _critical, anchor: _Anchor.right));
  }
  body
    ..add(_point(px, py, _critical))
    ..add(_tag(px, py, '(${_fmt(cosV)}, ${_fmt(sinV)})',
        anchor: angle < 90 || angle > 270 ? _Anchor.right : _Anchor.left));
  return _wrap(labels['title'] ?? '${labels['angle'] ?? 'θ'} = ${_fmt(angle)}°',
      body.join('\n'));
}

class _Scale {
  const _Scale(this.xMin, this.xMax, this.yMin, this.yMax);
  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;

  double x(double value) =>
      _plotX0 + ((value - xMin) / (xMax - xMin)) * (_plotX1 - _plotX0);
  double y(double value) =>
      _plotY1 - ((value - yMin) / (yMax - yMin)) * (_plotY1 - _plotY0);
}

String _axes(_Scale s, {String? xLabel, String? yLabel}) {
  final xStep = _niceStep(s.xMax - s.xMin);
  final yStep = _niceStep(s.yMax - s.yMin);
  final axisX = s.yMin <= 0 && s.yMax >= 0 ? s.y(0) : _plotY1;
  final axisY = s.xMin <= 0 && s.xMax >= 0 ? s.x(0) : _plotX0;
  final parts = <String>[];
  for (var x = (s.xMin / xStep).ceil() * xStep;
      x <= s.xMax + 1e-9;
      x += xStep) {
    parts.add(
        '<line x1="${s.x(x)}" y1="$_plotY0" x2="${s.x(x)}" y2="$_plotY1" stroke="$_grid" stroke-width="1"/>');
  }
  for (var y = (s.yMin / yStep).ceil() * yStep;
      y <= s.yMax + 1e-9;
      y += yStep) {
    parts.add(
        '<line x1="$_plotX0" y1="${s.y(y)}" x2="$_plotX1" y2="${s.y(y)}" stroke="$_grid" stroke-width="1"/>');
  }
  parts
    ..add(
        '<line x1="$_plotX0" y1="$axisX" x2="$_plotX1" y2="$axisX" stroke="$_axis" stroke-width="1.8"/>')
    ..add(
        '<line x1="$axisY" y1="$_plotY0" x2="$axisY" y2="$_plotY1" stroke="$_axis" stroke-width="1.8"/>');
  if (xLabel != null) {
    parts.add(
        '<text x="${_plotX1 + 6}" y="${axisX + 4}" fill="$_label" font-family="$_font" font-size="13" font-weight="600">${_xml(xLabel)}</text>');
  }
  if (yLabel != null) {
    parts.add(
        '<text x="${axisY - 4}" y="${_plotY0 - 12}" fill="$_label" font-family="$_font" font-size="13" font-weight="600" text-anchor="end">${_xml(yLabel)}</text>');
  }
  return parts.join('\n');
}

(double, double) _range(List<double> values,
    {double top = 0.2, double bottom = 0.15}) {
  var min = values.reduce(math.min);
  var max = values.reduce(math.max);
  if (!min.isFinite || !max.isFinite) return (0, 1);
  final span = math.max(1.0, max - min);
  return (min - span * bottom, max + span * top);
}

double _niceStep(double range, [int targetTicks = 8]) {
  if (range <= 0) return 1;
  final rough = range / targetTicks;
  final pow = math.pow(10, (math.log(rough) / math.ln10).floor()).toDouble();
  final norm = rough / pow;
  return (norm < 1.5
          ? 1
          : norm < 3
              ? 2
              : norm < 7
                  ? 5
                  : 10) *
      pow;
}

Map<String, String> _labels(Map<String, dynamic> p) {
  final labels = p['labels'];
  if (labels is! Map) return const {};
  return labels.map((key, value) => MapEntry(key.toString(), value.toString()));
}

double? _num(Object? value) {
  if (value is num && value.isFinite) return value.toDouble();
  return null;
}

double? _positive(Object? value) {
  final n = _num(value);
  return n != null && n > 0 ? n : null;
}

String _wrap(String? title, String body) {
  final titleNode = title == null
      ? ''
      : '<text x="${_canvasW / 2}" y="32" fill="$_label" font-family="$_font" font-size="16" font-weight="700" text-anchor="middle">${_xml(title)}</text>';
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $_canvasW $_canvasH" width="100%" height="auto" role="img"><rect x="0" y="0" width="$_canvasW" height="$_canvasH" fill="$_bg"/>$titleNode$body</svg>';
}

String _point(double cx, double cy, String color) =>
    '<circle cx="$cx" cy="$cy" r="9" fill="$color" fill-opacity="0.15"/><circle cx="$cx" cy="$cy" r="5" fill="$color" stroke="#FFFFFF" stroke-width="1.5"/>';

enum _Anchor { above, below, right, left, center }

String _tag(
  double cx,
  double cy,
  String text, {
  String color = _label,
  _Anchor anchor = _Anchor.center,
}) {
  final width = math.max(28.0, text.length * 7.2 + 16);
  const height = 22.0;
  var x = cx - width / 2;
  var y = cy - height / 2;
  switch (anchor) {
    case _Anchor.above:
      y = cy - height - 12;
      break;
    case _Anchor.below:
      y = cy + 12;
      break;
    case _Anchor.right:
      x = cx + 12;
      break;
    case _Anchor.left:
      x = cx - width - 12;
      break;
    case _Anchor.center:
      break;
  }
  return '<g><rect x="$x" y="$y" width="$width" height="$height" rx="6" fill="rgba(255,255,255,0.92)" stroke="$color" stroke-width="1.2"/><text x="${x + width / 2}" y="${y + height / 2 + 4}" fill="$color" font-family="$_font" font-size="12" font-weight="600" text-anchor="middle">${_xml(text)}</text></g>';
}

String _equation(String text) {
  final width = math.max(120.0, text.length * 8.2 + 24);
  final x = _plotX1 - 10 - width;
  final y = _plotY0 + 6;
  return '<g><rect x="$x" y="$y" width="$width" height="26" rx="6" fill="rgba(255,255,255,0.92)" stroke="$_curve" stroke-width="1.2" stroke-opacity="0.6"/><text x="${x + width / 2}" y="${y + 17}" fill="$_label" font-family="$_font" font-size="12" font-weight="600" text-anchor="middle">${_xml(text)}</text></g>';
}

String _stEquation(double s0, double v0, double a) {
  final parts = <String>['s(t) = ${_fmt(s0)}'];
  if (v0 != 0) parts.add('${v0 >= 0 ? '+' : '-'} ${_fmt(v0.abs())}·t');
  if (a != 0) parts.add('${a >= 0 ? '+' : '-'} ${_fmt((0.5 * a).abs())}·t²');
  return parts.join(' ');
}

String _fmt(double n) {
  if (!n.isFinite) return '—';
  final rounded = (n * 1000).round() / 1000;
  if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);
  return rounded
      .toStringAsFixed(3)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

String _xml(String text) => text
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
