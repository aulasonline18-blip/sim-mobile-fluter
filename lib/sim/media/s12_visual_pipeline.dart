// S12 — VisualPipeline (Visual Decision Engine)
// Port fiel do src/core/S12_VisualPipeline.ts do SIM Web.
//
// REGRAS:
//   render_strategy="software" + svg_payload válido → SVG inline, custo zero.
//   svg_payload inválido → fallback para ai (Blueprint).
//   render_strategy="ai" ou ausente → Blueprint, sujeito a gates de custo.
//   Sem visual_trigger / needs_image:false / pedagogical_need:none → skip.

const int _maxSvgBytes = 100000; // 100 KB

/// Valida e converte um SVG em data URL seguro.
/// Retorna null se inválido — chamador deve usar fallback IA.
String? sanitizeAndEncodeSvg(Object? raw) {
  if (raw is! String) return null;
  final svg = raw.trim();
  if (svg.isEmpty) return null;
  if (svg.length > _maxSvgBytes) return null;
  final lower = svg.toLowerCase();
  if (!lower.startsWith('<svg')) return null;
  if (!lower.contains('</svg>')) return null;
  if (!RegExp(r'\bviewBox\s*=', caseSensitive: false).hasMatch(svg)) {
    return null;
  }
  // Bloqueios de segurança XSS:
  if (lower.contains('<script')) {
    return null;
  }
  if (RegExp(r'\son[a-z]+\s*=').hasMatch(lower)) {
    return null;
  }
  if (RegExp(r'javascript\s*:', caseSensitive: false).hasMatch(svg)) {
    return null;
  }
  if (RegExp(r'<foreignobject', caseSensitive: false).hasMatch(lower)) {
    return null;
  }

  final encoded = Uri.encodeComponent(
    svg,
  ).replaceAll("'", '%27').replaceAll('"', '%22');
  return 'data:image/svg+xml;utf8,$encoded';
}

class VisualDecision {
  const VisualDecision({
    required this.generate,
    required this.prompt,
    required this.svg,
    required this.reason,
  });

  /// true só para AI Blueprint paga. SVG inline NÃO conta como "generate".
  final bool generate;

  /// Prompt pro Blueprint. Null quando não vai pagar.
  final String? prompt;

  /// data URL de SVG inline já sanitizado.
  final String? svg;

  final String reason;
}

class VisualDecisionContext {
  const VisualDecisionContext({
    this.priority = 'background',
    this.allowPaidImages = false,
    this.stableLang,
  });

  final String priority; // 'active' | 'background'
  final bool allowPaidImages;
  final String? stableLang;
}

VisualDecision decideVisualGeneration(
  Map<String, dynamic>? conteudo,
  VisualDecisionContext contexto,
) {
  final vt = conteudo?['visual_trigger'];
  if (vt == null || vt is! Map) {
    return const VisualDecision(
      generate: false,
      prompt: null,
      svg: null,
      reason: 'S12_NO_VISUAL_TRIGGER',
    );
  }
  if (vt['needs_image'] != true) {
    return const VisualDecision(
      generate: false,
      prompt: null,
      svg: null,
      reason: 'S12_NEEDS_IMAGE_FALSE',
    );
  }
  if (vt['pedagogical_need'] == 'none') {
    return const VisualDecision(
      generate: false,
      prompt: null,
      svg: null,
      reason: 'S12_PEDAGOGICAL_NEED_NONE',
    );
  }

  // ── CAMINHO 1: SOFTWARE (SVG inline, custo zero) ──────────────────────────
  if (vt['render_strategy'] == 'software') {
    final svg = sanitizeAndEncodeSvg(vt['svg_payload']);
    if (svg != null) {
      return VisualDecision(
        generate: false,
        prompt: null,
        svg: svg,
        reason: 'S12_SVG_INLINE_OK',
      );
    }
    final softwarePrompt = vt['image_prompt']?.toString().trim() ?? '';
    final softwareTopic = vt['topic']?.toString().trim() ?? '';
    if (softwarePrompt.isNotEmpty ||
        softwareTopic.isNotEmpty ||
        vt['math_template'] != null) {
      return VisualDecision(
        generate: true,
        prompt: softwarePrompt.isNotEmpty ? softwarePrompt : softwareTopic,
        svg: null,
        reason: 'S12_SOFTWARE_ROUTE_FROM_PROMPT',
      );
    }
    // SVG quebrado/ausente → cai no fallback AI abaixo
  }

  // ── CAMINHO 2: AI BLUEPRINT (pago) ────────────────────────────────────────
  if (contexto.priority != 'active') {
    return const VisualDecision(
      generate: false,
      prompt: null,
      svg: null,
      reason: 'S12_BLOCK_PREFETCH_BACKGROUND',
    );
  }
  if (!contexto.allowPaidImages) {
    return const VisualDecision(
      generate: false,
      prompt: null,
      svg: null,
      reason: 'S12_PAID_IMAGES_DISABLED',
    );
  }

  final imagePrompt = vt['image_prompt']?.toString().trim() ?? '';
  if (imagePrompt.isNotEmpty) {
    return VisualDecision(
      generate: true,
      prompt: imagePrompt,
      svg: null,
      reason: 'S12_OK_IMAGE_PROMPT',
    );
  }

  final topic = vt['topic']?.toString().trim() ?? '';
  if (topic.isNotEmpty) {
    final lang =
        contexto.stableLang?.trim() ?? 'the student\'s selected language';
    final prompt =
        'Technical, clean, precise didactic diagram about: $topic. '
        'Use the student\'s selected language ($lang) for any unavoidable visible labels. '
        'Light background, no decorative elements, no extra text.';
    return VisualDecision(
      generate: true,
      prompt: prompt,
      svg: null,
      reason: 'S12_OK_TOPIC_ONLY',
    );
  }

  return const VisualDecision(
    generate: false,
    prompt: null,
    svg: null,
    reason: 'S12_NO_PROMPT_NO_TOPIC',
  );
}
