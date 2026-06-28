// SIM i18n — chaves PT-BR padrão (§21 da Planta da Interface)
// Se uma chave estiver ausente, mostra a própria chave (espelha comportamento Web).
const Map<String, String> _simStrings = {
  // Portal
  'portal_tagline': 'Smart Intelligence Mentor',
  'portal_statement_p1': 'Aprenda de verdade com',
  'portal_statement_real_learning': 'aprendizagem real',
  'portal_statement_p2': ' — do seu nível ao domínio,',
  'portal_statement_p3': ' com',
  'portal_statement_real_progress': 'progresso real',
  'portal_btn_start': 'Continuar',
  'portal_btn_signin': 'Entrar',
  'portal_help_title': 'Precisa de ajuda?',
  'portal_help_body': 'Fale com a gente pelo WhatsApp ou Messenger.',

  // Login
  'loading': 'Carregando...',

  // Step shell
  'step_label_pedagogica': 'Pedagógica',

  // Idioma
  // (language names are hardcoded in the buttons)

  // Objeto
  'objeto_h1': 'O que você quer estudar?',
  'objeto_card1_title': 'Resumo livre',
  'objeto_helper': 'Escreva com suas palavras. SIM vai montar o currículo ideal.',
  'objeto_save_continue': 'Salvar e continuar',
  'objeto_too_long': 'Texto muito longo',
  'objeto_preferred_name': 'Como você quer ser chamado?',
  'objeto_name_placeholder': 'Ex: João',
  'objetivo_reading': 'Lendo seu objetivo...',

  // Aula / Sala
  'aula_theory': 'TEORIA',
  'aula_review': 'REVISÃO',
  'aula_challenge': 'DESAFIO',
  'aula_image_alt': 'Imagem da aula',
  'aula_gen_fail': 'Não consegui gerar agora.',
  'aula_try_again_2': 'Tentar novamente',
  'aula_next': 'Próximo',
  'aula_next_item': 'Próximo item',
  'aula_consolidate': 'Consolidar',
  'aula_layer_label': 'Nível',
  'aula_sig_certeza': 'Certeza',
  'aula_sig_revisar': 'Revisar',
  'aula_sig_nao_sei': 'Não sei',
  'aula_fb_correct': 'Correto!',
  'aula_fb_correct_rev': 'Correto! Revisando...',
  'aula_fb_dont_know': 'Vamos revisar juntos.',
  'aula_fb_redo': 'Vamos tentar de novo.',
  'aula_fb_review_none': 'Sem revisão necessária.',
  'aula_fb_review_light': 'Pequena revisão.',
  'aula_fb_review_heavy': 'Revisão necessária.',
  'aula_no_curr_h1': 'Currículo não encontrado',
  'aula_no_curr_body': 'Volte e monte um novo currículo.',
  'aula_back_curr': 'Voltar ao currículo',
  'aula_building_layer': 'Construindo camada {n}...',
  'aula_buy_credits': 'Comprar créditos',
  'aula_continue_no_img': 'Continuar sem imagem',
  'aula_img_label': 'Imagem',
  'aula_img_desc': 'Ver imagem desta aula',
  'aula_img_cost': '{n} crédito(s)',
  'aula_img_balance': ' · Saldo: {n}',
  'aula_view_img': 'Ver imagem ({n})',
  'aula_skip': 'Pular',
  'aula_generating_img': 'Gerando imagem...',

  // Revisão
  'aux_review_button': 'Revisão',
  'aux_review_ask_count': 'Quantas questões de revisão?',
  'aux_review_preparing_title': 'Preparando revisão...',
  'aux_review_preparing_msg': 'Selecionando os melhores pontos para revisar.',
  'aux_review_start_cta': 'Começar revisão',
  'aux_review_done_title': 'Revisão concluída!',
  'aux_review_done_msg': 'Ótimo trabalho! Continue assim.',
  'aux_review_continue_cta': 'Continuar',
  'aux_review_fail_back': 'Voltar',

  // Recuperação
  'aux_recovery_intro_msg': 'Identificamos pontos para reforçar.',
  'aux_recovery_preparing_title': 'Preparando recuperação...',
  'aux_recovery_start_cta': 'Começar recuperação',
  'aux_recovery_done_title': 'Recuperação concluída!',
  'aux_recovery_done_msg': 'Você avançou! Continue praticando.',
  'aux_recovery_finish_cta': 'Concluir',

  // Preparação
  'preparing_profile': 'Montando seu perfil...',
  'preparing_curriculum': 'Criando currículo...',
  'preparing_lesson': 'Preparando aula...',
  'preparing_next_lesson': 'Preparando próxima aula...',
  'preparing_short': 'Preparando...',
  'ready_to_continue': 'Pronto! Toque para continuar.',
  'can_skip_when_ready': 'Aguarde — pode pular quando estiver pronto.',
  'prep_msg_1': 'Analisando seu objetivo...',
  'prep_msg_2': 'Identificando seu nível...',
  'prep_msg_3': 'Selecionando conteúdo relevante...',
  'prep_msg_4': 'Estruturando o currículo...',
  'prep_msg_5': 'Adaptando ao seu perfil...',
  'prep_msg_6': 'Organizando os itens...',
  'prep_msg_7': 'Calibrando dificuldade...',
  'prep_msg_8': 'Preparando exemplos práticos...',
  'prep_msg_9': 'Revisando o conteúdo...',
  'prep_msg_10': 'Quase lá...',
  'prep_msg_11': 'Finalizando detalhes...',
  'prep_msg_12': 'Tudo pronto em instantes!',

  // Conclusão
  'done_title': 'Aula concluída!',
  'done_msg_1': 'Você foi incrível hoje.',
  'done_msg_2': 'Continue assim!',
  'done_msg_3': 'Seu progresso está avançando.',
  'done_cta': 'Finalizar',
  'done_hint': 'Toque para voltar ao início.',
  'continue_arrow': 'Continuar →',
  'continue': 'Continuar',

  // Drawer
  'menu': 'MENU',
  'fechar': '✕',
  'nova_aula': 'Nova aula',
  'recarregar_creditos': 'Recarregar créditos',
  'top_up': 'TOP UP',
  'historico': 'HISTÓRICO',
  'historico_vazio': 'Nenhuma aula ainda.',
  'drawer_search_placeholder': 'Buscar aula...',
  'drawer_search_empty': 'Nenhuma aula encontrada.',
  'drawer_load_more': 'Carregar mais',
  'drawer_progress': 'Progresso',
  'drawer_backup_exported': 'Backup exportado!',
  'drawer_status_exported': 'Status exportado!',
  'drawer_uploading_lessons': 'Enviando aulas...',
  'drawer_import_cloud_ok': 'Importação concluída!',
  'drawer_import_cloud_failed': 'Falha na importação.',
  'drawer_delete_cloud_error': 'Erro ao apagar na nuvem.',
  'drawer_delete_error': 'Erro ao apagar.',
  'drawer_delete_account_confirm': 'Confirmação de exclusão enviada.',
  'drawer_rename_error': 'Erro ao renomear.',
  'no_account_lessons': 'Faça login para ver suas aulas.',
  'searching_account': 'Buscando conta...',
  'pending_short': 'pend.',
  'exportar': '⤓ Exportar',
  'importar': '⤒ Importar',
  'status': 'ⓘ Status',
  'logout': 'Logout',
  'confirmar_apagar': 'Apagar esta aula?',
  'apagar': '🗑',
  'renomear': '✎',
  'backup_ok': 'Backup OK!',
  'backup_invalido': 'Backup inválido.',
  'audio_toggle_on': 'Áudio ligado',
  'audio_toggle_off': 'Áudio desligado',
  'curriculo_nao_encontrado': 'Currículo não encontrado.',

  // Placement
  'placement_loading': 'Carregando nivelamento...',
  'placement_label': 'Nivelamento',
  'placement_unavailable': 'Nivelamento não disponível.',
  'placement_choice_h1': 'Como você quer começar?',
  'placement_choice_body': 'Escolha seu ponto de partida.',
  'placement_start_beginning': 'Começar do zero',
  'placement_take_quick': 'Fazer teste rápido',
  'placement_intro_h1': 'Teste rápido de nivelamento',
  'placement_intro_body': 'Algumas perguntas para calibrar seu nível.',
  'placement_start': 'Começar',
  'placement_preparing': 'Preparando...',
  'placement_question_of': 'Questão {n} de {total}',
  'placement_result_h1': 'Resultado do nivelamento',
  'placement_result_body': 'Identificamos seu nível de entrada.',
  'placement_starting_at': 'Você começa em',

  // Créditos
  'pay_pack_lessons_100': '~100 aulas',
  'pay_pack_lessons_200': '~200 aulas',
  'pay_pack_lessons_500': '~500 aulas',
  'pay_checkout_timeout': 'Checkout expirou. Tente novamente.',
};

String t(String key, [Map<String, dynamic>? params]) {
  var value = _simStrings[key] ?? key;
  if (params != null) {
    params.forEach((k, v) {
      value = value.replaceAll('{$k}', '$v');
    });
  }
  return value;
}
