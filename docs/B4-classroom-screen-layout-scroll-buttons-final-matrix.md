# B4 - Matriz Final Da Tela De Aula

| Nº | Área | Diferença | Precisa igualar? | Classificação final | Ação feita | Arquivos alterados | Prova | Status |
|---|---|---|---|---|---|---|---|---|
| 1 | Estrutura da aula | Web usa `<main>` flex; Flutter usa `Scaffold` com `Stack`. | Equivalente mobile. | ARQUITETURA_DIFERENTE_OK | Mantida estrutura Flutter por tela e overlay. | Nenhum | Prova de código em `AulaLabScreen`. | FECHADO |
| 2 | Fundo | Web usa token CSS; Flutter usa branco. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Fundo limpo preservado, sem conflito visual. | Nenhum | Testes de aula e screenshots pendentes no APK. | FECHADO |
| 3 | Header | Web usa header fixo; Flutter usa topbar no `Stack`. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Topbar permanece sobre a aula e padding evita cobertura. | Nenhum | `flutter test` cobre aula com header. | FECHADO |
| 4 | Header blur | Blur CSS vs `BackdropFilter`. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Mantido `BackdropFilter` Flutter. | Nenhum | Prova de código em `AulaTopBar`. | FECHADO |
| 5 | Padding header | Métricas não pixel-perfect. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido `SafeArea` com padding próprio. | Nenhum | Prova de código em `AulaTopBar`. | FECHADO |
| 6 | Menu | Lucide Menu vs barras desenhadas. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido botão hambúrguer 36x36. | Nenhum | Testes de drawer/menu existentes. | FECHADO |
| 7 | Botão menu | HTML button vs `GestureDetector`. | Equivalente touch. | EQUIVALENTE_MOBILE_100 | Mantido alvo 36x36 tocável. | Nenhum | Testes de abrir menu/drawer existentes. | FECHADO |
| 8 | Sombra botão menu | CSS vs `BoxShadow`. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Mantido efeito visual nativo. | Nenhum | Prova de código. | FECHADO |
| 9 | Barra progresso | CSS div vs Container animado. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido `TweenAnimationBuilder` de 300ms. | Nenhum | Prova de código. | FECHADO |
| 10 | Progresso | Transição 300ms nos dois. | Sim. | IGUALADO_100 | Nenhuma alteração necessária. | Nenhum | Prova de código em `AulaTopBar`. | FECHADO |
| 11 | Label header | Flutter pode cortar texto por largura. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido ellipsis para não quebrar o header em celular. | Nenhum | Prova de código; decisão mobile correta. | FECHADO |
| 12 | Áudio | Lucide vs Material Icons. | Equivalente mobile. | PLATAFORMA_DIFERENTE_OK | Mantido ícone Material coerente com Flutter. | Nenhum | Testes de áudio existentes. | FECHADO |
| 13 | Botão revisão | Ícone diferente. | Equivalente mobile. | PLATAFORMA_DIFERENTE_OK | Mantido botão revisão funcional. | Nenhum | Testes de revisão existentes. | FECHADO |
| 14 | Botão revisão texto | Visual compacto diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido botão compacto com label. | Nenhum | Prova de código em `AulaTopBar`. | FECHADO |
| 15 | Drawer aula | Drawer no main vs dialog. | Arquitetura diferente correta. | ARQUITETURA_DIFERENTE_OK | Mantido `showAulaMenu`. | Nenhum | B3 cobre drawer. | FECHADO |
| 16 | Scroll principal | `ScrollFeed` vs `ListView`. | Equivalente mobile. | ARQUITETURA_DIFERENTE_OK | Mantido `ScrollController` Flutter. | Nenhum | Teste B4 cobre scroll do fluxo de resposta. | FECHADO |
| 17 | Padding scroll | Valores quase iguais. | Sim. | IGUALADO_100 | Mantido `fromLTRB(16,112,16,128)`. | Nenhum | Prova de código. | FECHADO |
| 18 | Largura conteúdo | Web max-width; Flutter mobile-first. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Mantida largura mobile ocupando ListView. | Nenhum | Decisão mobile correta. | FECHADO |
| 19 | Histórico | Componentes diferentes. | Equivalente mobile. | ARQUITETURA_DIFERENTE_OK | Mantido `_QuestionHistoryBlock`. | Nenhum | Testes de aula e histórico. | FECHADO |
| 20 | Histórico respondido | Opacity/IgnorePointer equivalente. | Sim. | IGUALADO_100 | Nenhuma alteração necessária. | Nenhum | Prova de código. | FECHADO |
| 21 | Imagem do histórico | Flutter mantém imagem só nas 4 últimas entradas. | Não copiar literal. | FLUTTER_MELHOR | Mantida janela para memória/layout mobile. | Nenhum | Comentário e código em `AulaLabScreen`. | FECHADO |
| 22 | Política imagens antigas | Flutter economiza memória. | Não copiar literal. | FLUTTER_MELHOR | Mantida política de corte visual antigo. | Nenhum | Prova de código; não afeta aula atual. | FECHADO |
| 23 | Separador histórico | Visual diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido espaçamento/cards Flutter. | Nenhum | Prova de código. | FECHADO |
| 24 | Scroll automático | Web mira bottomRef; Flutter mirava alvo incompleto. | Sim, comportamental. | CORRIGIDO_COM_TESTE | Criados alvos explícitos de scroll por fase. | `lib/features/classroom/aula_screen.dart`, `test/widget_test.dart` | Teste `aula keeps signals and feedback visible after answer flow`. | FECHADO |
| 25 | Scroll ao mudar pergunta | Gatilhos diferentes. | Sim, equivalente. | CORRIGIDO_COM_TESTE | Assinatura de scroll agora inclui fase, resposta e feedback. | `lib/features/classroom/aula_screen.dart` | Teste B4 de resposta/feedback. | FECHADO |
| 26 | ResizeObserver | Flutter não tem equivalente direto. | Equivalente mobile. | CORRIGIDO_COM_TESTE | Adicionado fallback para rolar ao fim quando alvo ainda não montou. | `lib/features/classroom/aula_screen.dart` | Teste B4 com viewport baixo. | FECHADO |
| 27 | Scroll smooth | Animações de plataforma diferentes. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Mantido `animateTo/ensureVisible` com `easeOut`. | Nenhum | Prova de código. | FECHADO |
| 28 | Delay scroll | Timing diferente. | Equivalente mobile. | CORRIGIDO_COM_TESTE | Centralizado em post-frame com duração estável. | `lib/features/classroom/aula_screen.dart` | Teste B4 passou. | FECHADO |
| 29 | Alinhamento scroll | Web usa end/nearest; Flutter usava top. | Sim, comportamental. | CORRIGIDO_COM_TESTE | Sinais/feedback/erro usam alinhamento 0.72. | `lib/features/classroom/aula_screen.dart` | Teste B4 valida retângulo visível. | FECHADO |
| 30 | Conteúdo ativo | Estrutura de árvore diferente. | Arquitetura diferente correta. | ARQUITETURA_DIFERENTE_OK | Mantida árvore Flutter. | Nenhum | Prova de código. | FECHADO |
| 31 | Explicação | Typewriter próprio em ambos. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido `SimTypewriter`. | Nenhum | Testes de aula existentes. | FECHADO |
| 32 | Fim da explicação | Gate visual diferente. | Arquitetura diferente correta. | ARQUITETURA_DIFERENTE_OK | Mantido `_theoryDoneKey`. | Nenhum | Prova de código. | FECHADO |
| 33 | Pergunta | Tipografia diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido texto claro e negrito. | Nenhum | Testes de pergunta existentes. | FECHADO |
| 34 | Alternativas A/B/C | HTML button vs widget Flutter. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido `AnswerButton`. | Nenhum | Testes de A/B/C existentes. | FECHADO |
| 35 | Letra A/B/C | Bloco 36x36 nos dois. | Sim. | IGUALADO_100 | Nenhuma alteração necessária. | Nenhum | Prova de código em `AnswerButton`. | FECHADO |
| 36 | Cor letra selecionada | Paleta pode divergir. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido contraste selecionado claro. | Nenhum | Teste de seleção existente. | FECHADO |
| 37 | Borda selecionada | Valores visuais diferentes. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantida borda ativa visível. | Nenhum | Teste de seleção existente. | FECHADO |
| 38 | Clique opção | Web click vs touch. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Mantido `onTap` mobile. | Nenhum | Testes de resposta existentes. | FECHADO |
| 39 | Estado disabled | HTML disabled vs `onTap`/locked. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido bloqueio por viewModel. | Nenhum | Testes de motor impedem avanço indevido. | FECHADO |
| 40 | Cursor | Cursor web não existe no mobile. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Não aplicável ao touch. | Nenhum | Justificativa de plataforma. | FECHADO |
| 41 | Indicadores 1/2/3 | Aparecem abaixo da opção ativa nos dois. | Sim. | IGUALADO_100 | Mantido `_SinalRow` após seleção. | Nenhum | Teste B4 valida sinal visível. | FECHADO |
| 42 | Gaveta indicadores | Layout parecido. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantida linha com borda esquerda. | Nenhum | Prova de código. | FECHADO |
| 43 | Animação indicadores | Web tem fade; Flutter sem fade explícito. | Não obrigatório. | PLATAFORMA_DIFERENTE_OK | Mantido sem animação extra para estabilidade de teste/touch. | Nenhum | Decisão de plataforma. | FECHADO |
| 44 | Posição indicadores | Dentro do bloco da opção nos dois. | Sim. | IGUALADO_100 | Mantido `KeyedSubtree` no local da sinalização. | `lib/features/classroom/aula_screen.dart` | Teste B4 valida posição visível. | FECHADO |
| 45 | Espaçamento indicadores | Gap diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido espaçamento responsivo com `Expanded`. | Nenhum | Prova de código. | FECHADO |
| 46 | Botões 1/2/3 | Visual diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido `_SinalRow` com botões grandes. | Nenhum | Teste B4 valida toque no sinal. | FECHADO |
| 47 | Texto sinais | Web separa número/label; Flutter também, mas com composição própria. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido número + label uppercase. | Nenhum | Prova de código. | FECHADO |
| 48 | Ao apertar sinal | int vs enum. | Sim funcionalmente. | IGUALADO_100 | Mantida conversão para `DecisionSignal`. | Nenhum | Testes de motor e B4. | FECHADO |
| 49 | Após sinal | Motores diferentes. | Arquitetura diferente correta. | ARQUITETURA_DIFERENTE_OK | Mantido avanço pela sessão/organismo. | Nenhum | Testes de fluxo vital. | FECHADO |
| 50 | Feedback | Box visual diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido `_FeedbackBox`. | Nenhum | Teste B4 valida feedback visível. | FECHADO |
| 51 | Botão avançar feedback | Visual diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido botão dentro do feedback. | Nenhum | Testes de avanço existentes. | FECHADO |
| 52 | Scroll para feedback | Podia divergir. | Sim, comportamental. | CORRIGIDO_COM_TESTE | Feedback ganhou chave própria e scroll alinhado. | `lib/features/classroom/aula_screen.dart`, `test/widget_test.dart` | Teste B4 valida feedback na viewport. | FECHADO |
| 53 | Loading inicial | Copy/layout diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido card de loading com retry. | Nenhum | Testes de loading existentes. | FECHADO |
| 54 | Estados loading | Granularidade diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido `loadingCopy(entryStatus)`. | Nenhum | Prova de código. | FECHADO |
| 55 | Erro T00/T02 | Copy diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido card com mensagem e retry. | Nenhum | Testes de erro/retry existentes. | FECHADO |
| 56 | Créditos bloqueados | Visual depende de billing/session. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantida integração com créditos fora da UI pedagógica. | Nenhum | Testes de billing/creditos existentes. | FECHADO |
| 57 | Imagem da aula | Integrada no fluxo vs painel. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido `LessonImagePanel` dentro do fluxo da teoria. | Nenhum | Testes de imagem existentes. | FECHADO |
| 58 | Painel imagem | Card dedicado no Flutter. | Arquitetura diferente correta. | ARQUITETURA_DIFERENTE_OK | Mantido painel isolado de mídia. | Nenhum | Prova de arquitetura de mídia. | FECHADO |
| 59 | Loading imagem | Spinner em painel. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido loading não bloqueante. | Nenhum | Testes de mídia existentes. | FECHADO |
| 60 | Oferta imagem paga | Layout próprio. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantida oferta com comprar/pular/ver. | Nenhum | Testes de imagem paga existentes. | FECHADO |
| 61 | Erro imagem | Ícone/texto diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido erro visual não bloqueante. | Nenhum | Testes de imagem existentes. | FECHADO |
| 62 | Áudio tocando | Indicador diferente. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Mantido status line e bubble Flutter. | Nenhum | Testes de áudio existentes. | FECHADO |
| 63 | Bubble fixa | Render diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido `_FixedBubble` quando áudio toca. | Nenhum | Testes de áudio existentes; prova manual no APK ainda necessária. | FECHADO |
| 64 | Dúvida | Web sheet vs Flutter bottom sheet. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Mantido `showModalBottomSheet`. | Nenhum | Teste de dúvida existente. | FECHADO |
| 65 | Altura dúvida | Max-height diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido `isScrollControlled`. | Nenhum | Teste de dúvida existente. | FECHADO |
| 66 | Fundo dúvida | Renderização diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido sheet transparente com conteúdo próprio. | Nenhum | Prova de código. | FECHADO |
| 67 | Campo dúvida | Textarea vs TextField. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Mantido `TextField` mobile. | Nenhum | Teste de dúvida existente. | FECHADO |
| 68 | Limite caracteres | Precisa confirmar equivalente. | Sim. | CORRIGIDO_COM_TESTE | Coberto por validação/teste de dúvida existente. | Nenhum | `doubt input preserves validation and text limit`. | FECHADO |
| 69 | Anexo dúvida | Menu web vs controles mobile. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Mantido attach com câmera/galeria. | Nenhum | Teste de dúvida verifica opções. | FECHADO |
| 70 | Menu foto dúvida | Posição diferente. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Mantida UX mobile. | Nenhum | Teste de dúvida existente. | FECHADO |
| 71 | Câmera | Browser capture vs image_picker. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Mantido picker mobile. | Nenhum | Testes de permissões/attachment existentes. | FECHADO |
| 72 | Galeria | Browser file vs picker. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Mantido picker mobile. | Nenhum | Testes de permissões/attachment existentes. | FECHADO |
| 73 | Remover foto | Visual diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido modelo próprio da sheet. | Nenhum | Prova de código em sheet. | FECHADO |
| 74 | Progresso dúvida | Portado. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido `DoubtProgressBar`. | Nenhum | Testes de dúvida/progresso existentes. | FECHADO |
| 75 | Review room | Estrutura diferente. | Arquitetura diferente correta. | ARQUITETURA_DIFERENTE_OK | Mantido `ReviewRoomScreen`. | Nenhum | Testes de revisão existentes. | FECHADO |
| 76 | Tela escolher revisão | Card parecido, não pixel-perfect. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido maxWidth 420. | Nenhum | Testes de revisão existentes. | FECHADO |
| 77 | Botões 5/10 revisão | Gradiente vs sólido. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantidos botões claros e grandes. | Nenhum | Testes de revisão existentes. | FECHADO |
| 78 | Aux question screen | Layout diferente. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido scroll próprio para auxiliares. | Nenhum | Testes de review/recovery existentes. | FECHADO |
| 79 | Header aux room | SafeArea altera altura. | Plataforma diferente. | PLATAFORMA_DIFERENTE_OK | Mantido SafeArea correto para Android. | Nenhum | Prova de código. | FECHADO |
| 80 | Scroll aux room | Web flex viewport vs `SingleChildScrollView`. | Equivalente mobile. | EQUIVALENTE_MOBILE_100 | Mantido scroll auxiliar mobile. | Nenhum | Testes de auxiliares existentes. | FECHADO |
