import 'dart:math' as math;

class FormulaTemplateOverride {
  const FormulaTemplateOverride({required this.name, required this.params});

  final String name;
  final Map<String, dynamic> params;
}

FormulaTemplateOverride overrideParamsFromFormula(
  String name,
  Map<String, dynamic> params,
) {
  final formula = params['formula']?.toString().trim();
  if (formula == null || formula.isEmpty) {
    return FormulaTemplateOverride(name: name, params: params);
  }
  final parts = _splitRhs(formula);
  if (parts == null) {
    return FormulaTemplateOverride(name: name, params: params);
  }
  final lhs = parts.$1.toLowerCase();
  final rhs = parts.$2;

  try {
    if (name == 'custom') {
      final inferred = _inferTemplateFromFormula(lhs, rhs, params);
      if (inferred != null) return inferred;
      return FormulaTemplateOverride(name: name, params: params);
    }
    switch (name) {
      case 'linear_function':
        return FormulaTemplateOverride(
          name: name,
          params: {...params, ..._linearCoefficients(rhs, 'x')},
        );
      case 'quadratic_function':
        return FormulaTemplateOverride(
          name: name,
          params: {...params, ..._quadraticCoefficients(rhs, 'x')},
        );
      case 'kinematics_vt':
        return FormulaTemplateOverride(
          name: name,
          params: {
            ...params,
            'v0': _evalAt(rhs, 't', 0),
            'a': _evalAt(rhs, 't', 1) - _evalAt(rhs, 't', 0),
          },
        );
      case 'kinematics_st':
        final f0 = _evalAt(rhs, 't', 0);
        final f1 = _evalAt(rhs, 't', 1);
        final f2 = _evalAt(rhs, 't', 2);
        final a = f2 - 2 * f1 + f0;
        return FormulaTemplateOverride(
          name: name,
          params: {...params, 's0': f0, 'v0': f1 - f0 - a / 2, 'a': a},
        );
    }
  } catch (_) {
    return FormulaTemplateOverride(name: name, params: params);
  }
  return FormulaTemplateOverride(name: name, params: params);
}

FormulaTemplateOverride? _inferTemplateFromFormula(
  String lhs,
  String rhs,
  Map<String, dynamic> params,
) {
  if (lhs == 'v') {
    return overrideParamsFromFormula('kinematics_vt', {
      ...params,
      'formula': 'v=$rhs',
    });
  }
  if (lhs == 's') {
    return overrideParamsFromFormula('kinematics_st', {
      ...params,
      'formula': 's=$rhs',
    });
  }
  if (lhs == 'y' || lhs == 'f') {
    final q = _quadraticCoefficients(rhs, 'x');
    final a = (q['a'] as num).toDouble();
    if (a.abs() < 1e-9) {
      return FormulaTemplateOverride(
        name: 'linear_function',
        params: {...params, ..._linearCoefficients(rhs, 'x')},
      );
    }
    return FormulaTemplateOverride(
      name: 'quadratic_function',
      params: {...params, ...q},
    );
  }
  return null;
}

(String, String)? _splitRhs(String formula) {
  final match = RegExp(r'^\s*([a-zA-Z]\w*)\s*=\s*(.+)$').firstMatch(formula);
  if (match == null) return null;
  return (match.group(1)!, match.group(2)!);
}

Map<String, double> _linearCoefficients(String rhs, String variable) {
  final f0 = _evalAt(rhs, variable, 0);
  final f1 = _evalAt(rhs, variable, 1);
  return {'a': f1 - f0, 'b': f0};
}

Map<String, double> _quadraticCoefficients(String rhs, String variable) {
  final f0 = _evalAt(rhs, variable, 0);
  final f1 = _evalAt(rhs, variable, 1);
  final f2 = _evalAt(rhs, variable, 2);
  final c = f0;
  final a = (f2 - 2 * f1 + f0) / 2;
  final b = f1 - a - c;
  return {'a': a, 'b': b, 'c': c};
}

double _evalAt(String expression, String variable, double value) {
  final parser = _ExpressionParser(expression, variable, value);
  final result = parser.parse();
  if (!result.isFinite) throw const FormatException('formula not finite');
  return result;
}

class _ExpressionParser {
  _ExpressionParser(String source, this.variable, this.value)
    : source = _normalize(source);

  final String source;
  final String variable;
  final double value;
  int index = 0;

  double parse() {
    final out = _parseExpression();
    _skipSpaces();
    if (index != source.length) {
      throw FormatException('unexpected token at $index');
    }
    return out;
  }

  double _parseExpression() {
    var left = _parseTerm();
    while (true) {
      _skipSpaces();
      if (_consume('+')) {
        left += _parseTerm();
      } else if (_consume('-')) {
        left -= _parseTerm();
      } else {
        return left;
      }
    }
  }

  double _parseTerm() {
    var left = _parsePower();
    while (true) {
      _skipSpaces();
      if (_consume('*')) {
        left *= _parsePower();
      } else if (_consume('/')) {
        left /= _parsePower();
      } else {
        return left;
      }
    }
  }

  double _parsePower() {
    var left = _parseUnary();
    _skipSpaces();
    if (_consume('^')) {
      left = math.pow(left, _parsePower()).toDouble();
    }
    return left;
  }

  double _parseUnary() {
    _skipSpaces();
    if (_consume('+')) return _parseUnary();
    if (_consume('-')) return -_parseUnary();
    return _parsePrimary();
  }

  double _parsePrimary() {
    _skipSpaces();
    if (_consume('(')) {
      final out = _parseExpression();
      if (!_consume(')')) throw const FormatException('missing )');
      return out;
    }
    if (_peekIdentifier(variable)) {
      index += variable.length;
      return value;
    }
    return _parseNumber();
  }

  double _parseNumber() {
    _skipSpaces();
    final start = index;
    while (index < source.length && RegExp(r'[0-9.]').hasMatch(source[index])) {
      index++;
    }
    if (start == index) throw FormatException('number expected at $index');
    return double.parse(source.substring(start, index));
  }

  bool _peekIdentifier(String id) {
    if (!source.startsWith(id, index)) return false;
    final end = index + id.length;
    if (end < source.length && RegExp(r'[a-zA-Z0-9_]').hasMatch(source[end])) {
      return false;
    }
    return true;
  }

  bool _consume(String char) {
    _skipSpaces();
    if (index < source.length && source[index] == char) {
      index++;
      return true;
    }
    return false;
  }

  void _skipSpaces() {
    while (index < source.length && source[index].trim().isEmpty) {
      index++;
    }
  }

  static String _normalize(String raw) {
    var out = raw
        .replaceAll('×', '*')
        .replaceAll('·', '*')
        .replaceAll('−', '-')
        .replaceAll('²', '^2')
        .replaceAll('³', '^3');
    out = out.replaceAllMapped(
      RegExp(r'(\d|\))\s*([a-zA-Z(])'),
      (m) => '${m.group(1)}*${m.group(2)}',
    );
    out = out.replaceAllMapped(
      RegExp(r'([a-zA-Z])\s*(\()'),
      (m) => '${m.group(1)}*${m.group(2)}',
    );
    return out;
  }
}
