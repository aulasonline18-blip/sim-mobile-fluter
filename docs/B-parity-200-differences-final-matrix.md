# B - Matriz final das 200 diferencas SimWeb x SimApp

Base congelada em 2026-07-01 a partir da auditoria estatica informada pelo usuario.

Repositorios:

- SimWeb: `/root/sim-work/sim-web/src`
- SimApp Flutter: `/root/sim-mobile-fluter/lib`
- Flutter HEAD auditado: `e29f4ac` em `main`/`origin/main`

Classificacoes permitidas usadas:

- `IGUALADO_100`
- `EQUIVALENTE_MOBILE_100`
- `FLUTTER_MELHOR`
- `WEB_ONLY_NAO_APLICAVEL`
- `ARQUITETURA_DIFERENTE_OK`
- `DECISAO_HUMANA_NECESSARIA`
- `CORRIGIDO_COM_TESTE`
- `CORRIGIDO_COM_PROVA_MANUAL`

Status final permitido usado:

- `FECHADO`
- `BLOQUEADO_POR_DECISAO_HUMANA`

| Nº | Área | Diferença | Classificação final | Precisa ação? | Ação feita | Arquivo(s) alterados | Prova/teste | Status final |
|---:|---|---|---|---|---|---|---|---|
| 1 | Roteamento | TanStack Router Web vs navegacao por estado Dart | ARQUITETURA_DIFERENTE_OK | Nao | Mantida arquitetura mobile por estado | Nenhum | `test/school_completeness_test.dart`, `test/sim_live_parity_test.dart` | FECHADO |
| 2 | Rotas publicas | URLs Web vs telas internas Flutter | EQUIVALENTE_MOBILE_100 | Nao | Equivalencia por portas/telas mobile | Nenhum | `test/school_completeness_test.dart` | FECHADO |
| 3 | SEO | Meta tags Web sem equivalente nativo | WEB_ONLY_NAO_APLICAVEL | Nao | Marcado web-only | Nenhum | App Android nao usa SEO | FECHADO |
| 4 | Error boundary | React error boundary vs telas/estados Flutter | EQUIVALENTE_MOBILE_100 | Nao | Equivalente por estados de erro | Nenhum | `test/finish_phase_test.dart`, `test/first_lesson_ready_window_test.dart` | FECHADO |
| 5 | Not found | Pagina 404 Web sem 404 nativo | WEB_ONLY_NAO_APLICAVEL | Nao | Marcado web-only | Nenhum | Navegacao mobile nao depende de URL livre | FECHADO |
| 6 | Login Google | Redirect Web vs SDK mobile Supabase | ARQUITETURA_DIFERENTE_OK | Nao | Mantido fluxo mobile Supabase | Nenhum | `test/fase9_session_test.dart`, `test/widget_test.dart` | FECHADO |
| 7 | Sessao | localStorage/browser vs Supabase mobile/session | ARQUITETURA_DIFERENTE_OK | Nao | Persistencia mobile propria | Nenhum | `test/cloud_phase_test.dart`, `test/fase9_session_test.dart` | FECHADO |
| 8 | Auth sync | Hooks/query Web vs AuthSession/provider | ARQUITETURA_DIFERENTE_OK | Nao | Mantido provider mobile | Nenhum | `test/fase9_session_test.dart` | FECHADO |
| 9 | Retorno pos-login | Query/returnTo vs estado interno | CORRIGIDO_COM_TESTE | Nao | Retorno seguro coberto por NavigationState/controller | Nenhum nesta rodada | `test/fase9_session_test.dart`, `test/billing_phase_test.dart` | FECHADO |
| 10 | Logout | Limpeza Web vs limpeza mobile | CORRIGIDO_COM_TESTE | Nao | Logout no drawer/session limpa sessao mobile | Nenhum nesta rodada | `test/widget_test.dart`, `docs/drawer-menu-parity-combined.md` | FECHADO |
| 11 | Dev auth bypass | Bypass dev no Web nao deve existir no app | ARQUITETURA_DIFERENTE_OK | Nao | Nao portado por seguranca | Nenhum | Regra de seguranca; app nao deve burlar auth | FECHADO |
| 12 | Credito infinito | Web consulta propria vs App/API | CORRIGIDO_COM_TESTE | Nao | Conta teste/credito infinito cobertos por servidor/app | Nenhum nesta rodada | `test/bug_regression_fixes_test.dart`, `npm test` API | FECHADO |
| 13 | Creditos | ServerFn Web vs cliente API Flutter | EQUIVALENTE_MOBILE_100 | Nao | Backend proprio equivalente mantido | Nenhum | `test/billing_phase_test.dart`, `npm test` | FECHADO |
| 14 | Checkout | Stripe Web vs fluxo mobile externo | EQUIVALENTE_MOBILE_100 | Nao | Fluxo hosted/return mobile preservado | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 15 | Checkout return | Rota Web vs controller Flutter | EQUIVALENTE_MOBILE_100 | Nao | Controller mobile substitui URL Web | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 16 | Banner test mode | Componente Web vs visual mobile | CORRIGIDO_COM_TESTE | Nao | Estado test/unlimited refletido em UI de credito | Nenhum | `test/bug_regression_fixes_test.dart`, `test/billing_phase_test.dart` | FECHADO |
| 17 | Compra creditos | Modal Web vs tela Flutter | EQUIVALENTE_MOBILE_100 | Nao | Tela mobile de creditos equivalente | Nenhum | `test/billing_phase_test.dart`, `docs/button-component-parity-full-table.md` | FECHADO |
| 18 | Status checkout | ServerFn Stripe vs API/cliente Flutter | EQUIVALENTE_MOBILE_100 | Nao | Validacao checkout por controller/API | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 19 | Webhook | Web/server route fora do Flutter | WEB_ONLY_NAO_APLICAVEL | Nao | Mantido fora do app | Nenhum | App nativo nao hospeda webhook | FECHADO |
| 20 | Precos | Config Web vs Dart pricing | CORRIGIDO_COM_TESTE | Nao | Precos oficiais portados e testados | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 21 | Portal | Visual Web vs widget Flutter | CORRIGIDO_COM_TESTE | Nao | Estrutura principal e botoes alinhados | Nenhum | `test/widget_test.dart`, `docs/button-component-parity-full-table.md` | FECHADO |
| 22 | Animacoes portal | CSS transitions vs Flutter animations | EQUIVALENTE_MOBILE_100 | Nao | Timing nao precisa ser pixel-perfect | Nenhum | Equivalencia funcional mobile | FECHADO |
| 23 | Hover | Hover Web ausente no mobile | WEB_ONLY_NAO_APLICAVEL | Nao | Marcado plataforma Web | Nenhum | Mobile touch-first | FECHADO |
| 24 | Focus outline | Browser/CSS vs foco Flutter | ARQUITETURA_DIFERENTE_OK | Nao | Semantics/foco mobile separados | Nenhum | Plataforma mobile | FECHADO |
| 25 | Responsivo | CSS/Tailwind vs layout Flutter | CORRIGIDO_COM_TESTE | Nao | Layout mobile coberto por widget tests | Nenhum | `test/widget_test.dart`, `test/finish_phase_test.dart` | FECHADO |
| 26 | Tipografia | Browser fonts vs GoogleFonts/Flutter | ARQUITETURA_DIFERENTE_OK | Nao | Renderizacao de plataforma aceita | Nenhum | Diferenca de renderer | FECHADO |
| 27 | Cores | CSS variables vs constantes Dart | CORRIGIDO_COM_TESTE | Nao | Tokens/componentes alinhados em UI principal | Nenhum | `docs/button-component-parity-full-table.md` | FECHADO |
| 28 | Bordas/sombras | CSS vs BoxDecoration | EQUIVALENTE_MOBILE_100 | Nao | Equivalencia visual funcional, nao pixel-perfect | Nenhum | Docs de paridade visual | FECHADO |
| 29 | Idioma | Tela Web vs tela Flutter | CORRIGIDO_COM_TESTE | Nao | Selecao de idioma funcional | Nenhum | `test/widget_test.dart`, `test/normal_lesson_full_completion_flow_test.dart` | FECHADO |
| 30 | i18n | i18n Web dinamico vs Dart estatico | ARQUITETURA_DIFERENTE_OK | Nao | Mobile usa catalogo estatico controlado | Nenhum | `lib/sim/ui/sim_i18n.dart`, testes UI | FECHADO |
| 31 | Traducao UI | ServerFn ui-translate ausente | ARQUITETURA_DIFERENTE_OK | Nao | Nao portar IA dinamica para UI mobile sem decisao de produto | Nenhum | Arquitetura mobile evita traducao remota de UI | FECHADO |
| 32 | Cache traducao | Cache Web sem equivalente completo | ARQUITETURA_DIFERENTE_OK | Nao | Nao necessario com i18n estatico | Nenhum | `sim_i18n.dart` | FECHADO |
| 33 | Objetivo | Rota Web vs onboarding Flutter | CORRIGIDO_COM_TESTE | Nao | Fluxo objetivo -> T00 coberto | Nenhum | `test/widget_test.dart`, `test/normal_lesson_full_completion_flow_test.dart` | FECHADO |
| 34 | Objetivo vazio | Estado Web vs Flutter | CORRIGIDO_COM_TESTE | Nao | Validacao/estado visual cobertos | Nenhum | `test/widget_test.dart` | FECHADO |
| 35 | Objetivo preenchido | Botao habilita nos dois | CORRIGIDO_COM_TESTE | Nao | Botao continua aciona fluxo | Nenhum | `test/widget_test.dart`, `test/organism_vital_flow_test.dart` | FECHADO |
| 36 | Upload/anexos | File input vs cliente mobile | EQUIVALENTE_MOBILE_100 | Nao | UX mobile equivalente por picker/processamento | Nenhum | `test/finish_phase_test.dart`, `test/electrical_hydraulic_connections_test.dart` | FECHADO |
| 37 | PDF | Web processa PDF vs API app | EQUIVALENTE_MOBILE_100 | Nao | Processamento via API propria | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 38 | Imagem anexo | FileReader vs bytes/data mobile | EQUIVALENTE_MOBILE_100 | Nao | Data/bytes mobile equivalentes | Nenhum | `test/finish_phase_test.dart`, `test/media_phase_test.dart` | FECHADO |
| 39 | Camera | input capture Web vs camera mobile | EQUIVALENTE_MOBILE_100 | Nao | Permissao/camera mobile cobertas | Nenhum | `test/electrical_hydraulic_connections_test.dart`, `test/auxiliary_phase_test.dart` | FECHADO |
| 40 | Galeria | Browser file vs picker mobile | EQUIVALENTE_MOBILE_100 | Nao | Picker mobile equivalente | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 41 | Audio anexo | Web rejeita/trata vs Flutter | CORRIGIDO_COM_TESTE | Nao | Validacao de anexos cobre tipos | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 42 | OCR/vision | Web server function vs API app | EQUIVALENTE_MOBILE_100 | Nao | Backend separado aprovado | Nenhum | `test/electrical_hydraulic_connections_test.dart` | FECHADO |
| 43 | Compressao imagem | Canvas browser vs Dart/image | EQUIVALENTE_MOBILE_100 | Nao | Algoritmo mobile equivalente | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 44 | Preparacao | SimPreparationExperience Web vs Dart | CORRIGIDO_COM_TESTE | Nao | Widget/fluxo pronto cobertos | Nenhum | `test/widget_test.dart`, `test/finish_phase_test.dart` | FECHADO |
| 45 | Typewriter | React vs SimTypewriter | EQUIVALENTE_MOBILE_100 | Nao | Timing nao precisa ser literal | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 46 | T00 SSE | Web stream vs Flutter adapter | IGUALADO_100 | Nao | Contrato T00 portado | Nenhum | `test/student_experience_t00_test.dart` | FECHADO |
| 47 | Evento parcial | Writer TS vs Dart | IGUALADO_100 | Nao | Orgao equivalente | Nenhum | `test/student_experience_t00_test.dart` | FECHADO |
| 48 | Curriculo final | Estado Web vs Flutter store | EQUIVALENTE_MOBILE_100 | Nao | Persistencia mobile/cloud equivalente | Nenhum | `test/student_experience_t00_test.dart`, `test/cloud_phase_test.dart` | FECHADO |
| 49 | Perfil T00 | Writer TS vs Dart | CORRIGIDO_COM_TESTE | Nao | Campos principais preservados | Nenhum | `test/student_experience_t00_test.dart`, `docs/B1-lesson-logic-t00-t02-audit.md` | FECHADO |
| 50 | Parser T00 | Parser TS vs Dart utils | CORRIGIDO_COM_TESTE | Nao | Parser Dart validado por contrato | Nenhum | `test/student_experience_t00_test.dart` | FECHADO |
| 51 | Gemini no Web | ServerFns Web vs API app | ARQUITETURA_DIFERENTE_OK | Nao | IA fica no servidor proprio, nao no Flutter | Nenhum | `test/external_ai_clients_test.dart`, `npm test` | FECHADO |
| 52 | Prompts | Web/server contem prompts; Flutter nao | ARQUITETURA_DIFERENTE_OK | Nao | Segredo/prompt fora do app | Nenhum | Arquitetura segura | FECHADO |
| 53 | Lovable gateway | Web usa; app nao deve | ARQUITETURA_DIFERENTE_OK | Nao | Mantida API oficial propria | Nenhum | `test/external_ai_clients_test.dart` | FECHADO |
| 54 | Retry AI | Web retry vs API/cliente separado | CORRIGIDO_COM_TESTE | Nao | Retry T02 invalido na API propria | Nenhum | `npm test`, `docs/B2-lesson-logic-t00-t02-parity.md` | FECHADO |
| 55 | Request logging | Logs Web vs Flutter/API | EQUIVALENTE_MOBILE_100 | Nao | Logs com requestId na API quando necessario | Nenhum | `npm test`, relatorios B2 imagem/logica | FECHADO |
| 56 | T02 payload | Builder TS vs Dart request | CORRIGIDO_COM_TESTE | Nao | Contrato auditado e validado | Nenhum | `test/external_ai_clients_test.dart`, `docs/B2-lesson-logic-t00-t02-parity.md` | FECHADO |
| 57 | Cache T02 | Web cache vs Dart cache | CORRIGIDO_COM_TESTE | Nao | Cache invalido descartado | Nenhum | `test/first_lesson_ready_window_test.dart` | FECHADO |
| 58 | Dedupe T02 | Web shared ops vs Dart inflight/cache | CORRIGIDO_COM_TESTE | Nao | Inflight/cache cobertos | Nenhum | `test/classroom_parity_t01_t28_test.dart`, `test/first_lesson_ready_window_test.dart` | FECHADO |
| 59 | TTL cache | Web material cache vs Dart cache | CORRIGIDO_COM_TESTE | Nao | TTL/validade cobertos por cache tests | Nenhum | `test/bloco1_completion_test.dart`, `test/first_lesson_ready_window_test.dart` | FECHADO |
| 60 | LRU 3 aulas | Web ready window vs Dart cache/window | CORRIGIDO_COM_TESTE | Nao | Limite 3 aulas testado | Nenhum | `test/first_lesson_ready_window_test.dart` | FECHADO |
| 61 | Aula principal | React hooks vs runtime engine | ARQUITETURA_DIFERENTE_OK | Nao | Orgaos Dart substituem hooks | Nenhum | `test/organism_vital_flow_test.dart` | FECHADO |
| 62 | Runtime aula | Hooks React vs controllers Dart | ARQUITETURA_DIFERENTE_OK | Nao | Modularizacao mobile preservada | Nenhum | `test/internal_organs_governor_test.dart` | FECHADO |
| 63 | Hydration | Hook Web vs engine Dart | CORRIGIDO_COM_TESTE | Nao | Hidratacao coberta | Nenhum | `test/first_lesson_ready_window_test.dart`, `test/cloud_phase_test.dart` | FECHADO |
| 64 | Session engine | Hook TS vs engine Dart | EQUIVALENTE_MOBILE_100 | Nao | Sem lifecycle React por design | Nenhum | `test/organism_integration_test.dart` | FECHADO |
| 65 | Material controller | Hook TS vs controller Dart | CORRIGIDO_COM_TESTE | Nao | Controller Dart coberto | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 66 | Position engine | Hook TS vs engine Dart | CORRIGIDO_COM_TESTE | Nao | Posicao/layer cobertas | Nenhum | `test/normal_lesson_full_completion_flow_test.dart`, `test/classroom_parity_t01_t28_test.dart` | FECHADO |
| 67 | Playback engine | Hook TS vs audio/controller Dart | ARQUITETURA_DIFERENTE_OK | Nao | Audio mobile proprio | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 68 | View model | Hook TS vs Dart view model | CORRIGIDO_COM_TESTE | Nao | View model de aula testado | Nenhum | `test/classroom_phase_test.dart` | FECHADO |
| 69 | ScrollFeed | React feed vs Flutter scroll | EQUIVALENTE_MOBILE_100 | Nao | Equivalencia mobile, nao pixel-perfect | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 70 | Historico aula | Web feed vs Flutter history | CORRIGIDO_COM_TESTE | Nao | Historico/attempts persistidos | Nenhum | `test/classroom_parity_t01_t28_test.dart`, `test/cloud_phase_test.dart` | FECHADO |
| 71 | Explicacao | Bloco Web vs widget Flutter | CORRIGIDO_COM_TESTE | Nao | Texto aparece sem bloquear imagem/audio | Nenhum | `test/normal_lesson_full_completion_flow_test.dart`, `test/media_phase_test.dart` | FECHADO |
| 72 | Pergunta | QuestionBlock vs aula widgets | CORRIGIDO_COM_TESTE | Nao | Pergunta aparece no fluxo | Nenhum | `test/normal_lesson_full_completion_flow_test.dart` | FECHADO |
| 73 | Alternativas A/B/C | Botoes Web vs Flutter | CORRIGIDO_COM_TESTE | Nao | A/B/C funcionam e foram alinhados | Nenhum | `test/widget_test.dart`, `docs/button-component-parity-full-table.md` | FECHADO |
| 74 | Estado selecionado | CSS state vs Flutter style | EQUIVALENTE_MOBILE_100 | Nao | Estado visual mobile equivalente | Nenhum | `test/widget_test.dart` | FECHADO |
| 75 | Sinais 1/2/3 | Web buttons vs Flutter | CORRIGIDO_COM_TESTE | Nao | Sinais enviam decisao | Nenhum | `test/classroom_parity_t01_t28_test.dart`, `test/widget_test.dart` | FECHADO |
| 76 | Separacao A/B/C e sinais | Separacao preservada | IGUALADO_100 | Nao | Igual funcionalmente | Nenhum | `test/classroom_parity_t01_t28_test.dart` | FECHADO |
| 77 | Feedback | TS feedback vs Dart feedback | CORRIGIDO_COM_TESTE | Nao | Textos/estado de feedback cobertos | Nenhum | `test/widget_test.dart`, `test/classroom_phase_test.dart` | FECHADO |
| 78 | Avanco | Hook controller vs Dart progress | CORRIGIDO_COM_TESTE | Nao | Avanco item/layer coberto | Nenhum | `test/normal_lesson_full_completion_flow_test.dart` | FECHADO |
| 79 | Stop audio responder | Web hook vs Dart controller | CORRIGIDO_COM_TESTE | Nao | Stop em resposta/sinal/avanco/dispose | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 80 | Janela dopaminica | Engine Web vs Dart | CORRIGIDO_COM_TESTE | Nao | Engine Dart coberta | Nenhum | `test/first_lesson_ready_window_test.dart` | FECHADO |
| 81 | Slot A | Prioridade Web vs Flutter | EQUIVALENTE_MOBILE_100 | Nao | Prioridade preservada | Nenhum | `test/first_lesson_ready_window_test.dart` | FECHADO |
| 82 | Slots B/C | Background Web vs Flutter | EQUIVALENTE_MOBILE_100 | Nao | Background nao bloqueante | Nenhum | `test/first_lesson_ready_window_test.dart` | FECHADO |
| 83 | Falha B/C | Nao bloqueia nos dois | IGUALADO_100 | Nao | Falha secundaria nao bloqueia aula | Nenhum | `test/first_lesson_ready_window_test.dart` | FECHADO |
| 84 | Review | Service Web vs Dart | CORRIGIDO_COM_TESTE | Nao | Revisao integrada | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 85 | Recovery | Service Web vs Dart | CORRIGIDO_COM_TESTE | Nao | Recuperacao integrada | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 86 | Amparo | Aux room Web vs Flutter | EQUIVALENTE_MOBILE_100 | Nao | Amparo tratado como orgao auxiliar/painel | Nenhum | `test/bloco1_completion_test.dart`, `test/support_phase_test.dart` | FECHADO |
| 87 | Tela revisao | React screen vs Flutter screen | CORRIGIDO_COM_TESTE | Nao | Fluxo e botoes cobertos | Nenhum | `test/auxiliary_phase_test.dart`, `test/widget_test.dart` | FECHADO |
| 88 | Tela recuperacao | React screen vs Flutter screen | CORRIGIDO_COM_TESTE | Nao | Fluxo e bloqueio/liberacao cobertos | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 89 | Tela duvida | Web sheet vs Dart sheet | CORRIGIDO_COM_TESTE | Nao | Sheet/texto/foto/T02 real cobertos | Nenhum | `test/auxiliary_phase_test.dart`, `test/widget_test.dart` | FECHADO |
| 90 | Duvida texto | Textarea vs TextField | EQUIVALENTE_MOBILE_100 | Nao | Input mobile equivalente | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 91 | Duvida foto | File input vs picker mobile | CORRIGIDO_COM_TESTE | Nao | `dataUrl` preservado | Nenhum | `test/auxiliary_phase_test.dart`, `npm test` | FECHADO |
| 92 | Duvida galeria | Browser file vs picker | EQUIVALENTE_MOBILE_100 | Nao | Galeria mobile equivalente | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 93 | Progresso duvida | DoubtProgressBar Web vs Dart | CORRIGIDO_COM_TESTE | Nao | Progress/state coberto | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 94 | Audio duvida | useDoubtAudio vs DoubtAudio | CORRIGIDO_COM_TESTE | Nao | Audio de duvida coberto | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 95 | Validacao imagem duvida | Web moduleCaller vs API/Dart | CORRIGIDO_COM_TESTE | Nao | Validacao em API/Dart | Nenhum | `npm test`, `test/auxiliary_phase_test.dart` | FECHADO |
| 96 | Imagem aula | Web subscribe cache vs Flutter media state | CORRIGIDO_COM_TESTE | Nao | Painel e pipeline imagem cobertos | Nenhum | `test/media_phase_test.dart`, `docs/B2-image-system-parity.md` | FECHADO |
| 97 | Oferta imagem paga | Web offer vs Dart offer | CORRIGIDO_COM_TESTE | Nao | Oferta antes de custo | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 98 | Geracao imagem | Web route/function vs API externa | ARQUITETURA_DIFERENTE_OK | Nao | Endpoint proprio aprovado | Nenhum | `npm test`, `docs/B2-image-system-parity.md` | FECHADO |
| 99 | Visual free SVG | Web visual router vs Dart | CORRIGIDO_COM_TESTE | Nao | SVG/templates gratuitos cobertos | Nenhum | `test/media_phase_test.dart`, `test/first_lesson_ready_window_test.dart` | FECHADO |
| 100 | N2/N3 visual | TS templates vs Dart templates | CORRIGIDO_COM_TESTE | Nao | N2/N3 equivalente testado | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 101 | Compressao visual | Canvas vs Dart image | CORRIGIDO_COM_TESTE | Nao | Compressao data URL coberta | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 102 | Audio aula | Web Audio vs Flutter audio adapter | ARQUITETURA_DIFERENTE_OK | Nao | Plataforma audio propria | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 103 | Preferencia audio | localStorage vs SharedPreferences | ARQUITETURA_DIFERENTE_OK | Nao | Persistencia mobile correta | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 104 | Bubble fixa | FixedBubble React vs Dart widget | EQUIVALENTE_MOBILE_100 | Nao | Bolha funcional equivalente | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 105 | Avatar | LessonAvatar React vs Dart | EQUIVALENTE_MOBILE_100 | Nao | Avatar nao governa audio/pedagogia | Nenhum | `test/support_phase_test.dart` | FECHADO |
| 106 | Loading aula | Web skeleton vs Flutter state | CORRIGIDO_COM_TESTE | Nao | Estados loading cobertos | Nenhum | `test/finish_phase_test.dart`, `test/normal_lesson_full_completion_flow_test.dart` | FECHADO |
| 107 | Erro aula | Web state vs Flutter card | CORRIGIDO_COM_TESTE | Nao | Erro controlado nao bloqueante | Nenhum | `test/finish_phase_test.dart`, `test/media_phase_test.dart` | FECHADO |
| 108 | Retry aula | Web retry vs Flutter retry | CORRIGIDO_COM_TESTE | Nao | Retry/erro controlado | Nenhum | `test/first_lesson_ready_window_test.dart` | FECHADO |
| 109 | Estado vazio | Web route/state vs Flutter | CORRIGIDO_COM_TESTE | Nao | Empty classroom state alinhado | Nenhum | `test/school_completeness_test.dart`, `docs/interface-parity-map.md` | FECHADO |
| 110 | Retomada | Web storage/cloud vs SharedPrefs/cloud | CORRIGIDO_COM_TESTE | Nao | Retomada e persistencia cobertas | Nenhum | `test/cloud_phase_test.dart`, `docs/B-sync-state-backup-final-report.md` | FECHADO |
| 111 | Fresh lesson seed | sessionStorage vs estado interno | ARQUITETURA_DIFERENTE_OK | Nao | Seed interno mobile correto | Nenhum | `test/organism_vital_flow_test.dart` | FECHADO |
| 112 | Live entry state | TS state vs Dart live entry | CORRIGIDO_COM_TESTE | Nao | Live entry nao regride | Nenhum | `test/sim_state_engines_test.dart` | FECHADO |
| 113 | StudentLearningState | TS store vs Dart model | CORRIGIDO_COM_TESTE | Nao | Fonte unica Dart preservada | Nenhum | `test/cloud_phase_test.dart`, `test/state_store_truth_engine_test.dart` | FECHADO |
| 114 | Mirror state | TS mirror vs Dart store | CORRIGIDO_COM_TESTE | Nao | Mirror/estado canonico cobertos | Nenhum | `test/internal_organs_governor_test.dart` | FECHADO |
| 115 | Cloud meta | Web meta vs Flutter cloud storage | CORRIGIDO_COM_TESTE | Nao | Cloud meta/summaries cobertos | Nenhum | `test/cloud_phase_test.dart`, `npm test` | FECHADO |
| 116 | Cloud queue | TS queue vs Dart queue | CORRIGIDO_COM_TESTE | Nao | Queue e conflito cobertos | Nenhum | `test/cloud_phase_test.dart`, `test/classroom_parity_t01_t28_test.dart` | FECHADO |
| 117 | Cloud sync | Web focus/realtime vs Flutter session/manual | EQUIVALENTE_MOBILE_100 | Nao | Equivalente mobile por queue/drain/pull | Nenhum | `test/cloud_phase_test.dart`, `docs/B-sync-state-backup-final-report.md` | FECHADO |
| 118 | Realtime | useSimRealtime vs sync mobile | ARQUITETURA_DIFERENTE_OK | Nao | Realtime browser nao e requisito literal do app | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 119 | Pull cloud | cloudPull TS vs Flutter load/list | CORRIGIDO_COM_TESTE | Nao | Pull/list cloud cobertos | Nenhum | `test/cloud_phase_test.dart`, `test/widget_test.dart` | FECHADO |
| 120 | React Query | Cache/invalidation sem equivalente direto | ARQUITETURA_DIFERENTE_OK | Nao | Store/queue Dart substituem React Query | Nenhum | Arquitetura mobile | FECHADO |
| 121 | Lista cloud | Hook Web vs drawer Flutter cloud | CORRIGIDO_COM_TESTE | Nao | Lista cloud no drawer | Nenhum | `test/widget_test.dart`, `docs/drawer-menu-parity-combined.md` | FECHADO |
| 122 | Dedupe cloud/local | Web bridge vs Flutter drawer | CORRIGIDO_COM_TESTE | Nao | Dedupe por lessonLocalId | Nenhum | `test/widget_test.dart` | FECHADO |
| 123 | Abrir aula cloud | Web hydrate vs Flutter active | CORRIGIDO_COM_TESTE | Nao | Hidrata e abre aula | Nenhum | `test/widget_test.dart`, `test/cloud_phase_test.dart` | FECHADO |
| 124 | Renomear local | Web state/cloud vs Flutter | CORRIGIDO_COM_TESTE | Nao | Rename local testado | Nenhum | `test/widget_test.dart` | FECHADO |
| 125 | Renomear cloud | Web function vs API cloud | CORRIGIDO_COM_TESTE | Nao | Rename cloud testado | Nenhum | `test/widget_test.dart`, `docs/drawer-menu-parity-combined.md` | FECHADO |
| 126 | Apagar local | Delete/tombstone Web vs Flutter | CORRIGIDO_COM_TESTE | Nao | Tombstone seguro | Nenhum | `test/widget_test.dart` | FECHADO |
| 127 | Apagar cloud | Web cloud delete vs Flutter cloud delete | CORRIGIDO_COM_TESTE | Nao | Delete cloud seguro | Nenhum | `test/widget_test.dart`, `npm test` | FECHADO |
| 128 | Paginacao drawer | Web load more vs Flutter load more | CORRIGIDO_COM_TESTE | Nao | 30+30 coberto | Nenhum | `test/widget_test.dart`, `docs/drawer-menu-parity-combined.md` | FECHADO |
| 129 | Busca drawer | Web search vs Flutter search | CORRIGIDO_COM_TESTE | Nao | Busca local/cloud coberta | Nenhum | `test/widget_test.dart` | FECHADO |
| 130 | Drawer visual | CSS panel vs Flutter drawer | EQUIVALENTE_MOBILE_100 | Nao | Equivalencia mobile, nao pixel-perfect | Nenhum | `test/widget_test.dart`, `docs/drawer-menu-parity-combined.md` | FECHADO |
| 131 | Export backup | Browser download vs temp/clipboard | EQUIVALENTE_MOBILE_100 | Nao | UX mobile equivalente | Nenhum | `test/widget_test.dart`, `docs/B-sync-state-backup-final-report.md` | FECHADO |
| 132 | Nome backup | Padrao igual | IGUALADO_100 | Nao | Padrao preservado | Nenhum | `docs/drawer-menu-parity-combined.md` | FECHADO |
| 133 | Import backup | File picker vs colar/texto/mobile | EQUIVALENTE_MOBILE_100 | Nao | Import mobile equivalente | Nenhum | `test/widget_test.dart`, `docs/B-sync-state-backup-final-report.md` | FECHADO |
| 134 | Formato backup | Envelope Web vs Flutter compativel | CORRIGIDO_COM_TESTE | Nao | Envelope Web importavel | Nenhum | `docs/B-sync-state-backup-final-report.md`, `test/widget_test.dart` | FECHADO |
| 135 | Export status | Browser download vs arquivo/clipboard | EQUIVALENTE_MOBILE_100 | Nao | UX mobile equivalente | Nenhum | `test/widget_test.dart`, `docs/drawer-menu-parity-combined.md` | FECHADO |
| 136 | Father panel status | Web completo vs Flutter simplificado | EQUIVALENTE_MOBILE_100 | Nao | Status parental mobile suficiente | Nenhum | `test/support_phase_test.dart` | FECHADO |
| 137 | Historico local | Web cyberLessons vs StudentLearningState | ARQUITETURA_DIFERENTE_OK | Nao | Modelo Dart canonico | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 138 | Historico cloud | Supabase/Web bridge vs API cloud | EQUIVALENTE_MOBILE_100 | Nao | API cloud propria equivalente | Nenhum | `test/cloud_phase_test.dart`, `npm test` | FECHADO |
| 139 | Nova aula drawer | Web reset/navega vs Flutter | CORRIGIDO_COM_TESTE | Nao | Reset/navegacao testados | Nenhum | `test/widget_test.dart` | FECHADO |
| 140 | Creditos drawer | Web route vs Flutter tela/modal | CORRIGIDO_COM_TESTE | Nao | Drawer abre creditos corretamente | Nenhum | `test/widget_test.dart` | FECHADO |
| 141 | Sair drawer | Web logout vs Flutter logout | CORRIGIDO_COM_TESTE | Nao | Logout no drawer coberto | Nenhum | `test/widget_test.dart` | FECHADO |
| 142 | Excluir conta | Web route/function vs Flutter controller | CORRIGIDO_COM_TESTE | Nao | Rota/fluxo de exclusao cobertos | Nenhum | `test/billing_phase_test.dart`, `test/widget_test.dart` | FECHADO |
| 143 | Tela creditos | Web completa vs billing page | CORRIGIDO_COM_TESTE | Nao | Packs, checkout e retorno cobertos | Nenhum | `test/billing_phase_test.dart`, `docs/button-component-parity-full-table.md` | FECHADO |
| 144 | Tela termos | Web SEO vs legal page Flutter | EQUIVALENTE_MOBILE_100 | Nao | Pagina legal mobile equivalente | Nenhum | `test/support_phase_test.dart` | FECHADO |
| 145 | Tela privacidade | Web SEO vs legal page Flutter | EQUIVALENTE_MOBILE_100 | Nao | Pagina legal mobile equivalente | Nenhum | `test/support_phase_test.dart` | FECHADO |
| 146 | Tela deletar conta | Web route vs Flutter screen/controller | CORRIGIDO_COM_TESTE | Nao | Exclusao exige confirmacao | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 147 | Painel pai | `/pai` Web vs father_panel.dart | EQUIVALENTE_MOBILE_100 | Nao | Painel/status parental equivalente | Nenhum | `test/support_phase_test.dart` | FECHADO |
| 148 | Escola/ambiente | Web route set vs Dart school env | EQUIVALENTE_MOBILE_100 | Nao | Ambiente escolar Dart cobre rotas saudaveis | Nenhum | `test/school_completeness_test.dart` | FECHADO |
| 149 | Completeness school | Verificacao propria Flutter | FLUTTER_MELHOR | Nao | Flutter tem teste de completude escolar | Nenhum | `test/school_completeness_test.dart` | FECHADO |
| 150 | Placement intro | Web screen vs Flutter screen | CORRIGIDO_COM_TESTE | Nao | Placement intro/flow coberto | Nenhum | `test/placement_phase_test.dart`, `test/widget_test.dart` | FECHADO |
| 151 | Placement choice | Web screen vs Flutter screen | CORRIGIDO_COM_TESTE | Nao | Choice coberto | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 152 | Placement question | Web screen vs Flutter screen | CORRIGIDO_COM_TESTE | Nao | Pergunta placement coberta | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 153 | Placement result | Web screen vs Flutter screen | CORRIGIDO_COM_TESTE | Nao | Resultado placement coberto | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 154 | Placement T02 | TS caller vs Dart caller | CORRIGIDO_COM_TESTE | Nao | Caller Dart coberto | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 155 | Placement store | TS store vs Dart store | CORRIGIDO_COM_TESTE | Nao | Store/mirror cobertos | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 156 | Feature flag placement | TS flag vs Dart route/state | ARQUITETURA_DIFERENTE_OK | Nao | Controle por rota/estado mobile | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 157 | Math templates | TS vs Dart templates | CORRIGIDO_COM_TESTE | Nao | Templates principais portados | Nenhum | `test/media_phase_test.dart`, `test/first_lesson_ready_window_test.dart` | FECHADO |
| 158 | Formula parser | TS parser vs Dart templates | EQUIVALENTE_MOBILE_100 | Nao | Equivalente funcional para templates vivos | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 159 | Kinematics ST | TS vs Dart | CORRIGIDO_COM_TESTE | Nao | Template portado | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 160 | Kinematics VT | TS vs Dart | CORRIGIDO_COM_TESTE | Nao | Template portado | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 161 | Quadratica | TS vs Dart | CORRIGIDO_COM_TESTE | Nao | Template portado | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 162 | Funcao linear | TS vs Dart | CORRIGIDO_COM_TESTE | Nao | Template portado | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 163 | Circulo unitario | TS vs Dart | CORRIGIDO_COM_TESTE | Nao | Template portado | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 164 | T04 interpreter | Web prompt/module vs Flutter sem prompt | ARQUITETURA_DIFERENTE_OK | Nao | Funcao absorvida por T00/API | Nenhum | `test/sim_live_parity_test.dart` | FECHADO |
| 165 | Pretest functions | ServerFn Web vs placement client | ARQUITETURA_DIFERENTE_OK | Nao | Placement substitui pretest | Nenhum | `test/sim_live_parity_test.dart`, `test/placement_phase_test.dart` | FECHADO |
| 166 | Module caller tests | Vitest vs Flutter tests | ARQUITETURA_DIFERENTE_OK | Nao | Testes por contrato nos orgaos Dart/API | Nenhum | `flutter test`, `npm test` | FECHADO |
| 167 | Store tests | Vitest vs Dart tests | ARQUITETURA_DIFERENTE_OK | Nao | Cobertura equivalente por Dart tests | Nenhum | `test/state_store_truth_engine_test.dart`, `test/cloud_phase_test.dart` | FECHADO |
| 168 | Golden/screenshot | Web capturavel vs Flutter sem golden completo | EQUIVALENTE_MOBILE_100 | Nao | Funcionalidade coberta por widget/integration tests; pixel golden nao e requisito funcional | Nenhum | `test/widget_test.dart`, `docs/interface-parity-map.md` | FECHADO |
| 169 | App real APK | Web nao tem APK vs Flutter release | FLUTTER_MELHOR | Nao | APK release gerado como prova de plataforma | Nenhum | Build release final | FECHADO |
| 170 | PWA/browser | Web PWA/meta vs Android app | ARQUITETURA_DIFERENTE_OK | Nao | Plataforma Android propria | Nenhum | Build Android | FECHADO |
| 171 | Permissoes Android | N/A Web vs Android permissions | FLUTTER_MELHOR | Nao | Permissoes mobile verificadas | Nenhum | `test/electrical_hydraulic_connections_test.dart` | FECHADO |
| 172 | Internet error | Browser fetch vs mobile http | EQUIVALENTE_MOBILE_100 | Nao | Erro mobile tratado | Nenhum | `test/finish_phase_test.dart`, `test/external_ai_clients_test.dart` | FECHADO |
| 173 | RequestId | Logs Web vs App/API | CORRIGIDO_COM_TESTE | Nao | RequestId/logs API cobertos | Nenhum | `npm test`, relatorios B2 | FECHADO |
| 174 | Auth header | Cookies/header vs bearer/API token | ARQUITETURA_DIFERENTE_OK | Nao | Bearer/API token correto no app | Nenhum | `test/external_ai_clients_test.dart`, `test/electrical_hydraulic_connections_test.dart` | FECHADO |
| 175 | API baseUrl | Same-origin Web vs API externa | ARQUITETURA_DIFERENTE_OK | Nao | API propria oficial do app | Nenhum | `test/external_ai_clients_test.dart` | FECHADO |
| 176 | Healthcheck | Web server vs API separada | ARQUITETURA_DIFERENTE_OK | Nao | Healthcheck API separado | Nenhum | `npm test` | FECHADO |
| 177 | Service role | Web/server pode usar; Flutter nao | ARQUITETURA_DIFERENTE_OK | Nao | Service role fora do app | Nenhum | Revisao de arquitetura segura | FECHADO |
| 178 | Gemini key | Web/server/API; Flutter nao | ARQUITETURA_DIFERENTE_OK | Nao | Chave fora do app | Nenhum | `test/external_ai_clients_test.dart` | FECHADO |
| 179 | Supabase types | Generated TS vs Dart SDK | ARQUITETURA_DIFERENTE_OK | Nao | SDK Dart proprio | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 180 | Supabase realtime | Web hook vs Flutter parcial | EQUIVALENTE_MOBILE_100 | Nao | Sync mobile por queue/pull e suficiente para vida escolar | Nenhum | `test/cloud_phase_test.dart`, `docs/B-sync-state-backup-final-report.md` | FECHADO |
| 181 | Local cache | localStorage/sessionStorage vs SharedPreferences/files | ARQUITETURA_DIFERENTE_OK | Nao | Persistencia mobile correta | Nenhum | `test/fase1_persistence_test.dart`, `test/bloco1_completion_test.dart` | FECHADO |
| 182 | File download | Browser download vs arquivo/clipboard | EQUIVALENTE_MOBILE_100 | Nao | UX mobile equivalente | Nenhum | `test/widget_test.dart` | FECHADO |
| 183 | File import | Browser picker vs colagem/picker mobile | EQUIVALENTE_MOBILE_100 | Nao | Import mobile equivalente | Nenhum | `test/widget_test.dart` | FECHADO |
| 184 | Clipboard | Mais central no Flutter | FLUTTER_MELHOR | Nao | Clipboard ajuda no mobile/remoto | Nenhum | `test/widget_test.dart` | FECHADO |
| 185 | Toasts | Web toast vs SnackBar/flash | EQUIVALENTE_MOBILE_100 | Nao | Feedback mobile equivalente | Nenhum | `test/widget_test.dart` | FECHADO |
| 186 | Dialogs | Shadcn/dialog vs AlertDialog | EQUIVALENTE_MOBILE_100 | Nao | Dialog mobile nativo | Nenhum | `test/widget_test.dart` | FECHADO |
| 187 | Sheets | Shadcn/sheet vs Flutter modal sheet | EQUIVALENTE_MOBILE_100 | Nao | Sheet mobile nativo | Nenhum | `test/auxiliary_phase_test.dart`, `test/widget_test.dart` | FECHADO |
| 188 | Buttons UI | Shadcn button vs custom buttons | CORRIGIDO_COM_TESTE | Nao | Componentes/botoes alinhados | Nenhum | `docs/button-component-parity-full-table.md`, `test/widget_test.dart` | FECHADO |
| 189 | Tooltips | Web tooltip vs mobile limitado | WEB_ONLY_NAO_APLICAVEL | Nao | Tooltip hover nao e requisito touch-first | Nenhum | Plataforma mobile | FECHADO |
| 190 | Skeleton | Web skeleton vs loading custom | EQUIVALENTE_MOBILE_100 | Nao | Loading mobile equivalente | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 191 | Progress | Web progress vs Flutter widgets | EQUIVALENTE_MOBILE_100 | Nao | Progress funcional equivalente | Nenhum | `test/widget_test.dart`, `test/normal_lesson_full_completion_flow_test.dart` | FECHADO |
| 192 | Toggle | Web toggle vs Flutter switch/button | EQUIVALENTE_MOBILE_100 | Nao | Toggle mobile equivalente | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 193 | Inputs | Web input vs Flutter TextField | EQUIVALENTE_MOBILE_100 | Nao | Input mobile equivalente | Nenhum | `test/widget_test.dart`, `test/auxiliary_phase_test.dart` | FECHADO |
| 194 | Validacao formulario | Web zod/hooks vs Flutter local validation | EQUIVALENTE_MOBILE_100 | Nao | Validacao local mobile equivalente | Nenhum | `test/auxiliary_phase_test.dart`, `test/widget_test.dart` | FECHADO |
| 195 | Accessibility ARIA | Web ARIA vs Flutter Semantics | EQUIVALENTE_MOBILE_100 | Nao | Semantics/mobile focus suficiente para fluxo principal | Nenhum | `test/electrical_hydraulic_connections_test.dart`, widget tests | FECHADO |
| 196 | Keyboard shortcuts | Web teclado vs mobile touch-first | WEB_ONLY_NAO_APLICAVEL | Nao | Atalho teclado nao e requisito mobile principal | Nenhum | Plataforma mobile | FECHADO |
| 197 | Scroll physics | Browser scroll vs Flutter physics | ARQUITETURA_DIFERENTE_OK | Nao | Scroll mobile nativo | Nenhum | Widget tests sem overflow funcional | FECHADO |
| 198 | Safe areas | Web viewport vs Flutter SafeArea | ARQUITETURA_DIFERENTE_OK | Nao | SafeArea mobile correta | Nenhum | Widget tests/estrutura Flutter | FECHADO |
| 199 | Captura visual autenticada | Web capturado vs Flutter depende APK/dispositivo | DECISAO_HUMANA_NECESSARIA | Sim | APK release gerado, SHA calculado e link publico validado; teste fisico no APK real exige dispositivo Android/acao humana, indisponivel nesta VM | Nenhum | `flutter devices` mostra apenas Linux desktop; URL publica do APK retorna 200 OK | BLOQUEADO_POR_DECISAO_HUMANA |
| 200 | Paridade total comprovada | Web referencia viva vs Flutter testes/build/matriz | DECISAO_HUMANA_NECESSARIA | Sim | Matriz 200 fechada por classificacao; B total depende da validacao humana do APK real do item 199 | Nenhum | `flutter analyze`, `flutter test`, build release e `npm test` passaram; falta teste fisico do APK | BLOQUEADO_POR_DECISAO_HUMANA |
