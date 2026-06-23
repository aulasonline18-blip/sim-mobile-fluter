import '../state/student_learning_state.dart';
import '../state/student_learning_state_service.dart';

enum FatherItemStatus { concluido, pendente, avancado, futuro }

class FatherItemView {
  const FatherItemView({
    required this.marker,
    required this.text,
    required this.estado,
  });

  final String marker;
  final String text;
  final FatherItemStatus estado;
}

class ReviewEntry {
  const ReviewEntry({
    required this.marker,
    required this.text,
    required this.addedAt,
    required this.retries,
    required this.kind,
    required this.layer,
    this.signals = const [],
  });

  final String marker;
  final String text;
  final int addedAt;
  final int retries;
  final String kind;
  final LessonLayer layer;
  final List<Object?> signals;
}

class FatherAttemptSummary {
  const FatherAttemptSummary({
    required this.marker,
    required this.layer,
    required this.letra,
    required this.sinal,
    required this.correct,
    required this.ts,
  });

  final String marker;
  final LessonLayer layer;
  final AnswerLetter letra;
  final DecisionSignal sinal;
  final bool correct;
  final int ts;
}

class SignalsSummary {
  const SignalsSummary({
    required this.s1,
    required this.s2,
    required this.s3,
  });

  final int s1;
  final int s2;
  final int s3;
  int get total => s1 + s2 + s3;
}

class FatherSnapshot {
  const FatherSnapshot({
    required this.hasSession,
    required this.takenAt,
    this.objective,
    this.subject,
    this.targetTopic,
    this.academicLevel,
    this.curriculumZone,
    this.preferredName,
    this.examGoal,
    this.language,
    required this.totalItems,
    required this.currentItemIndex,
    this.currentMarker,
    this.currentLayer,
    required this.mainAdvances,
    required this.progressPercent,
    required this.items,
    required this.concluidos,
    required this.pendentes,
    required this.avancados,
    required this.futuros,
    required this.signalsSummary,
    required this.tentativasResumo,
    required this.errorsCount,
    required this.amparoActive,
    required this.amparoLevel,
    required this.upcomingReviews,
    required this.lessonsCount,
    required this.dificuldade,
    required this.pendingMarkers,
    required this.statusText,
  });

  final bool hasSession;
  final int takenAt;
  final String? objective;
  final String? subject;
  final String? targetTopic;
  final String? academicLevel;
  final String? curriculumZone;
  final String? preferredName;
  final String? examGoal;
  final String? language;
  final int totalItems;
  final int currentItemIndex;
  final String? currentMarker;
  final LessonLayer? currentLayer;
  final int mainAdvances;
  final int progressPercent;
  final List<FatherItemView> items;
  final int concluidos;
  final int pendentes;
  final int avancados;
  final int futuros;
  final SignalsSummary signalsSummary;
  final List<FatherAttemptSummary> tentativasResumo;
  final int errorsCount;
  final bool amparoActive;
  final int amparoLevel;
  final List<ReviewEntry> upcomingReviews;
  final int lessonsCount;
  final String dificuldade;
  final List<String> pendingMarkers;
  final String statusText;
}

class FatherPanel {
  const FatherPanel({required this.stateService});

  final StudentLearningStateService stateService;

  Future<FatherSnapshot> snapshot({String? activeLessonLocalId}) async {
    return snapshotSync(activeLessonLocalId: activeLessonLocalId);
  }

  FatherSnapshot snapshotSync({String? activeLessonLocalId}) {
    final ids = stateService.listLessonIds();
    final activeId = activeLessonLocalId ?? (ids.isNotEmpty ? ids.last : null);
    final active = activeId == null ? null : stateService.read(activeId);
    if (active != null && active.curriculum != null) {
      return _snapshotFromState(active, ids.length);
    }
    return _emptySnapshot(lessonsCount: ids.length);
  }

  String buildStatusReport([FatherSnapshot? snapshot]) {
    final s = snapshot ?? snapshotSync();
    final lines = <String>[
      '========================================',
      '   SIM — STATUS PEDAGÓGICO',
      '========================================',
      '',
      'Data            : ${_fmtDate(s.takenAt)}',
    ];
    if (s.preferredName != null) lines.add('Aluno           : ${s.preferredName}');
    if (s.objective != null) lines.add('Objetivo        : ${s.objective}');
    if (s.subject != null) lines.add('Matéria         : ${s.subject}');
    if (s.targetTopic != null) lines.add('Tópico          : ${s.targetTopic}');
    if (s.academicLevel != null) lines.add('Nível/Série     : ${s.academicLevel}');
    if (s.curriculumZone != null) lines.add('Currículo/País  : ${s.curriculumZone}');
    if (s.examGoal != null) lines.add('Meta/Prova      : ${s.examGoal}');
    if (s.language != null) lines.add('Idioma          : ${s.language}');
    lines.addAll([
      '',
      '----------------------------------------',
      'PROGRESSO',
      '----------------------------------------',
      'Total de itens  : ${s.totalItems}',
    ]);
    if (s.currentMarker != null) {
      lines.add('Item atual      : ${s.currentItemIndex + 1}/${s.totalItems}  (${s.currentMarker})');
      lines.add('Camada atual    : ${s.currentLayer?.value ?? '—'}/3');
    }
    lines.addAll([
      'Avanço geral    : ${s.mainAdvances}/${s.totalItems} (${s.progressPercent}%)',
      'Concluídos      : ${s.concluidos}',
      'Avançados       : ${s.avancados}',
      'Pendentes       : ${s.pendentes}',
      'Futuros         : ${s.futuros}',
      '',
      '----------------------------------------',
      'SINAIS DO ALUNO',
      '----------------------------------------',
      'Respondido com segurança (1) : ${s.signalsSummary.s1}',
      'Teve dúvida              (2) : ${s.signalsSummary.s2}',
      'Precisa cuidado futuro   (3) : ${s.signalsSummary.s3}',
      'Erros registrados            : ${s.errorsCount}',
      '',
    ]);
    if (s.tentativasResumo.isNotEmpty) {
      lines.addAll(['----------------------------------------', 'ÚLTIMAS TENTATIVAS', '----------------------------------------']);
      for (final attempt in s.tentativasResumo) {
        final ok = attempt.correct ? 'acertou' : 'errou';
        lines.add(
          '${_fmtDate(attempt.ts)}  ${attempt.marker}  L${attempt.layer.value}  resp ${attempt.letra.name}  $ok  — ${_humanSignalLabel(attempt.sinal)}',
        );
      }
      lines.add('');
    }
    if (s.items.isNotEmpty) {
      lines.addAll(['----------------------------------------', 'CURRÍCULO', '----------------------------------------']);
      for (var i = 0; i < s.items.length; i++) {
        final item = s.items[i];
        final tag = switch (item.estado) {
          FatherItemStatus.concluido => '[CONCLUÍDO]',
          FatherItemStatus.pendente => '[PENDENTE] ',
          FatherItemStatus.avancado => '[AVANÇADO] ',
          FatherItemStatus.futuro => '[FUTURO]   ',
        };
        lines.add('${(i + 1).toString().padLeft(2, '0')}. $tag ${item.marker}  ${item.text}');
      }
      lines.add('');
    }
    if (s.pendentes > 0) {
      lines.add('Observação: há itens marcados como pendentes para revisar depois.');
      lines.add('');
    }
    return lines.join('\n');
  }
}

FatherSnapshot _emptySnapshot({int lessonsCount = 0}) {
  return FatherSnapshot(
    hasSession: false,
    takenAt: DateTime.now().millisecondsSinceEpoch,
    totalItems: 0,
    currentItemIndex: 0,
    mainAdvances: 0,
    progressPercent: 0,
    items: const [],
    concluidos: 0,
    pendentes: 0,
    avancados: 0,
    futuros: 0,
    signalsSummary: const SignalsSummary(s1: 0, s2: 0, s3: 0),
    tentativasResumo: const [],
    errorsCount: 0,
    amparoActive: false,
    amparoLevel: 0,
    upcomingReviews: const [],
    lessonsCount: lessonsCount,
    dificuldade: '—',
    pendingMarkers: const [],
    statusText: 'Sem sessão ativa.',
  );
}

FatherSnapshot _snapshotFromState(StudentLearningState state, int lessonsCount) {
  final profile = state.profile;
  final curriculum = state.curriculum;
  final progress = state.progress;
  final itemsBase = curriculum?.items ?? const <CurriculumItem>[];
  final total = itemsBase.length;
  final idx = (progress?.itemIdx ?? state.current?.itemIdx ?? 0).clamp(0, total == 0 ? 0 : total);
  final layer = progress?.layer ?? state.current?.layer ?? LessonLayer.l1;
  final mainAdvances = (progress?.mainAdvances ?? 0).clamp(0, total == 0 ? 0 : total);
  final pendingSet = Set<String>.from(progress?.pendentesMarkers ?? const []);
  final masteredSet = Set<String>.from(progress?.concluidos ?? const []);
  final items = <FatherItemView>[
    for (var i = 0; i < itemsBase.length; i++)
      FatherItemView(
        marker: itemsBase[i].marker,
        text: itemsBase[i].text,
        estado: pendingSet.contains(itemsBase[i].marker)
            ? FatherItemStatus.pendente
            : masteredSet.contains(itemsBase[i].marker)
                ? FatherItemStatus.concluido
                : i < mainAdvances
                    ? FatherItemStatus.avancado
                    : FatherItemStatus.futuro,
      ),
  ];
  final attempts = state.attempts;
  final s1 = attempts.where((a) => a.sinal == DecisionSignal.one).length;
  final s2 = attempts.where((a) => a.sinal == DecisionSignal.two).length;
  final s3 = attempts.where((a) => a.sinal == DecisionSignal.three).length;
  final currentMarker = idx >= 0 && idx < items.length ? items[idx].marker : null;
  final progressPercent = total == 0 ? 0 : ((mainAdvances / total) * 100).round().clamp(0, 100);
  return FatherSnapshot(
    hasSession: true,
    takenAt: DateTime.now().millisecondsSinceEpoch,
    objective: profile.objetivo,
    subject: profile.extra['subject']?.toString(),
    targetTopic: profile.targetTopic,
    academicLevel: profile.academicLevel ?? profile.nivel,
    curriculumZone: profile.extra['country_or_curriculum']?.toString(),
    preferredName: profile.preferredName,
    examGoal: profile.extra['exam_goal']?.toString(),
    language: profile.stableLang ?? profile.language,
    totalItems: total,
    currentItemIndex: idx,
    currentMarker: currentMarker,
    currentLayer: currentMarker == null ? null : layer,
    mainAdvances: mainAdvances,
    progressPercent: progressPercent,
    items: items,
    concluidos: items.where((item) => item.estado == FatherItemStatus.concluido).length,
    pendentes: items.where((item) => item.estado == FatherItemStatus.pendente).length,
    avancados: items.where((item) => item.estado == FatherItemStatus.avancado).length,
    futuros: items.where((item) => item.estado == FatherItemStatus.futuro).length,
    signalsSummary: SignalsSummary(s1: s1, s2: s2, s3: s3),
    tentativasResumo: attempts
        .skip(attempts.length > 20 ? attempts.length - 20 : 0)
        .map(
          (attempt) => FatherAttemptSummary(
            marker: attempt.marker,
            layer: attempt.layer,
            letra: attempt.letra,
            sinal: attempt.sinal,
            correct: attempt.correct,
            ts: attempt.ts,
          ),
        )
        .toList(growable: false),
    errorsCount: attempts.where((attempt) => !attempt.correct).length,
    amparoActive: (progress?.amparoLvl ?? 0) > 0,
    amparoLevel: progress?.amparoLvl ?? 0,
    upcomingReviews: const [],
    lessonsCount: lessonsCount,
    dificuldade: currentMarker == null ? '—' : 'Camada ${layer.value}/3',
    pendingMarkers: pendingSet.take(12).toList(growable: false),
    statusText: currentMarker == null
        ? 'Sessão pronta — $total itens no currículo'
        : 'Item ${idx + 1}/$total · Camada ${layer.value}/3 · $progressPercent% concluído',
  );
}

String _humanSignalLabel(DecisionSignal signal) {
  return switch (signal) {
    DecisionSignal.one => 'respondido com segurança',
    DecisionSignal.two => 'teve dúvida',
    DecisionSignal.three => 'precisa de cuidado futuro',
  };
}

String _fmtDate(int ts) {
  final date = DateTime.fromMillisecondsSinceEpoch(ts);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} ${two(date.hour)}:${two(date.minute)}';
}
