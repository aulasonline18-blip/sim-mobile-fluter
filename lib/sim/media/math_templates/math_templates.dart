// Registry de templates matemáticos SVG.
// Port fiel do src/cyber/math-templates/index.ts do SIM Web.
//
// REGRA DE OURO:
//   - T02 escolhe qual template e quais parâmetros (visual_trigger.math_template).
//   - Software calcula matematicamente e desenha em SVG puro.
//   - Qualquer falha → null. Orchestrator faz fallback ao Blueprint/IA.
import '../s12_visual_pipeline.dart' show sanitizeAndEncodeSvg;
import 'kinematics_vt.dart';
import 'kinematics_st.dart';
import 'linear_function.dart';
import 'quadratic_function.dart';
import 'unit_circle.dart';

const _allowedNames = {
  'kinematics_vt',
  'kinematics_st',
  'linear_function',
  'quadratic_function',
  'unit_circle',
};

/// Renderiza template matemático. Retorna SVG cru ou null em qualquer falha.
String? renderMathTemplate(String name, Map<String, dynamic> params) {
  try {
    switch (name) {
      case 'kinematics_vt': return renderKinematicsVT(params);
      case 'kinematics_st': return renderKinematicsST(params);
      case 'linear_function': return renderLinearFunction(params);
      case 'quadratic_function': return renderQuadraticFunction(params);
      case 'unit_circle': return renderUnitCircle(params);
      default: return null;
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

  final name = raw['name']?.toString();
  if (name == null || !_allowedNames.contains(name)) return null;

  final params = raw['params'];
  if (params is! Map) return null;

  final svg = renderMathTemplate(name, Map<String, dynamic>.from(params));
  if (svg == null) return null;
  return sanitizeAndEncodeSvg(svg);
}
