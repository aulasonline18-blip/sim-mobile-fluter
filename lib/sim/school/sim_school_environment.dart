import 'sim_school_routes.dart';

enum SimDoorKind {
  navigation,
  action,
  serverCall,
  externalLink,
  stateWrite,
  modal,
}

class SimSchoolDoor {
  const SimSchoolDoor({
    required this.id,
    required this.label,
    required this.kind,
    this.destination,
    this.calls = const [],
    this.writes = const [],
    this.requiresAuth = false,
    this.serverOnly = false,
  });

  final String id;
  final String label;
  final SimDoorKind kind;
  final String? destination;
  final List<String> calls;
  final List<String> writes;
  final bool requiresAuth;
  final bool serverOnly;
}

class SimSchoolEnvironment {
  const SimSchoolEnvironment({
    required this.id,
    required this.name,
    required this.route,
    required this.purpose,
    required this.doors,
    this.live = true,
  });

  final String id;
  final String name;
  final String route;
  final String purpose;
  final List<SimSchoolDoor> doors;
  final bool live;
}

const simSchoolEnvironments = <SimSchoolEnvironment>[
  SimSchoolEnvironment(
    id: 'portal',
    name: 'Entrada',
    route: '/',
    purpose: 'Primeiro ambiente: início, créditos, menu e contato com desenvolvedores.',
    doors: [
      SimSchoolDoor(id: 'portal_menu', label: 'Menu', kind: SimDoorKind.modal),
      SimSchoolDoor(id: 'portal_credits', label: 'Créditos', kind: SimDoorKind.navigation, destination: '/creditos'),
      SimSchoolDoor(id: 'portal_login', label: 'Login', kind: SimDoorKind.navigation, destination: '/login'),
      SimSchoolDoor(id: 'portal_start', label: 'Começar', kind: SimDoorKind.navigation, destination: '/cyber/idioma', requiresAuth: true),
      SimSchoolDoor(id: 'portal_whatsapp', label: 'WhatsApp', kind: SimDoorKind.externalLink, destination: 'https://wa.me/message/RLCYEXAYFUIIA1'),
      SimSchoolDoor(id: 'portal_messenger', label: 'Messenger', kind: SimDoorKind.externalLink, destination: 'https://m.me/61557707493807'),
    ],
  ),
  SimSchoolEnvironment(
    id: 'login',
    name: 'Identificação',
    route: '/login',
    purpose: 'Autentica o aluno com Google/Supabase e devolve ao returnTo.',
    doors: [
      SimSchoolDoor(id: 'login_google', label: 'Continuar com Google', kind: SimDoorKind.serverCall, calls: ['supabase.auth.signInWithOAuth']),
      SimSchoolDoor(id: 'login_home', label: 'Voltar', kind: SimDoorKind.navigation, destination: '/'),
      SimSchoolDoor(id: 'login_privacy', label: 'Privacidade', kind: SimDoorKind.navigation, destination: '/privacidade'),
      SimSchoolDoor(id: 'login_terms', label: 'Termos', kind: SimDoorKind.navigation, destination: '/termos'),
    ],
  ),
  SimSchoolEnvironment(
    id: 'language',
    name: 'Idioma',
    route: '/cyber/idioma',
    purpose: 'Define stableLang, idioma, STABLE_LANG e language para app, aula, imagem e áudio.',
    doors: [
      SimSchoolDoor(id: 'language_known', label: 'Escolher idioma conhecido', kind: SimDoorKind.stateWrite, destination: '/cyber/objeto', writes: ['StudentProfileService.draft']),
      SimSchoolDoor(id: 'language_other', label: 'Outro idioma', kind: SimDoorKind.stateWrite, destination: '/cyber/objeto', writes: ['idiomaOutro', 'stableLang']),
    ],
  ),
  SimSchoolEnvironment(
    id: 'objective',
    name: 'Recepção pedagógica',
    route: '/cyber/objeto',
    purpose: 'Recebe objetivo, nome preferido e anexos, cria a entrada viva.',
    doors: [
      SimSchoolDoor(id: 'objective_text', label: 'Campo objetivo', kind: SimDoorKind.stateWrite, writes: ['objetivo', 'student_profile_notes']),
      SimSchoolDoor(id: 'objective_document', label: 'Anexar arquivo', kind: SimDoorKind.serverCall, calls: ['processAttachment']),
      SimSchoolDoor(id: 'objective_camera', label: 'Tirar foto', kind: SimDoorKind.serverCall, calls: ['processAttachment']),
      SimSchoolDoor(id: 'objective_gallery', label: 'Escolher imagem', kind: SimDoorKind.serverCall, calls: ['processAttachment']),
      SimSchoolDoor(id: 'objective_remove_attachment', label: 'Remover anexo', kind: SimDoorKind.action, writes: ['attachments']),
      SimSchoolDoor(id: 'objective_continue', label: 'Salvar e continuar', kind: SimDoorKind.navigation, destination: '/cyber/curriculo', writes: ['lessonLocalId', 'LiveEntry']),
    ],
  ),
  SimSchoolEnvironment(
    id: 'preparation',
    name: 'Preparo',
    route: '/cyber/curriculo',
    purpose: 'Roda T00, perfil, currículo, primeira aula T02 e decide placement ou aula.',
    doors: [
      SimSchoolDoor(id: 'prep_t00', label: 'Preparar currículo', kind: SimDoorKind.serverCall, calls: ['/api/bootstrap-t00']),
      SimSchoolDoor(id: 'prep_first_lesson', label: 'Preparar primeira aula', kind: SimDoorKind.serverCall, calls: ['T02']),
      SimSchoolDoor(id: 'prep_to_placement', label: 'Ir ao nivelamento', kind: SimDoorKind.navigation, destination: '/cyber/placement'),
      SimSchoolDoor(id: 'prep_to_classroom', label: 'Ir à aula', kind: SimDoorKind.navigation, destination: '/cyber/aula'),
      SimSchoolDoor(id: 'prep_buy_credits', label: 'Comprar créditos', kind: SimDoorKind.navigation, destination: '/creditos'),
      SimSchoolDoor(id: 'prep_retry', label: 'Tentar novamente', kind: SimDoorKind.action),
    ],
  ),
  SimSchoolEnvironment(
    id: 'placement',
    name: 'Nivelamento',
    route: '/cyber/placement',
    purpose: 'Opcional: começa do zero ou responde blocos diagnósticos.',
    doors: [
      SimSchoolDoor(id: 'placement_skip', label: 'Começar do zero', kind: SimDoorKind.navigation, destination: '/cyber/aula', writes: ['placement.skipped']),
      SimSchoolDoor(id: 'placement_start', label: 'Fazer nivelamento', kind: SimDoorKind.serverCall, calls: ['callPlacementT02']),
      SimSchoolDoor(id: 'placement_answer', label: 'Responder bloco', kind: SimDoorKind.stateWrite, writes: ['placement.answers']),
      SimSchoolDoor(id: 'placement_continue', label: 'Continuar', kind: SimDoorKind.navigation, destination: '/cyber/aula'),
    ],
  ),
  SimSchoolEnvironment(
    id: 'classroom',
    name: 'Sala de aula',
    route: '/cyber/aula',
    purpose: 'Aula principal: conteúdo, áudio, imagem, pergunta, sinais, dúvida, revisão e recuperação.',
    doors: [
      SimSchoolDoor(id: 'class_menu', label: 'Menu', kind: SimDoorKind.modal),
      SimSchoolDoor(id: 'class_audio', label: 'Áudio', kind: SimDoorKind.action, calls: ['studentLessonMediaService.playLessonAudioSequence']),
      SimSchoolDoor(id: 'class_review', label: 'Revisão', kind: SimDoorKind.modal, calls: ['ReviewRoomService']),
      SimSchoolDoor(id: 'class_answer', label: 'Alternativa A/B/C', kind: SimDoorKind.stateWrite, writes: ['selectedAnswer']),
      SimSchoolDoor(id: 'class_signal_1', label: 'Sinal 1', kind: SimDoorKind.stateWrite, calls: ['StudentLessonExecutor']),
      SimSchoolDoor(id: 'class_signal_2', label: 'Sinal 2', kind: SimDoorKind.stateWrite, calls: ['StudentLessonExecutor']),
      SimSchoolDoor(id: 'class_signal_3', label: 'Sinal 3', kind: SimDoorKind.stateWrite, calls: ['StudentLessonExecutor']),
      SimSchoolDoor(id: 'class_doubt', label: 'Dúvida', kind: SimDoorKind.modal, calls: ['doubtT02Caller']),
      SimSchoolDoor(id: 'class_advance', label: 'Avançar', kind: SimDoorKind.action, calls: ['LearningDecisionEngine']),
      SimSchoolDoor(id: 'class_done', label: 'Fim da aula', kind: SimDoorKind.navigation, destination: '/'),
      SimSchoolDoor(id: 'class_buy_credits', label: 'Comprar créditos', kind: SimDoorKind.navigation, destination: '/creditos'),
    ],
  ),
  SimSchoolEnvironment(
    id: 'drawer',
    name: 'Menu da aula',
    route: '/cyber/aula#drawer',
    purpose: 'Gaveta lateral: histórico, conta, backup, status, créditos e logout.',
    doors: [
      SimSchoolDoor(id: 'drawer_new_lesson', label: 'Nova aula', kind: SimDoorKind.navigation, destination: '/cyber/aula'),
      SimSchoolDoor(id: 'drawer_credits', label: 'Recarregar créditos', kind: SimDoorKind.navigation, destination: '/creditos'),
      SimSchoolDoor(id: 'drawer_open_lesson', label: 'Abrir aula', kind: SimDoorKind.navigation, destination: '/cyber/aula'),
      SimSchoolDoor(id: 'drawer_rename', label: 'Renomear', kind: SimDoorKind.stateWrite, writes: ['StudentLearningState.profile.objetivo']),
      SimSchoolDoor(id: 'drawer_delete', label: 'Apagar', kind: SimDoorKind.serverCall, calls: ['deleteLesson', 'deleteSimLessonByLocalId']),
      SimSchoolDoor(id: 'drawer_export_backup', label: 'Exportar backup', kind: SimDoorKind.action),
      SimSchoolDoor(id: 'drawer_import_backup', label: 'Importar backup', kind: SimDoorKind.action, calls: ['StudentLearningSync.drain']),
      SimSchoolDoor(id: 'drawer_export_status', label: 'Exportar status', kind: SimDoorKind.action, calls: ['fatherPanel.buildStatusReport']),
      SimSchoolDoor(id: 'drawer_logout', label: 'Sair', kind: SimDoorKind.navigation, destination: '/login', calls: ['supabase.auth.signOut']),
      SimSchoolDoor(id: 'drawer_delete_account', label: 'Solicitar exclusão da conta', kind: SimDoorKind.navigation, destination: '/conta/deletar'),
    ],
  ),
  SimSchoolEnvironment(
    id: 'credits',
    name: 'Caixa',
    route: '/creditos',
    purpose: 'Mostra saldo e abre Stripe Hosted Checkout.',
    doors: [
      SimSchoolDoor(id: 'credits_back', label: 'Voltar', kind: SimDoorKind.navigation, destination: '/'),
      SimSchoolDoor(id: 'credits_pack_100', label: '100 créditos', kind: SimDoorKind.externalLink, destination: 'https://checkout.stripe.com/'),
      SimSchoolDoor(id: 'credits_pack_200', label: '200 créditos', kind: SimDoorKind.externalLink, destination: 'https://checkout.stripe.com/'),
      SimSchoolDoor(id: 'credits_pack_500', label: '500 créditos', kind: SimDoorKind.externalLink, destination: 'https://checkout.stripe.com/'),
    ],
  ),
  SimSchoolEnvironment(
    id: 'checkout_return',
    name: 'Retorno do pagamento',
    route: '/checkout/return',
    purpose: 'Confirma pagamento e devolve o aluno ao returnTo salvo.',
    doors: [
      SimSchoolDoor(id: 'checkout_continue', label: 'Continuar aula', kind: SimDoorKind.navigation, destination: '/cyber/aula'),
      SimSchoolDoor(id: 'checkout_retry', label: 'Tentar de novo', kind: SimDoorKind.navigation, destination: '/creditos'),
    ],
  ),
  SimSchoolEnvironment(
    id: 'father_panel',
    name: 'Painel do Pai',
    route: '/pai',
    purpose: 'Supervisão read-only em linguagem humana.',
    doors: [
      SimSchoolDoor(id: 'father_back', label: 'Voltar', kind: SimDoorKind.navigation, destination: '/'),
    ],
  ),
  SimSchoolEnvironment(
    id: 'delete_account',
    name: 'Deletar conta',
    route: '/conta/deletar',
    purpose: 'Solicita exclusão da conta com confirmação DELETAR.',
    doors: [
      SimSchoolDoor(id: 'delete_back', label: 'Voltar', kind: SimDoorKind.navigation, destination: '/'),
      SimSchoolDoor(id: 'delete_submit', label: 'Solicitar exclusão da conta', kind: SimDoorKind.serverCall, calls: ['requestAccountDeletion']),
    ],
  ),
  SimSchoolEnvironment(
    id: 'privacy',
    name: 'Privacidade',
    route: '/privacidade',
    purpose: 'Página legal de privacidade.',
    doors: [SimSchoolDoor(id: 'privacy_back', label: 'Voltar', kind: SimDoorKind.navigation, destination: '/')],
  ),
  SimSchoolEnvironment(
    id: 'terms',
    name: 'Termos',
    route: '/termos',
    purpose: 'Página legal de termos de uso.',
    doors: [SimSchoolDoor(id: 'terms_back', label: 'Voltar', kind: SimDoorKind.navigation, destination: '/')],
  ),
];

List<SimSchoolDoor> allSimSchoolDoors() => [
      for (final environment in simSchoolEnvironments) ...environment.doors,
    ];

List<String> unresolvedInternalDestinations() {
  final paths = simLiveRoutes.map((route) => route.path).toSet();
  return allSimSchoolDoors()
      .map((door) => door.destination)
      .whereType<String>()
      .where((destination) => destination.startsWith('/') && !paths.contains(destination))
      .toSet()
      .toList(growable: false);
}
