// Registry de templates matemáticos SVG.
// Port fiel do src/cyber/math-templates/index.ts do SIM Web.
//
// REGRA DE OURO:
//   - T02 escolhe qual template e quais parâmetros (visual_trigger.math_template).
//   - Software calcula matematicamente e desenha em SVG puro.
//   - Qualquer falha → null. Orchestrator faz fallback ao Blueprint/IA.
import 'package:flutter/foundation.dart';

import '../s12_visual_pipeline.dart' show sanitizeAndEncodeSvg;
import 'kinematics_vt.dart';
import 'kinematics_st.dart';
import 'linear_function.dart';
import 'quadratic_function.dart';
import 'unit_circle.dart';
import 'formula_parser.dart';

const _allowedNames = {
  'kinematics_vt',
  'kinematics_st',
  'linear_function',
  'quadratic_function',
  'unit_circle',
  'custom',
};

const _templateAliases = {
  'parabola': 'quadratic_function',
  'parábola': 'quadratic_function',
  'quadratic': 'quadratic_function',
  'quadratic_function_graph': 'quadratic_function',
  'funcao_quadratica': 'quadratic_function',
  'função_quadrática': 'quadratic_function',
  'funcion_cuadratica': 'quadratic_function',
  'linear': 'linear_function',
  'line': 'linear_function',
  'reta': 'linear_function',
  'linear_graph': 'linear_function',
  'funcao_linear': 'linear_function',
  'função_linear': 'linear_function',
  'circle': 'unit_circle',
  'circulo_unitario': 'unit_circle',
  'círculo_unitário': 'unit_circle',
  'unit-circle': 'unit_circle',
  'v_t': 'kinematics_vt',
  'velocity_time': 'kinematics_vt',
  'velocidade_tempo': 'kinematics_vt',
  's_t': 'kinematics_st',
  'position_time': 'kinematics_st',
  'posicao_tempo': 'kinematics_st',
  'posição_tempo': 'kinematics_st',
};

/// Renderiza template matemático. Retorna SVG cru ou null em qualquer falha.
String? renderMathTemplate(String name, Map<String, dynamic> params) {
  try {
    switch (name) {
      case 'kinematics_vt':
        return renderKinematicsVT(params);
      case 'kinematics_st':
        return renderKinematicsST(params);
      case 'linear_function':
        return renderLinearFunction(params);
      case 'quadratic_function':
        return renderQuadraticFunction(params);
      case 'unit_circle':
        return renderUnitCircle(params);
      default:
        return null;
    }
  } catch (_) {
    return null;
  }
}

/// Lê `visual_trigger.math_template` e tenta renderizar como data URL.
/// Retorna data URL SVG ou null se inválido/não suportado.
String? tryRenderMathTemplate(Object? visualTrigger) {
  if (visualTrigger is! Map) return null;
  final raw = visualTrigger['math_template'];
  if (raw is! Map) return null;

  final rawName = raw['name']?.toString();
  final name = _canonicalTemplateName(rawName);
  if (name == null || !_allowedNames.contains(name)) {
    _logMathTemplateReject(
      'name="$rawName" canonical="$name" not in $_allowedNames',
    );
    return null;
  }

  final rawParams = raw['params'];
  final params = <String, dynamic>{
    if (rawParams is Map) ...Map<String, dynamic>.from(rawParams),
    if (raw['formula'] != null) 'formula': raw['formula'],
  };
  if (params.isEmpty) {
    _logMathTemplateReject('name="$rawName" canonical="$name" without params');
    return null;
  }

  final overridden = overrideParamsFromFormula(name, params);
  if (!_allowedNames.contains(overridden.name) || overridden.name == 'custom') {
    _logMathTemplateReject(
      'name="$rawName" canonical="$name" formula did not resolve to supported template',
    );
    return null;
  }
  final svg = renderMathTemplate(overridden.name, overridden.params);
  if (svg == null) {
    _logMathTemplateReject(
      'name="$rawName" canonical="${overridden.name}" renderer returned null',
    );
    return null;
  }
  return sanitizeAndEncodeSvg(svg);
}

String? _canonicalTemplateName(String? rawName) {
  final name = rawName?.trim();
  if (name == null || name.isEmpty) return null;
  if (_allowedNames.contains(name)) return name;
  return _templateAliases[name.toLowerCase()];
}

void _logMathTemplateReject(String reason) {
  if (kDebugMode) {
    debugPrint('[MATH_TPL_REJECT] $reason');
  }
}
