// Visual Router — Nível 2 (determinístico, custo zero).
// Port fiel do src/lib/visual-router.functions.ts do SIM Web.
//
// Resolve ~70% dos casos sem chamar IA:
//   - "svg"      → desenhar com math template ou SVG (grátis)
//   - "ai"       → gerar com IA (Blueprint pago)
//   - "ambiguous"→ passar para N3 (AI judge, ~US$0.0001)

import 'package:flutter/foundation.dart';

enum VisualVerdict { svg, ai, ambiguous }

class VisualN2Result {
  const VisualN2Result({
    required this.verdict,
    required this.matched,
    required this.reason,
  });
  final VisualVerdict verdict;
  final List<String> matched;
  final String reason;
}

// ─────────────────────────────────────────────────────────────────────────────
// LISTAS DE PALAVRAS-CHAVE — PT, EN, ES (idiomas mais comuns do SIM).
// ─────────────────────────────────────────────────────────────────────────────

const _svgHints = [
  // matemática / gráficos cartesianos
  'gráfico', 'grafico', 'graph', 'gráfica', 'grafica', 'chart',
  'equação', 'equation', 'ecuación', 'ecuacion',
  'função', 'function', 'función', 'funcion',
  'parábola', 'parabola', 'hipérbole', 'hiperbole', 'hyperbola',
  'reta', 'line ', 'linha', 'linear', 'lineal',
  'plano cartesiano', 'cartesian', 'coordenadas', 'coordinate',
  'eixo', 'eixos', 'axis', 'axes', 'eje',
  'polinômio', 'polinomio', 'polynomial',
  'inequação', 'inequality', 'inecuación',
  'vetor', 'vector', 'vectores', 'vetores',
  'logaritmo', 'logarithm', 'logaritmica', 'logarítmica',
  'exponencial', 'exponential',
  'trigonometria',
  'trigonometry',
  'seno',
  'cosseno',
  'tangente',
  'sine',
  'cosine',
  'probabilidade', 'probability', 'probabilidad',
  'estatística',
  'estatistica',
  'statistics',
  'estadística',
  'histograma',
  'histogram',
  // geometria pura
  'triângulo', 'triangulo', 'triangle', 'triángulo',
  'quadrado', 'square', 'cuadrado', 'retângulo', 'retangulo', 'rectangle',
  'círculo', 'circulo', 'circle',
  'polígono', 'poligono', 'polygon',
  'ângulo', 'angulo', 'angle', 'ángulo',
  'geometria', 'geometry', 'geometría',
  'perímetro', 'perimetro', 'perimeter', 'área', 'area', 'volume',
  'prisma', 'prism', 'pirâmide', 'piramide', 'pyramid', 'cubo', 'cube',
  'esfera', 'sphere', 'cilindro', 'cylinder', 'cone',
  // tabelas e estruturas tabulares
  'tabela', 'table', 'tabla',
  'matriz', 'matrix',
  'tabela periódica', 'tabla periodica', 'periodic table',
  // fluxogramas / diagramas estruturais
  'fluxograma', 'flowchart', 'diagrama de fluxo', 'flujograma', 'diagrama',
  'linha do tempo', 'timeline', 'línea de tiempo',
  'organograma', 'org chart',
  'mapa mental', 'mind map', 'mindmap', 'mapa conceitual', 'concept map',
  'hierarquia', 'hierarchy', 'jerarquía', 'jerarquia',
  'sequência', 'sequencia', 'sequence', 'secuencia',
  'ciclo',
  'cycle',
  'ciclo da água',
  'ciclo do carbono',
  'water cycle',
  'carbon cycle',
  'processo', 'process', 'proceso', 'etapas', 'steps', 'passos',
  'causa e efeito', 'cause and effect', 'causa y efecto',
  'comparação', 'comparacao', 'comparison', 'comparación', 'versus', ' vs ',
  'antes e depois', 'before and after', 'antes y después',
  // fórmulas
  'fórmula', 'formula', 'fórmulas',
  // física esquemática (não realista)
  'força', 'forca', 'force', 'vetorial',
  'circuito',
  'circuit',
  'circuito elétrico',
  'circuito electrico',
  'electrical circuit',
  'polia', 'pulley', 'alavanca', 'lever', 'plano inclinado', 'inclined plane',
  'diagrama de corpo livre', 'free body diagram',
  'movimento uniforme', 'mru', 'mruv', 'queda livre', 'free fall',
  // química esquemática
  'molécula', 'molecula', 'molecule',
  'ligação química', 'ligacao quimica', 'chemical bond',
  'reação', 'reacao', 'reaction', 'reação química', 'reacao quimica',
  'equação química', 'equacao quimica', 'chemical equation',
  // biologia/anatomia ESQUEMÁTICA
  'esquema', 'schematic', 'diagrama de', 'diagrama del',
  'cadeia alimentar', 'food chain', 'cadena alimentaria',
  'ciclo de vida', 'life cycle', 'ciclo celular esquemático',
  'dna esquema', 'dna diagram', 'rna diagram',
  // gramática / linguística
  'conjugação', 'conjugacao', 'conjugation',
  'verbo', 'verb', 'tempo verbal', 'verb tense',
  'sintaxe', 'syntax', 'análise sintática', 'analise sintatica',
  'morfologia', 'morphology',
  'tabela verbal', 'verb table',
  'árvore sintática', 'arvore sintatica', 'syntax tree',
  // mapas conceituais
  'diagrama de venn', 'venn diagram',
  'infográfico estrutural', 'estrutura de', 'structure of',
];

const _aiHints = [
  // anatomia / biologia orgânica REALISTA
  'anatomia realista', 'realistic anatomy',
  'corte anatômico', 'anatomical cross-section', 'anatomical section',
  'órgão humano', 'human organ', 'órgãos humanos', 'human organs',
  'coração humano', 'human heart',
  'pulmão humano', 'human lung',
  'estômago realista',
  'fígado realista',
  'cérebro realista', 'realistic brain',
  'musculatura', 'musculature',
  'esqueleto humano', 'human skeleton',
  'tecido biológico', 'biological tissue',
  'histologia', 'histology',
  'célula realista', 'realistic cell',
  // realismo / foto / paisagem / fauna
  'foto',
  'photo',
  'fotografia',
  'photograph',
  'photorealistic',
  'fotorrealista',
  'paisagem', 'landscape', 'paisaje',
  'animal realista', 'realistic animal',
  'planta realista', 'realistic plant',
  'flor realista', 'realistic flower',
  'ecossistema realista', 'realistic ecosystem',
  // arte / mapa físico
  'ilustração artística', 'artistic illustration',
  'pintura', 'painting', 'óleo sobre tela', 'watercolor', 'aquarela',
  'mapa físico', 'physical map', 'relevo', 'relief map',
  'cena histórica', 'historical scene', 'escena histórica',
  'retrato', 'portrait', 'rosto humano', 'human face',
];

// Biologia orgânica — SEMPRE vai para IA (SVG não renderiza órgão/célula com dignidade pedagógica)
const _organicHints = [
  'célula',
  'celula',
  'cell',
  'células',
  'celulas',
  'cells',
  'organela',
  'organelas',
  'organelle',
  'organelles',
  'mitocôndria',
  'mitocondria',
  'mitochondria',
  'mitochondrion',
  'núcleo celular',
  'nucleo celular',
  'cell nucleus',
  'nucléolo',
  'nucleolo',
  'membrana celular',
  'cell membrane',
  'membrana plasmática',
  'membrana plasmatica',
  'citoplasma',
  'cytoplasm',
  'ribossomo',
  'ribosome',
  'lisossomo',
  'lysosome',
  'retículo endoplasmático',
  'reticulo endoplasmatico',
  'endoplasmic reticulum',
  'complexo de golgi',
  'golgi',
  'cloroplasto',
  'chloroplast',
  'ciclo celular',
  'cell cycle',
  'mitose',
  'mitosis',
  'meiose',
  'meiosis',
  'dna',
  'rna',
  'cromossomo',
  'chromosome',
  'tecido',
  'tecidos',
  'tissue',
  'tissues',
  'histologia',
  'histology',
  'microscopia',
  'microscopy',
  'microscópio',
  'microscopio',
  'órgão',
  'orgao',
  'órgãos',
  'orgaos',
  'organ',
  'organs',
  'coração',
  'coracao',
  'heart',
  'pulmão',
  'pulmao',
  'pulmões',
  'pulmoes',
  'lung',
  'lungs',
  'estômago',
  'estomago',
  'stomach',
  'intestino',
  'intestine',
  'intestino delgado',
  'intestino grosso',
  'fígado',
  'figado',
  'liver',
  'rim',
  'rins',
  'kidney',
  'kidneys',
  'cérebro',
  'cerebro',
  'brain',
  'neurônio',
  'neuronio',
  'neuron',
  'sistema digestivo',
  'digestive system',
  'sistema digestório',
  'digestorio',
  'sistema respiratório',
  'respiratorio',
  'respiratory system',
  'sistema circulatório',
  'circulatorio',
  'circulatory system',
  'sistema nervoso',
  'nervous system',
  'sistema reprodutor',
  'reproductive system',
  'sistema urinário',
  'urinario',
  'urinary system',
  'sistema imunológico',
  'imunologico',
  'immune system',
  'sistema endócrino',
  'endocrino',
  'endocrine system',
  'esqueleto',
  'skeleton',
  'osso',
  'ossos',
  'bone',
  'bones',
  'músculo',
  'musculo',
  'muscle',
  'muscles',
  'musculatura',
  'pele',
  'skin',
  'derme',
  'epiderme',
  'corpo humano',
  'human body',
  'anatomia',
  'anatomy',
  'digestão',
  'digestao',
  'digestion',
  'respiração',
  'respiracao',
  'respiration',
  'breathing',
  'fotossíntese',
  'fotossintese',
  'photosynthesis',
  'circulação sanguínea',
  'circulacao sanguinea',
  'blood circulation',
  'biologia',
  'biology',
  'biológico',
  'biologico',
  'biological',
  'planta',
  'plant',
  'raiz',
  'root',
  'caule',
  'folha',
  'leaf',
  'animal',
  'animais',
  'fauna',
  'flora',
  'bactéria',
  'bacteria',
  'vírus',
  'virus',
  'fungo',
  'fungus',
];

// Domínios onde SVG é OBRIGATÓRIO (física/matemática/química/lógica)
const _lockedSvgSubjects = [
  'newton',
  'primeira lei',
  'segunda lei',
  'terceira lei',
  'first law',
  'second law',
  'third law',
  'inércia',
  'inercia',
  'inertia',
  'força resultante',
  'forca resultante',
  'resultant force',
  'net force',
  'ação e reação',
  'acao e reacao',
  'action and reaction',
  'queda livre',
  'free fall',
  'caída libre',
  'movimento retilíneo',
  'movimento retilineo',
  'rectilinear motion',
  'movimento uniforme',
  'uniform motion',
  'velocidade constante',
  'constant velocity',
  'velocidad constante',
  'aceleração',
  'aceleracao',
  'acceleration',
  'aceleración',
  'lançamento',
  'lancamento',
  'projectile',
  'lanzamiento',
  'atrito',
  'friction',
  'fricción',
  'friccion',
  'peso',
  'weight',
  'massa',
  'mass',
  'gravidade',
  'gravity',
  'energia cinética',
  'energia cinetica',
  'kinetic energy',
  'energia potencial',
  'potential energy',
  'trabalho mecânico',
  'trabalho mecanico',
  'mechanical work',
  'potência mecânica',
  'potencia mecanica',
  'mechanical power',
  'momento linear',
  'linear momentum',
  'impulso',
  'impulse',
  'torque',
  'momento de força',
  'momento de forca',
  'mola',
  'spring',
  'hooke',
  'pêndulo',
  'pendulo',
  'pendulum',
  'ondas',
  'waves',
  'frequência',
  'frequencia',
  'frequency',
  'refração',
  'refracao',
  'refraction',
  'reflexão',
  'reflexao',
  'reflection',
  'lentes',
  'lens',
  'espelho',
  'mirror',
  'corrente elétrica',
  'corrente eletrica',
  'electric current',
  'tensão elétrica',
  'tensao eletrica',
  'voltage',
  'voltaje',
  'resistência elétrica',
  'resistencia eletrica',
  'electrical resistance',
  'lei de ohm',
  "ohm's law",
  'ley de ohm',
  'álgebra',
  'algebra',
  'cálculo',
  'calculo',
  'calculus',
  'derivada',
  'derivative',
  'integral',
  'integration',
  'limite',
  'limit',
  'matemática financeira',
  'matematica financeira',
  'financial math',
  'juros',
  'interest',
  'interés',
  'tabela periódica',
  'tabla periodica',
  'periodic table',
  'ligação iônica',
  'ligacao ionica',
  'ionic bond',
  'ligação covalente',
  'ligacao covalente',
  'covalent bond',
  'lewis',
  'estrutura de lewis',
  'lewis structure',
  'balanceamento',
  'balancing',
  'estequiometria',
  'stoichiometry',
  'ph',
  'ácido',
  'acido',
  'acid',
  'base',
  'alkali',
  'tabela verdade',
  'truth table',
  'tabla de verdad',
  'circuito lógico',
  'circuito logico',
  'logic circuit',
  'máquina de estados',
  'maquina de estados',
  'state machine',
  'algoritmo',
  'algorithm',
  'algoritmo de',
];

const _photoRealismEscape = [
  'foto realista',
  'realistic photo',
  'fotorrealista',
  'photorealistic',
  'real photograph',
  'fotografía real',
  'fotografia real',
  'imagem real de',
  'imagem fotográfica',
  'imagem fotografica',
];

VisualN2Result classifyVisualByKeywords({
  String? topic,
  String? visualType,
  String? imagePrompt,
}) {
  final parts = [
    topic,
    visualType,
    imagePrompt,
  ].where((x) => x != null && x.isNotEmpty).join(' ').toLowerCase();

  if (parts.trim().isEmpty) {
    return _withN2Log(
      const VisualN2Result(
        verdict: VisualVerdict.ambiguous,
        matched: [],
        reason: 'N2_EMPTY_INPUT',
      ),
      topic: topic,
      visualType: visualType,
      imagePrompt: imagePrompt,
    );
  }

  final vt = (visualType ?? '').toLowerCase();
  // Sinais fortíssimos do próprio T02:
  if (vt == 'anatomy') {
    return _withN2Log(
      const VisualN2Result(
        verdict: VisualVerdict.ai,
        matched: ['visual_type=anatomy'],
        reason: 'N2_HARD_AI_ANATOMY',
      ),
      topic: topic,
      visualType: visualType,
      imagePrompt: imagePrompt,
    );
  }

  // LOCK DE DOMÍNIO: física/matemática/química/lógica → SVG obrigatório
  final photoEscape = _photoRealismEscape.any((k) => _matchesHint(parts, k));
  final lockedHits = _lockedSvgSubjects
      .where((k) => _matchesHint(parts, k))
      .take(5)
      .toList();
  if (lockedHits.isNotEmpty && !photoEscape) {
    return _withN2Log(
      VisualN2Result(
        verdict: VisualVerdict.svg,
        matched: lockedHits,
        reason: 'N2_LOCKED_DOMAIN_SVG',
      ),
      topic: topic,
      visualType: visualType,
      imagePrompt: imagePrompt,
    );
  }

  // OVERRIDE: conteúdo orgânico/biológico/anatômico SEMPRE vai para IA
  final organicHits = _organicHints
      .where((k) => _matchesHint(parts, k))
      .toList();
  if (organicHits.isNotEmpty) {
    return _withN2Log(
      VisualN2Result(
        verdict: VisualVerdict.ai,
        matched: organicHits,
        reason: 'N2_ORGANIC_OVERRIDE_AI',
      ),
      topic: topic,
      visualType: visualType,
      imagePrompt: imagePrompt,
    );
  }

  if (vt == 'graph' || vt == 'geometry') {
    return _withN2Log(
      VisualN2Result(
        verdict: VisualVerdict.svg,
        matched: ['visual_type=$vt'],
        reason: 'N2_HARD_SVG_VISUAL_TYPE',
      ),
      topic: topic,
      visualType: visualType,
      imagePrompt: imagePrompt,
    );
  }

  final svgHits = _svgHints.where((k) => _matchesHint(parts, k)).toList();
  final aiHits = _aiHints.where((k) => _matchesHint(parts, k)).toList();

  if (svgHits.isNotEmpty && aiHits.isEmpty) {
    return _withN2Log(
      VisualN2Result(
        verdict: VisualVerdict.svg,
        matched: svgHits,
        reason: 'N2_KEYWORDS_SVG',
      ),
      topic: topic,
      visualType: visualType,
      imagePrompt: imagePrompt,
    );
  }
  if (aiHits.isNotEmpty && svgHits.isEmpty) {
    return _withN2Log(
      VisualN2Result(
        verdict: VisualVerdict.ai,
        matched: aiHits,
        reason: 'N2_KEYWORDS_AI',
      ),
      topic: topic,
      visualType: visualType,
      imagePrompt: imagePrompt,
    );
  }
  if (svgHits.isNotEmpty && aiHits.isNotEmpty) {
    return _withN2Log(
      VisualN2Result(
        verdict: VisualVerdict.ambiguous,
        matched: [...svgHits, ...aiHits],
        reason: 'N2_KEYWORDS_BOTH',
      ),
      topic: topic,
      visualType: visualType,
      imagePrompt: imagePrompt,
    );
  }
  return _withN2Log(
    const VisualN2Result(
      verdict: VisualVerdict.ambiguous,
      matched: [],
      reason: 'N2_NO_KEYWORDS',
    ),
    topic: topic,
    visualType: visualType,
    imagePrompt: imagePrompt,
  );
}

VisualN2Result _withN2Log(
  VisualN2Result result, {
  String? topic,
  String? visualType,
  String? imagePrompt,
}) {
  if (kDebugMode) {
    debugPrint(
      '[VISUAL_N2] verdict=${result.verdict.name} '
      'reason=${result.reason} matched=${result.matched.take(8).join('|')} '
      'topic="${_shortN2Text(topic)}" visualType="${_shortN2Text(visualType)}" '
      'imagePrompt="${_shortN2Text(imagePrompt)}"',
    );
  }
  return result;
}

String _shortN2Text(String? value) {
  final text = (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
  if (text.length <= 80) return text;
  return text.substring(0, 80);
}

bool _matchesHint(String text, String hint) {
  final normalized = hint.trim().toLowerCase();
  if (normalized.isEmpty) return false;
  if (normalized.length <= 2 && RegExp(r'^[a-z0-9]+$').hasMatch(normalized)) {
    return RegExp(
      '(^|[^a-z0-9])${RegExp.escape(normalized)}([^a-z0-9]|\$)',
    ).hasMatch(text);
  }
  return text.contains(hint);
}
