enum SimFinishArea {
  visualFaithfulness,
  buttons,
  texts,
  menus,
  audioPlaybackState,
  imagePresentationState,
  feedbacks,
  realLoading,
  errorStates,
  testableApk,
  androidPhoneTabletAdjustments,
}

class SimFinishRequirement {
  const SimFinishRequirement({
    required this.area,
    required this.label,
    required this.sourceOfTruth,
  });

  final SimFinishArea area;
  final String label;
  final String sourceOfTruth;
}

const simFinishRequirements = <SimFinishRequirement>[
  SimFinishRequirement(
    area: SimFinishArea.visualFaithfulness,
    label: 'Fidelidade visual das telas vivas',
    sourceOfTruth:
        'Portal, Login, Idioma, Objetivo, Curriculo, Placement, Aula',
  ),
  SimFinishRequirement(
    area: SimFinishArea.buttons,
    label: 'Botoes e portas preservados',
    sourceOfTruth: 'Start, Google, anexos, continuar, A/B/C, duvida, audio',
  ),
  SimFinishRequirement(
    area: SimFinishArea.texts,
    label: 'Textos preservados sem trocar funcao',
    sourceOfTruth: 'Textos vivos do fluxo traduzido',
  ),
  SimFinishRequirement(
    area: SimFinishArea.menus,
    label: 'Menus da entrada e aula acessiveis',
    sourceOfTruth: 'Drawer/menu vivo do SIM',
  ),
  SimFinishRequirement(
    area: SimFinishArea.audioPlaybackState,
    label: 'Audio com estado visivel',
    sourceOfTruth: 'useLessonAudioController/audio preference',
  ),
  SimFinishRequirement(
    area: SimFinishArea.imagePresentationState,
    label: 'Imagem com estado visivel',
    sourceOfTruth: 'LessonVisualPipeline/generate lesson image',
  ),
  SimFinishRequirement(
    area: SimFinishArea.feedbacks,
    label: 'Feedbacks de resposta e acoes',
    sourceOfTruth: 'lessonAnswerFeedback/LearningDecisionEngine',
  ),
  SimFinishRequirement(
    area: SimFinishArea.realLoading,
    label: 'Loading real para acoes demoradas',
    sourceOfTruth: 'Auth, anexos, preparo, imagem e audio',
  ),
  SimFinishRequirement(
    area: SimFinishArea.errorStates,
    label: 'Estados de erro visiveis',
    sourceOfTruth: 'Auth, objetivo, anexos, audio, imagem, pagamento',
  ),
  SimFinishRequirement(
    area: SimFinishArea.testableApk,
    label: 'APK debug testavel',
    sourceOfTruth: 'flutter build apk --debug',
  ),
  SimFinishRequirement(
    area: SimFinishArea.androidPhoneTabletAdjustments,
    label: 'Ajustes Android celular/tablet',
    sourceOfTruth: 'SafeArea, scroll, max width, deep link e permissoes',
  ),
];

bool simFinishIsComplete() {
  final covered = simFinishRequirements.map((r) => r.area).toSet();
  return covered.length == SimFinishArea.values.length;
}
