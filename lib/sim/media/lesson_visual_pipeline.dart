// LessonVisualPipeline — pipeline completo de imagem do SIM App.
// Port fiel do src/cyber/LessonVisualPipeline.ts + S12_VisualPipeline.ts do SIM Web.
import 'package:flutter/foundation.dart';

import 'blueprint_prompt.dart';
import 'lesson_visual_models.dart';
import 's12_visual_pipeline.dart';
import 'visual_router_n2.dart';
import 'visual_router_n3.dart';
import 'image_data_url_compression.dart';
import 'local_visual_fallback.dart';
import 'math_templates/math_templates.dart';

export 's12_visual_pipeline.dart'
    show
        sanitizeAndEncodeSvg,
        decideVisualGeneration,
        VisualDecision,
        VisualDecisionContext;
export 'visual_router_n2.dart'
    show classifyVisualByKeywords, VisualVerdict, VisualN2Result;
export 'visual_router_n3.dart'
    show routeVisualCheapN3, VisualN3Result, LessonVisualRouterClient;

abstract interface class LessonImageClient {
  Future<String?> generateLessonImage({
    required String prompt,
    required String lessonKey,
    String aspectRatio = '1:1',
    String? acceptedOfferId,
    String? idempotencyKey,
  });
}

/// Modelo completo do visual_trigger do T02 (todos os campos do contrato).
class LessonVisualTrigger {
  const LessonVisualTrigger({
    this.needsImage = false,
    this.pedagogicalNeed,
    this.topic,
    this.visualType,
    this.keyElements = const [],
    this.colorLegend = const [],
    this.highlightFocus,
    this.complexity,
    this.imagePrompt,
    this.mathTemplate,
    this.renderStrategy,
    this.svgPayload,
  });

  final bool needsImage;
  final String?
  pedagogicalNeed; // "none" | "helpful" | "important" | "essential"
  final String? topic;
  final String? visualType;
  final List<String> keyElements;
  final List<BlueprintColorLegendItem> colorLegend;
  final String? highlightFocus;
  final String? complexity; // "simple" | "moderate" | "technical"
  final String? imagePrompt;
  final Object? mathTemplate;
  final String? renderStrategy; // "software" | "ai"
  final String? svgPayload;

  factory LessonVisualTrigger.fromJson(Object? value) {
    if (value is! Map) return const LessonVisualTrigger();
    final needs = value['needs_image'] == true || value['needsImage'] == true;
    return LessonVisualTrigger(
      needsImage: needs,
      pedagogicalNeed: value['pedagogical_need']?.toString(),
      topic: value['topic']?.toString(),
      visualType: value['visual_type']?.toString(),
      keyElements: _parseStringList(value['key_elements']),
      colorLegend: colorLegendFromJson(value['color_legend']),
      highlightFocus: value['highlight_focus']?.toString(),
      complexity: value['complexity']?.toString(),
      imagePrompt:
          value['image_prompt']?.toString() ??
          value['teacher_prompt']?.toString() ??
          value['teacherPrompt']?.toString() ??
          value['prompt']?.toString(),
      mathTemplate: value['math_template'],
      renderStrategy:
          value['render_strategy']?.toString() ??
          value['renderStrategy']?.toString(),
      svgPayload: value['svg_payload']?.toString(),
    );
  }

  Map<String, dynamic> toVisualTriggerMap() => {
    'needs_image': needsImage,
    if (pedagogicalNeed != null) 'pedagogical_need': pedagogicalNeed,
    if (topic != null) 'topic': topic,
    if (visualType != null) 'visual_type': visualType,
    if (keyElements.isNotEmpty) 'key_elements': keyElements,
    if (colorLegend.isNotEmpty)
      'color_legend': colorLegend
          .map((c) => {'id': c.id, 'label': c.label, 'color': c.color})
          .toList(),
    if (highlightFocus != null) 'highlight_focus': highlightFocus,
    if (complexity != null) 'complexity': complexity,
    if (imagePrompt != null) 'image_prompt': imagePrompt,
    if (mathTemplate != null) 'math_template': mathTemplate,
    if (renderStrategy != null) 'render_strategy': renderStrategy,
    if (svgPayload != null) 'svg_payload': svgPayload,
  };
}

List<String> _parseStringList(Object? v) {
  if (v is List) return v.map((e) => e.toString()).toList();
  return const [];
}

class LessonVisualPipeline {
  LessonVisualPipeline({
    required this.imageClient,
    required this.visualRouterClient,
  });

  final LessonImageClient imageClient;
  final LessonVisualRouterClient visualRouterClient;

  /// Tenta renderizar usando math template SVG (custo zero).
  /// Retorna data URL do SVG ou null → chamador usa fallback IA.
  String? tryMathTemplate(Object? visualTrigger) {
    return tryRenderMathTemplate(visualTrigger);
  }

  /// Ponto de entrada principal: decide e executa o melhor caminho visual.
  ///
  /// Ordem de prioridade (fiel ao SIM Web):
  ///  1. render_strategy="software" + svg_payload → SVG inline (grátis)
  ///  2. math_template → SVG calculado (grátis)
  ///  3. N2 keyword router → se "svg" → N3 (AI judge) → SVG (grátis)
  ///  4. AI Blueprint → pago, sujeito a gates
  Future<LessonVisualResult> resolveVisual({
    required LessonVisualTrigger trigger,
    required String lessonKey,
    String? stableLang,
    bool allowPaidImages = false,
    String? acceptedOfferId,
    String? idempotencyKey,
  }) async {
    if (!trigger.needsImage || trigger.pedagogicalNeed == 'none') {
      _visualLog(
        lessonKey,
        'skip',
        'needsImage=${trigger.needsImage} pedagogicalNeed=${trigger.pedagogicalNeed}',
      );
      return const LessonVisualResult(svg: null, dataUrl: null, source: 'skip');
    }

    // 1. SVG inline do próprio T02 (render_strategy=software + svg_payload)
    if (trigger.renderStrategy == 'software' && trigger.svgPayload != null) {
      final svgDataUrl = sanitizeAndEncodeSvg(trigger.svgPayload);
      if (svgDataUrl != null) {
        _visualLog(
          lessonKey,
          'svg_inline',
          'accepted len=${trigger.svgPayload?.length ?? 0}',
        );
        return LessonVisualResult(
          svg: svgDataUrl,
          dataUrl: null,
          source: 'svg_inline',
        );
      }
      _visualLog(
        lessonKey,
        'svg_inline',
        'rejected len=${trigger.svgPayload?.length ?? 0}',
      );
    }

    // 2. Math template SVG (kinematics, linear, quadratic, unit circle)
    if (trigger.mathTemplate != null) {
      final mathSvg = tryRenderMathTemplate(trigger.toVisualTriggerMap());
      if (mathSvg != null) {
        _visualLog(
          lessonKey,
          'math_template',
          'accepted name=${_mathTemplateName(trigger.mathTemplate)}',
        );
        return LessonVisualResult(
          svg: mathSvg,
          dataUrl: null,
          source: 'math_template',
        );
      }
      _visualLog(
        lessonKey,
        'math_template',
        'rejected name=${_mathTemplateName(trigger.mathTemplate)}',
      );
    }

    // 3. N2 router — classifica por palavras-chave (custo zero)
    final n2 = classifyVisualByKeywords(
      topic: trigger.topic,
      visualType: trigger.visualType,
      imagePrompt: trigger.imagePrompt,
    );
    _visualLog(
      lessonKey,
      'n2',
      'verdict=${n2.verdict.name} reason=${n2.reason} matched=${n2.matched.take(8).join('|')}',
    );

    if (n2.verdict == VisualVerdict.svg ||
        n2.verdict == VisualVerdict.ambiguous) {
      final n3 = await routeVisualCheapN3(
        client: visualRouterClient,
        n2: n2,
        topic: trigger.topic,
        visualType: trigger.visualType,
        imagePrompt: trigger.imagePrompt,
      );
      _visualLog(
        lessonKey,
        'n3',
        'verdict=${n3.verdict.name} reason=${_shortVisualText(n3.reason)} hasSvg=${n3.svgDataUrl != null}',
      );
      if (n3.verdict == VisualVerdict.svg && n3.svgDataUrl != null) {
        return LessonVisualResult(
          svg: n3.svgDataUrl,
          dataUrl: null,
          source: 'n3_software',
          n2Reason: n2.reason,
        );
      }
    }

    final localSvg = renderLocalVisualFallback(
      n2: n2,
      topic: trigger.topic,
      visualType: trigger.visualType,
      imagePrompt: trigger.imagePrompt,
    );
    if (localSvg != null) {
      _visualLog(
        lessonKey,
        'local_software',
        'delivered after n2=${n2.verdict.name}/${n2.reason}',
      );
      return LessonVisualResult(
        svg: localSvg,
        dataUrl: null,
        source: 'local_software',
        n2Reason: n2.reason,
      );
    }

    if (!allowPaidImages) {
      _visualLog(
        lessonKey,
        'skip_no_paid',
        'n2=${n2.verdict.name}/${n2.reason} allowPaidImages=false topic=${_shortVisualText(trigger.topic)}',
      );
      return const LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'skip_no_paid',
      );
    }
    if (acceptedOfferId == null || acceptedOfferId.trim().isEmpty) {
      _visualLog(
        lessonKey,
        'skip_no_offer',
        'n2=${n2.verdict.name}/${n2.reason} acceptedOfferId=missing topic=${_shortVisualText(trigger.topic)}',
      );
      return const LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'skip_no_offer',
      );
    }

    // 4. AI Blueprint (pago)
    final prompt = buildPromptForTrigger(
      topic: trigger.topic ?? '',
      trigger: trigger,
      lang: stableLang,
    );
    if (prompt.isEmpty) {
      _visualLog(lessonKey, 'skip_no_prompt', 'paid prompt empty');
      return const LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'skip_no_prompt',
      );
    }

    final dataUrl = await fetchPaidLessonImage(
      prompt,
      lessonKey,
      acceptedOfferId: acceptedOfferId,
      idempotencyKey: idempotencyKey ?? acceptedOfferId,
    );
    if (dataUrl == null) {
      _visualLog(
        lessonKey,
        'ai_failed',
        'n2=${n2.verdict.name}/${n2.reason} promptLen=${prompt.length}',
      );
      return LessonVisualResult(
        svg: null,
        dataUrl: null,
        source: 'ai_failed',
        n2Reason: n2.reason,
      );
    }
    _visualLog(
      lessonKey,
      'ai_blueprint',
      'promptLen=${prompt.length} n2=${n2.verdict.name}/${n2.reason}',
    );
    return LessonVisualResult(
      svg: null,
      dataUrl: dataUrl,
      source: 'ai_blueprint',
      n2Reason: n2.reason,
    );
  }

  Future<String?> fetchPaidLessonImage(
    String prompt,
    String lessonKey, {
    String? acceptedOfferId,
    String? idempotencyKey,
  }) async {
    if (prompt.trim().isEmpty) return null;
    if (acceptedOfferId == null || acceptedOfferId.trim().isEmpty) return null;
    final dataUrl = await imageClient.generateLessonImage(
      prompt: prompt,
      lessonKey: lessonKey,
      aspectRatio: '1:1',
      acceptedOfferId: acceptedOfferId,
      idempotencyKey: idempotencyKey ?? acceptedOfferId,
    );
    if (!isUsableImageDataUrl(dataUrl)) return null;
    return compressImageDataUrl(dataUrl!);
  }

  String buildPromptForTrigger({
    required String topic,
    required LessonVisualTrigger trigger,
    String? lang,
  }) {
    final teacherPrompt = trigger.imagePrompt ?? '';
    if (trigger.colorLegend.length >= 2) {
      return buildNaturalImagePrompt(
        topic: topic,
        teacherPrompt: teacherPrompt,
        lang: lang,
        colorLegend: trigger.colorLegend,
      );
    }
    return buildNaturalImagePrompt(
      topic: topic,
      teacherPrompt: teacherPrompt,
      lang: lang,
    );
  }
}

void _visualLog(String lessonKey, String stage, String detail) {
  if (kDebugMode) {
    debugPrint('[VISUAL_PIPELINE] key=$lessonKey stage=$stage $detail');
  }
}

String _mathTemplateName(Object? mathTemplate) {
  if (mathTemplate is Map) {
    return mathTemplate['name']?.toString() ?? '<missing>';
  }
  return mathTemplate == null ? '<null>' : mathTemplate.runtimeType.toString();
}

String _shortVisualText(Object? value) {
  final text = (value ?? '').toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= 160) return text;
  return text.substring(0, 160);
}

class LessonVisualResult {
  const LessonVisualResult({
    required this.svg,
    required this.dataUrl,
    required this.source,
    this.n2Reason,
  });

  /// data URL de SVG inline (grátis) — usar se não nulo.
  final String? svg;

  /// data URL de imagem gerada por IA (Blueprint pago) — usar se svg nulo.
  final String? dataUrl;

  /// Fonte do resultado (para diagnóstico/auditoria).
  final String source;
  final String? n2Reason;

  /// Imagem útil disponível (SVG ou AI)
  bool get hasImage => svg != null || dataUrl != null;

  /// data URL para exibição (prefere SVG)
  String? get displayUrl => svg ?? dataUrl;
}
