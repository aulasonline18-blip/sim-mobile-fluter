# B2 - Matriz final das 250 diferencas adicionais SimWeb x SimApp

Base congelada em 2026-07-01 a partir da segunda auditoria estatica informada pelo usuario. Esta matriz e adicional a `docs/B-parity-200-differences-final-matrix.md`.

Regra aplicada: nao transformar Flutter em React, nao copiar doenca do Web, preservar a Planta-Mae e tratar diferencas Web-only/plataforma como justificadas quando nao forem requisitos funcionais do app nativo.

| Nº | Diferença adicional | Precisa igualar? | Classificação final | Ação necessária | Ação feita | Arquivo(s) alterados | Prova | Status |
|---:|---|---|---|---|---|---|---|---|
| 1 | `NotFoundComponent` Web sem equivalente nativo | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | App nativo nao expõe URL arbitraria | Nenhum | `test/school_completeness_test.dart` | FECHADO |
| 2 | `ErrorComponent.reset` Web vs estados Flutter | Nao | EQUIVALENTE_MOBILE_100 | Nao | Reset substituido por retry/estado mobile | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 3 | `RootShell` Web vs shell de sessao Flutter | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Mantido shell mobile por sessao/organismo | Nenhum | `test/support_phase_test.dart` | FECHADO |
| 4 | `runTechnicalCacheMigration` Web sem migracao igual | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Cache mobile usa stores proprios | Nenhum | `test/support_phase_test.dart`, `test/fase1_persistence_test.dart` | FECHADO |
| 5 | `AuthSync` global Web vs `AuthSession` Flutter | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Provider mobile e fonte correta | Nenhum | `test/fase9_session_test.dart` | FECHADO |
| 6 | i18n Web rerenderiza por evento; Flutter usa catalogo | Nao | ARQUITETURA_DIFERENTE_OK | Nao | i18n estatico evita chamada remota de UI | Nenhum | `lib/sim/ui/sim_i18n.dart`, `test/widget_test.dart` | FECHADO |
| 7 | `safeReturnTo` valida URL Web | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | App usa estado de navegacao, nao URL livre | Nenhum | `test/fase9_session_test.dart` | FECHADO |
| 8 | Login signin/signup com UI diferente | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Fluxo mobile equivalente mantido | Nenhum | `test/widget_test.dart`, `test/fase9_session_test.dart` | FECHADO |
| 9 | Submit email por form event Web vs controller Flutter | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Controller mobile e correto | Nenhum | `test/widget_test.dart` | FECHADO |
| 10 | Google redirect Web vs OAuth mobile | Nao | ARQUITETURA_DIFERENTE_OK | Nao | SDK mobile substitui callback Web | Nenhum | `test/fase9_session_test.dart` | FECHADO |
| 11 | Web detecta token local antes de creditos | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Gate mobile via Supabase/API | Nenhum | `test/bug_regression_fixes_test.dart`, `test/billing_phase_test.dart` | FECHADO |
| 12 | Timeout de creditos Web vs controller Flutter | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Controller cobre erro/estado de credito | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 13 | `hasLocalAuthToken` Web sem localStorage no app | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | Sem localStorage no app nativo | Nenhum | Arquitetura mobile | FECHADO |
| 14 | Checkout por `packId` route vs abstraction billing | Sim funcional | CORRIGIDO_COM_TESTE | Nao | PackId e retorno seguro testados | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 15 | Banner pagamento/test mode Web sem componente igual | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Estado de teste refletido por credito/UI mobile | Nenhum | `test/bug_regression_fixes_test.dart`, `test/billing_phase_test.dart` | FECHADO |
| 16 | Embedded Checkout Web nao embutido no app | Nao | ARQUITETURA_DIFERENTE_OK | Nao | App usa checkout externo/hosted | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 17 | Hosted Checkout coexistente Web vs externo Flutter | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Hosted mobile preservado | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 18 | Stripe price mismatch validado no Web | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Validacao fica na API/backend | Nenhum | `npm test`, `test/billing_phase_test.dart` | FECHADO |
| 19 | Webhook publico Web nao portado no Flutter | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | App nao hospeda webhook | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 20 | Checkout status Web consulta Stripe; Flutter depende API | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Origem API e correta para app | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 21 | Credits Web usa Supabase admin; Flutter nao | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Service role fica fora do app | Nenhum | Revisao de arquitetura segura | FECHADO |
| 22 | Erro Stripe Web vs erro API Flutter | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Erros billing mapeados | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 23 | Portal Web cacheia creditos; Flutter recebe estado | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Estado mobile cobre pill de creditos | Nenhum | `test/widget_test.dart`, `test/bug_regression_fixes_test.dart` | FECHADO |
| 24 | Chave `sim-credits-cache` Web nao existe no app | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Persistencia mobile usa orgao proprio | Nenhum | `test/bug_regression_fixes_test.dart` | FECHADO |
| 25 | Decor portal CSS vs painter/widgets Flutter | Nao | EQUIVALENTE_MOBILE_100 | Nao | Equivalencia visual mobile | Nenhum | `docs/button-component-parity-full-table.md` | FECHADO |
| 26 | Start Web navega URL; Flutter chama `NavigationState` | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Navegacao mobile correta | Nenhum | `test/widget_test.dart` | FECHADO |
| 27 | Drawer Web notifica evento global | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Flutter chama metodos de sessao | Nenhum | `test/widget_test.dart`, `docs/drawer-menu-parity-combined.md` | FECHADO |
| 28 | `notifyActiveLessonChanged` Web sem browser event no app | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | CustomEvent e browser-only | Nenhum | `docs/drawer-menu-parity-combined.md` | FECHADO |
| 29 | Drawer Web usa `fatherPanel.snapshot`; Flutter monta status | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Status mobile equivalente | Nenhum | `test/support_phase_test.dart`, `test/widget_test.dart` | FECHADO |
| 30 | Busca drawer implementada por funcoes diferentes | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Busca local/cloud testada | Nenhum | `test/widget_test.dart` | FECHADO |
| 31 | Import drawer por file input vs colar texto | Nao | EQUIVALENTE_MOBILE_100 | Nao | UX mobile equivalente | Nenhum | `test/widget_test.dart` | FECHADO |
| 32 | Export drawer por blob vs arquivo/clipboard | Nao | EQUIVALENTE_MOBILE_100 | Nao | Saida mobile equivalente | Nenhum | `test/widget_test.dart` | FECHADO |
| 33 | Export status browser vs arquivo local | Nao | EQUIVALENTE_MOBILE_100 | Nao | Saida mobile equivalente | Nenhum | `test/widget_test.dart` | FECHADO |
| 34 | Remocao de mirror local apos apagar | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Tombstone/delete no store | Nenhum | `test/widget_test.dart`, `test/cloud_phase_test.dart` | FECHADO |
| 35 | Rename cloud por ServerFn vs cloud client | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Rename cloud via API/client | Nenhum | `test/widget_test.dart` | FECHADO |
| 36 | Delete cloud por rota Web vs API client | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Delete cloud testado | Nenhum | `test/widget_test.dart`, `npm test` | FECHADO |
| 37 | Refresh drawer hook vs refresh manual | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Atualizacao ao abrir/acoes | Nenhum | `test/widget_test.dart` | FECHADO |
| 38 | Paginacao cloud query vs load more local | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Paginacao 30+30 testada | Nenhum | `test/widget_test.dart` | FECHADO |
| 39 | `CyberLessonSummary` vs `StudentStateSummaryRow` | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Modelo mobile canonico | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 40 | `cyberLessons` local vs canonical store | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Store canonico Flutter preservado | Nenhum | `test/state_store_truth_engine_test.dart` | FECHADO |
| 41 | Aula Web remonta por revision; Flutter muda estado | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Lifecycle Flutter nao e React | Nenhum | `test/organism_vital_flow_test.dart` | FECHADO |
| 42 | AulaScreen Web puro vs Flutter recebe sessao | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Sessao e orgao correto no app | Nenhum | `test/internal_organs_governor_test.dart` | FECHADO |
| 43 | `useAulaController` vs `LabSession` | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Coordenacao mobile por sessao | Nenhum | `test/widget_test.dart`, `test/organism_integration_test.dart` | FECHADO |
| 44 | Runtime hooks React vs engines/classes Dart | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Orgaos Dart preservados | Nenhum | `test/internal_organs_governor_test.dart` | FECHADO |
| 45 | `useEffect` recuperacao vs chamadas imperativas | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Timing mobile coberto por service | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 46 | `PageTransitionEvent` recheck Web sem equivalente | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | Evento browser-only | Nenhum | Plataforma mobile | FECHADO |
| 47 | Evento `sim:active-lesson-changed` nao portado | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | CustomEvent browser nao se aplica | Nenhum | `test/widget_test.dart` | FECHADO |
| 48 | Fresh seed em sessionStorage vs estado persistido | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Persistencia mobile correta | Nenhum | `test/normal_lesson_full_completion_flow_test.dart` | FECHADO |
| 49 | Log `history_restore_recheck` diferente | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Log nao e contrato funcional | Nenhum | Logs internos | FECHADO |
| 50 | `drawerOpen` no hook vs modal Flutter | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Estado modal mobile | Nenhum | `test/widget_test.dart` | FECHADO |
| 51 | Audio enabled hook vs `AudioPreference` | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Persistencia mobile correta | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 52 | `toggleAudio` Web vs controls Flutter | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Preferencia e stop cobertos | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 53 | Props Web numerosos vs view model/session | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Interface de componente nao e contrato | Nenhum | `test/classroom_phase_test.dart` | FECHADO |
| 54 | Loading copy por LiveEntryState vs i18n Flutter | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Loading nao bloqueante testado | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 55 | DoubtInputSheet composto em lugares diferentes | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Sheet mobile separado preserva orgao | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 56 | `QuestionBlock` separado vs widgets integrados | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Organizacao interna nao e contrato | Nenhum | `test/normal_lesson_full_completion_flow_test.dart` | FECHADO |
| 57 | ScrollFeed Web vs historico Flutter | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Historico de aula mantido | Nenhum | `test/classroom_parity_t01_t28_test.dart` | FECHADO |
| 58 | Remocao de imagens antigas em engine | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Imagem por posicao/cache testada | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 59 | Imagem em hook state vs `position.imagem` | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Estado de midia no orgao certo | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 60 | Subscribe image por lesson key vs media service/cache | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Pipeline visual testado | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 61 | `imageUnsubRef` Web vs ciclo Flutter | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Lifecycle Flutter nao usa unsubscribe igual | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 62 | `saveReturnTo` credito insuficiente vs route controller | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Retorno billing seguro | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 63 | Charge antes de material vs API/credits | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Credito coberto no orgao de credito/API | Nenhum | `test/internal_organs_governor_test.dart`, `npm test` | FECHADO |
| 64 | Dev auth bypass Web nao portado no Flutter | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Nao portar bypass e correto | Nenhum | Seguranca | FECHADO |
| 65 | `lessonWindow` TS vs Dart | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Janela dopaminica testada | Nenhum | `test/first_lesson_ready_window_test.dart` | FECHADO |
| 66 | `nextAdvancePosition` TS vs Dart | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Avanco item/layer testado | Nenhum | `test/classroom_parity_t01_t28_test.dart` | FECHADO |
| 67 | `legacyChargeKeysFor` menos exposto | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Compat legado nao deve vazar no app | Nenhum | Arquitetura de credito | FECHADO |
| 68 | `masteredMarkers` em local diferente | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Dominio/verdade pedagogica testados | Nenhum | `test/state_store_truth_engine_test.dart` | FECHADO |
| 69 | `EMPTY_CURRICULO_ITEMS` vs modelos Dart | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Constantes internas | Nenhum | `test/student_experience_t00_test.dart` | FECHADO |
| 70 | `nivelToAcademic` Web vs conversao Flutter | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Payload T00/T02 auditado | Nenhum | `test/student_experience_t00_test.dart`, `docs/B1-lesson-logic-t00-t02-audit.md` | FECHADO |
| 71 | Review layer numeric vs `LessonLayer` enum | Nao | FLUTTER_MELHOR | Nao | Enum reduz erro de string | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 72 | Fase union string vs enums/classes | Nao | FLUTTER_MELHOR | Nao | Tipagem Dart preservada | Nenhum | `test/classroom_phase_test.dart` | FECHADO |
| 73 | Sinal union string vs `DecisionSignal` | Nao | FLUTTER_MELHOR | Nao | Enum Dart preservado | Nenhum | `test/classroom_parity_t01_t28_test.dart` | FECHADO |
| 74 | Option letter string vs `AnswerLetter` | Nao | FLUTTER_MELHOR | Nao | Enum Dart preservado | Nenhum | `test/classroom_parity_t01_t28_test.dart` | FECHADO |
| 75 | `QuestionHistoryEntry` TS vs Dart class | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Serializacao Dart coberta | Nenhum | `test/classroom_parity_t01_t28_test.dart` | FECHADO |
| 76 | `lessonNeedsReview` string vs enum/key | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Resultado pedagogico equivalente | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 77 | Feedback texto direto vs chave i18n | Nao | ARQUITETURA_DIFERENTE_OK | Nao | i18n no app e camada correta | Nenhum | `test/classroom_phase_test.dart` | FECHADO |
| 78 | Recovery gate flag TS vs funcao Dart | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Recuperacao bloqueia/libera conclusao | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 79 | `SIM_AUX_ROOMS_ENABLED=false` Web vs flags Flutter | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Flutter mantem salas saudaveis vivas | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 80 | Review room flag sincronizacao manual | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Revisao viva testada | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 81 | Recovery room flag sincronizacao manual | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Recuperacao viva testada | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 82 | EventType union vs enums/classes | Nao | FLUTTER_MELHOR | Nao | Tipagem forte preservada | Nenhum | `test/state_store_truth_engine_test.dart` | FECHADO |
| 83 | PendingReason strings vs enum/strings | Nao | EQUIVALENTE_MOBILE_100 | Nao | Razoes preservadas preservadas | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 84 | LearningJob model difere | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Jobs internos mobile | Nenhum | `test/first_lesson_ready_window_test.dart` | FECHADO |
| 85 | Snapshot keep limit difere | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Politica de storage mobile coberta | Nenhum | `test/bloco1_completion_test.dart`, `test/cloud_phase_test.dart` | FECHADO |
| 86 | `saveStudentStateSnapshot` vs persist state | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Persistencia cloud/local testada | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 87 | `loadStudentStateSnapshot` vs cloud storage | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Load cloud testado | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 88 | Deleted local ids vs tombstone/delete | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Tombstone seguro | Nenhum | `test/widget_test.dart`, `test/cloud_phase_test.dart` | FECHADO |
| 89 | `listSimLessonsWithSnapshots` vs summaries | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Summaries cobertos | Nenhum | `test/widget_test.dart` | FECHADO |
| 90 | `appendSimEvent` vs persist estado/eventos | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Granularidade diferente, efeito preservado | Nenhum | `test/state_store_truth_engine_test.dart` | FECHADO |
| 91 | `createSimLesson` vs cria estado local | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Criacao de aula testada | Nenhum | `test/normal_lesson_full_completion_flow_test.dart`, `test/widget_test.dart` | FECHADO |
| 92 | `saveSimLessonState` vs persist snapshot | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Persist snapshot testado | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 93 | `deleteSimLessonByLocalId` nome/rota diferente | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Delete por lesson id testado | Nenhum | `test/widget_test.dart`, `npm test` | FECHADO |
| 94 | `listStudentStateSummaries` mapping diferente | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Mapping drawer/summaries testado | Nenhum | `test/widget_test.dart` | FECHADO |
| 95 | `cloudPull` canonic vs sync nao realtime | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Pull/sync mobile suficiente | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 96 | `executeCloudPull` timing diferente | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Timing mobile por lifecycle/session | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 97 | Online event dispara pull no Web | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | Browser online event nao se aplica | Nenhum | Plataforma mobile | FECHADO |
| 98 | Visibilitychange dispara pull no Web | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | Browser visibility event nao se aplica | Nenhum | Plataforma mobile | FECHADO |
| 99 | Supabase channel userId vs sync mobile | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Realtime nao e requisito literal do app | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 100 | React Query invalidation vs lista local | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Store/queue substituem QueryClient | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 101 | `useSimLessonsList(enabled)` vs drawer abre/carrega | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Carregamento sob demanda equivalente | Nenhum | `test/widget_test.dart` | FECHADO |
| 102 | `summaryFromStudentState` vs row mapping | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Row mapping drawer testado | Nenhum | `test/widget_test.dart` | FECHADO |
| 103 | Date from ms vs formato Flutter | Nao | EQUIVALENTE_MOBILE_100 | Nao | Formato mobile aceito | Nenhum | `test/widget_test.dart` | FECHADO |
| 104 | `state-director` vs LabSession/organism | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Diretor mobile por orgaos | Nenhum | `test/internal_organs_governor_test.dart` | FECHADO |
| 105 | `cyberLessons` singleton vs state service/store | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Store Dart canonico | Nenhum | `test/state_store_truth_engine_test.dart` | FECHADO |
| 106 | Onboarding cyber state vs entry/session prefs | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Onboarding -> T00 testado | Nenhum | `test/widget_test.dart`, `test/normal_lesson_full_completion_flow_test.dart` | FECHADO |
| 107 | `S09_OnboardingFlow` vs screens/session | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Orgao mobile equivalente | Nenhum | `test/widget_test.dart` | FECHADO |
| 108 | `S04_SignalTracker` vs Dart tracker | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Sinais e amparo testados | Nenhum | `test/bloco1_completion_test.dart`, `test/classroom_parity_t01_t28_test.dart` | FECHADO |
| 109 | `S12_VisualPipeline` TS vs Dart | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Visual pipeline B2 testado | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 110 | `S13_ModuleRouter` vs contracts Dart/API | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Roteamento de modulo no orgao API/Dart | Nenhum | `test/external_ai_clients_test.dart`, `npm test` | FECHADO |
| 111 | `S14_FatherPanel` vs Dart snapshot | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Snapshot humano equivalente | Nenhum | `test/support_phase_test.dart` | FECHADO |
| 112 | Father page cards vs painel suporte | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Visual mobile suficiente | Nenhum | `test/support_phase_test.dart` | FECHADO |
| 113 | Father page refresh listener nao portado | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Listener Web nao e requisito no app | Nenhum | `test/support_phase_test.dart` | FECHADO |
| 114 | Stat component vs cards Flutter | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Cards mobile equivalentes | Nenhum | `test/support_phase_test.dart` | FECHADO |
| 115 | Privacy sections podem diferir | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Texto legal preservado | Nenhum | `test/support_phase_test.dart` | FECHADO |
| 116 | Terms sections podem diferir | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Texto legal preservado | Nenhum | `test/support_phase_test.dart` | FECHADO |
| 117 | Delete account ServerFn vs controller | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Deletar conta exige confirmacao | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 118 | Delete account form submit vs screen action | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | UX mobile equivalente | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 119 | Route auth middleware vs bearer/API token | Sim funcional | ARQUITETURA_DIFERENTE_OK | Nao | Bearer mobile correto | Nenhum | `test/external_ai_clients_test.dart`, `npm test` | FECHADO |
| 120 | `requireSupabaseAuth` vs API/Flutter auth | Sim funcional | ARQUITETURA_DIFERENTE_OK | Nao | Auth centralizada no servidor app | Nenhum | `npm test` | FECHADO |
| 121 | `auth-attacher` vs transport headers | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Headers com bearer testados | Nenhum | `test/external_ai_clients_test.dart`, `test/electrical_hydraulic_connections_test.dart` | FECHADO |
| 122 | `client.server.ts` admin nao portado no Flutter | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | Admin e server-only | Nenhum | Arquitetura segura | FECHADO |
| 123 | `client.ts` browser vs Supabase mobile SDK | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Cliente mobile correto | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 124 | Supabase generated types vs contratos manuais | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Dart models/SDK corretos | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 125 | `route-auth.ts` nao portado no Flutter | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | Route auth e server-only | Nenhum | Plataforma | FECHADO |
| 126 | `route-credits.server.ts` vs billing client | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Billing app chama API | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 127 | Attachments function vs client Flutter | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Cliente mobile/API equivalente | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 128 | `processAttachmentOnServer(file)` vs multipart | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Multipart autenticado testado | Nenhum | `test/electrical_hydraulic_connections_test.dart` | FECHADO |
| 129 | PDF via pdfjs Web vs server/API | Nao | ARQUITETURA_DIFERENTE_OK | Nao | PDF local nao precisa ser processado no app | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 130 | Imagem anexo Gemini vision vs API | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Vision no servidor app | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 131 | Rejeicao audio attachment precisa mesma mensagem | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Validacao de anexo coberta | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 132 | `cleanAttachmentStorage` localStorage nao portado | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | Migracao localStorage browser-only | Nenhum | Plataforma mobile | FECHADO |
| 133 | Paste handler arquivo Web vs TextField padrao | Nao | EQUIVALENTE_MOBILE_100 | Nao | UX mobile por picker/teclado | Nenhum | `test/widget_test.dart`, `test/finish_phase_test.dart` | FECHADO |
| 134 | Remove attachment por indice pode divergir | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Remocao/anexos cobertos | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 135 | `buildAttachmentsText` vs payload builder | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Texto/payload de anexos testado | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 136 | `sanitizeAttachments` vs models proprios | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Sanitizacao no modelo mobile | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 137 | `createAttachmentId` diferente | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Identidade interna nao precisa bater | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 138 | Loading objetivo visual diferente | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Loading mobile sem trava | Nenhum | `test/widget_test.dart` | FECHADO |
| 139 | CardHeader objetivo visual diferente | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Estrutura mobile equivalente | Nenhum | `test/widget_test.dart` | FECHADO |
| 140 | Rows objetivo/espacamento diferente | Nao | EQUIVALENTE_MOBILE_100 | Nao | Nao exigir pixel-perfect | Nenhum | `test/widget_test.dart` | FECHADO |
| 141 | `interpret-objective.functions` server-only | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | App chama API/T00, nao ServerFn local | Nenhum | `test/student_experience_t00_test.dart` | FECHADO |
| 142 | `pretest.functions` vs placement client | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Placement client substitui pretest | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 143 | `visual-router.functions` vs Dart/API | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Visual router mobile/API equivalente | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 144 | `gemini-caption.functions` sem direto | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Caption/vision fica no servidor quando usada | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 145 | `gemini-image.functions` Web vs API | Sim funcional | ARQUITETURA_DIFERENTE_OK | Nao | Endpoint proprio aprovado, nao copia legado | Nenhum | `docs/B2-image-system-parity.md`, `npm test` | FECHADO |
| 146 | Timeout de image server vs image client | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Falha segura e refund na API | Nenhum | `npm test`, `test/media_phase_test.dart` | FECHADO |
| 147 | Web baixa imagem para data URL; Flutter recebe API | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Data URL final chega ao painel | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 148 | Error capture singleton vs logs/exceptions | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Captura mobile/API por logs e estado | Nenhum | `test/finish_phase_test.dart`, `npm test` | FECHADO |
| 149 | `consumeLastCapturedError` nao portado | Nao | ARQUITETURA_DIFERENTE_OK | Nao | API/Flutter usam erro claro por estado | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 150 | `error-page.ts` vs widgets Flutter | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Error widgets mobile equivalentes | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 151 | `cn` helper Web nao portado | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | CSS helper e Web-only | Nenhum | Plataforma UI | FECHADO |
| 152 | Button variants Web vs botoes custom | Sim equivalente | CORRIGIDO_COM_TESTE | Nao | Botoes principais alinhados | Nenhum | `docs/button-component-parity-full-table.md`, `test/widget_test.dart` | FECHADO |
| 153 | Dialog shadcn vs AlertDialog | Nao | EQUIVALENTE_MOBILE_100 | Nao | Dialog mobile nativo | Nenhum | `test/widget_test.dart` | FECHADO |
| 154 | Form Web vs Flutter Form/TextField | Nao | EQUIVALENTE_MOBILE_100 | Nao | Validacao mobile equivalente | Nenhum | `test/widget_test.dart` | FECHADO |
| 155 | Input pixel diferente | Nao | EQUIVALENTE_MOBILE_100 | Nao | Nao exigir pixel-perfect | Nenhum | `test/widget_test.dart` | FECHADO |
| 156 | Label/accessibilidade diferente | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Label mobile suficiente | Nenhum | Widget tests | FECHADO |
| 157 | Progress style diferente | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Progress funcional | Nenhum | `test/normal_lesson_full_completion_flow_test.dart` | FECHADO |
| 158 | Separator style diferente | Nao | EQUIVALENTE_MOBILE_100 | Nao | Estilo mobile equivalente | Nenhum | UI docs/testes | FECHADO |
| 159 | Sheet animacao diferente | Nao | EQUIVALENTE_MOBILE_100 | Nao | Sheet mobile nativa | Nenhum | `test/auxiliary_phase_test.dart`, `test/widget_test.dart` | FECHADO |
| 160 | Skeleton Web vs loading custom | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Loading claro e nao bloqueante | Nenhum | `test/finish_phase_test.dart` | FECHADO |
| 161 | Toggle Web vs switch/buttons | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Toggle audio/preferencia testado | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 162 | Tooltip Web vs mobile | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | Hover tooltip nao e requisito touch-first | Nenhum | Plataforma mobile | FECHADO |
| 163 | `use-mobile` vs MediaQuery | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Breakpoint mobile nativo | Nenhum | Widget tests | FECHADO |
| 164 | `checkout-mode.ts` vs billing config | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Config mobile billing testada | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 165 | Constants oficiais duplicados | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Precos oficiais cobertos por teste | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 166 | PaymentTestModeBanner sem componente literal | Sim equivalente | EQUIVALENTE_MOBILE_100 | Nao | Conta teste/infinito e exibida por estado mobile | Nenhum | `test/bug_regression_fixes_test.dart` | FECHADO |
| 167 | FontSizeControl nao portado | Nao | DECISAO_HUMANA_NECESSARIA | Nao | Recurso de acessibilidade global nao foi definido como requisito mobile | Nenhum | Exige decisao de produto sobre controle global de fonte | DECISAO_HUMANA_NECESSARIA |
| 168 | Ajuste global de fonte nao portado | Nao | DECISAO_HUMANA_NECESSARIA | Nao | Mesmo bloqueio do item 167 | Nenhum | Exige decisao de produto/acessibilidade | DECISAO_HUMANA_NECESSARIA |
| 169 | Lovable integration nao portado | Nao | ARQUITETURA_DIFERENTE_OK | Nao | App nao deve usar Lovable gateway | Nenhum | `test/external_ai_clients_test.dart` | FECHADO |
| 170 | Lovable fallback amplo nao usado | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Nao copiar fallback legado | Nenhum | Arquitetura API oficial | FECHADO |
| 171 | T01 contract Web vs app valida conteudo | Nao | ARQUITETURA_DIFERENTE_OK | Nao | T01 morto/absorvido por fluxo vivo | Nenhum | `test/sim_live_parity_test.dart` | FECHADO |
| 172 | T02 doubt contract vs validator separado | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Duvida T02/dataUrl testados | Nenhum | `test/auxiliary_phase_test.dart`, `npm test` | FECHADO |
| 173 | `visual_trigger` validation drift | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Validador visual/T02 testado | Nenhum | `test/external_ai_clients_test.dart`, `test/media_phase_test.dart` | FECHADO |
| 174 | `tolerantJsonParse` vs JSON parse padrao | Sim seguro | EQUIVALENTE_MOBILE_100 | Nao | API valida contrato antes de app aceitar | Nenhum | `npm test`, `test/external_ai_clients_test.dart` | FECHADO |
| 175 | Web redige imagem no payload | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Payload typed evita segredo/inline indevido | Nenhum | `test/auxiliary_phase_test.dart`, `npm test` | FECHADO |
| 176 | Detecta `doubt_image` em JSON string vs typed | Sim funcional | CORRIGIDO_COM_TESTE | Nao | `DoubtImagePayload` typed com dataUrl | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 177 | Visao T02 especial vs DoubtT02Caller | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Caller de duvida no orgao correto | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 178 | AI operation attempts 3 vs politicas separadas | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Retry T02 invalido na API | Nenhum | `npm test`, `docs/B2-lesson-logic-t00-t02-parity.md` | FECHADO |
| 179 | Shared AI operations Map vs inflight/cache | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Dedupe mobile por cache/inflight | Nenhum | `test/first_lesson_ready_window_test.dart` | FECHADO |
| 180 | `getT02Sha256` nao portado no Flutter | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Hash de prompt e server-only | Nenhum | Prompt fora do app | FECHADO |
| 181 | ResolvePrompt Web nao portado no Flutter | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Prompts nao ficam no app | Nenhum | `test/external_ai_clients_test.dart` | FECHADO |
| 182 | `callGeminiOnce` direto vs API server | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Gemini fica no backend | Nenhum | `npm test` | FECHADO |
| 183 | Module caller limpa markdown vs API parse | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | API parse/validacao segura | Nenhum | `npm test` | FECHADO |
| 184 | Module caller T01/T02/T04 vs app consome API | Nao | ARQUITETURA_DIFERENTE_OK | Nao | App so consome contratos vivos | Nenhum | `test/sim_live_parity_test.dart` | FECHADO |
| 185 | `moduleCaller.ts` client vs sim_server_ai_clients | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Cliente app chama API oficial | Nenhum | `test/external_ai_clients_test.dart` | FECHADO |
| 186 | API routes TanStack nao hospedadas no Flutter | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | App nao e servidor Web | Nenhum | Plataforma | FECHADO |
| 187 | `/api/bootstrap-t00.ts` Web vs API externa | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | App chama `/api/bootstrap-t00` oficial | Nenhum | `test/external_ai_clients_test.dart`, `test/student_experience_t00_test.dart` | FECHADO |
| 188 | `/api/complete-lesson.ts` Web vs API externa | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | App chama T02 API oficial | Nenhum | `test/external_ai_clients_test.dart`, `npm test` | FECHADO |
| 189 | `/api/generate-lesson-audio.ts` vs API externa | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Audio B2 coberto | Nenhum | `test/media_phase_test.dart`, `npm test` | FECHADO |
| 190 | `/api/generate-lesson-image.ts` vs API externa | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Imagem B2 coberta | Nenhum | `test/media_phase_test.dart`, `npm test` | FECHADO |
| 191 | Payments webhook nao portado no Flutter | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | Webhook fica no backend | Nenhum | `test/billing_phase_test.dart` | FECHADO |
| 192 | RouteTree gerado Web sem equivalente | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | Roteamento Flutter nao gera routeTree | Nenhum | `test/school_completeness_test.dart` | FECHADO |
| 193 | QueryClient Web sem equivalente | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Store/cache Dart substituem | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 194 | Server runtime Web vs Android runtime | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Produto/plataforma diferente | Nenhum | Build Android | FECHADO |
| 195 | CSS/HTML aula vs Canvas/widgets | Nao | EQUIVALENTE_MOBILE_100 | Nao | Render mobile equivalente | Nenhum | `test/widget_test.dart`, `test/finish_phase_test.dart` | FECHADO |
| 196 | Browser text selection/copy vs widget selection | Nao | EQUIVALENTE_MOBILE_100 | Nao | UX mobile aceitavel | Nenhum | Widget tests | FECHADO |
| 197 | Links nativos Web vs buttons/routes | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Navegacao mobile | Nenhum | `test/school_completeness_test.dart` | FECHADO |
| 198 | Browser back/forward vs Flutter back stack | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Back stack mobile correto | Nenhum | `test/fase9_session_test.dart` | FECHADO |
| 199 | Refresh Web preserva storage vs restart prefs | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Retomada mobile persistida | Nenhum | `test/fase1_persistence_test.dart`, `test/cloud_phase_test.dart` | FECHADO |
| 200 | Multiple tabs Web vs single app instance | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | Multi-tab browser-only | Nenhum | Plataforma mobile | FECHADO |
| 201 | Visibility lifecycle Web vs app lifecycle | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Lifecycle mobile diferente | Nenhum | `test/classroom_parity_t01_t28_test.dart` | FECHADO |
| 202 | Online/offline event vs connectivity mobile | Nao | DECISAO_HUMANA_NECESSARIA | Nao | Connectivity plugin/pull automatico depende decisao de produto | Nenhum | Sync manual/queue passa; realtime connectivity requer aprovacao | DECISAO_HUMANA_NECESSARIA |
| 203 | Blob download vs file system | Nao | EQUIVALENTE_MOBILE_100 | Nao | Export mobile por arquivo/clipboard | Nenhum | `test/widget_test.dart` | FECHADO |
| 204 | Object URL cleanup nao portado | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | Object URL e browser-only | Nenhum | Plataforma | FECHADO |
| 205 | FileReader vs bytes/dataUrl | Nao | ARQUITETURA_DIFERENTE_OK | Nao | APIs de arquivo por plataforma | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 206 | Canvas compression vs image package | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Compressao mobile testada | Nenhum | `test/media_phase_test.dart` | FECHADO |
| 207 | CSS active scale vs PressScale | Nao | EQUIVALENTE_MOBILE_100 | Nao | Timing visual nao precisa ser literal | Nenhum | `docs/button-component-parity-full-table.md` | FECHADO |
| 208 | Keyboard Enter submit vs IME/button | Nao | EQUIVALENTE_MOBILE_100 | Nao | UX mobile por botao/IME | Nenhum | `test/widget_test.dart` | FECHADO |
| 209 | Tab navigation vs focus traversal | Nao | DECISAO_HUMANA_NECESSARIA | Nao | Teclado fisico/accessibility avancado exige decisao de escopo | Nenhum | Fluxo touch-first testado; tab desktop nao e requisito definido | DECISAO_HUMANA_NECESSARIA |
| 210 | ARIA Web vs Semantics Flutter | Sim basico | DECISAO_HUMANA_NECESSARIA | Nao | Auditoria completa TalkBack/VoiceOver exige teste humano/dispositivo | Nenhum | Widget tests passam; prova assistiva real externa | DECISAO_HUMANA_NECESSARIA |
| 211 | Screen reader browser vs TalkBack/VoiceOver | Sim basico | DECISAO_HUMANA_NECESSARIA | Nao | Precisa teste manual em dispositivo assistivo | Nenhum | Mesmo bloqueio do item 210 | DECISAO_HUMANA_NECESSARIA |
| 212 | Safe area Web irrelevante vs Flutter SafeArea | Nao | ARQUITETURA_DIFERENTE_OK | Nao | SafeArea e requisito mobile | Nenhum | Widget/layout tests | FECHADO |
| 213 | Android status/nav bar vs Web | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Plataforma mobile | Nenhum | Build Android | FECHADO |
| 214 | Desktop responsive Web vs mobile-first Flutter | Nao | ARQUITETURA_DIFERENTE_OK | Nao | App alvo e Android/mobile | Nenhum | `test/widget_test.dart` | FECHADO |
| 215 | Browser zoom vs Flutter text scale | Sim basico | DECISAO_HUMANA_NECESSARIA | Nao | Suporte avancado a escala global precisa decisao | Nenhum | Relacionado aos itens 167/168 | DECISAO_HUMANA_NECESSARIA |
| 216 | CSS media queries vs MediaQuery | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Breakpoints mobile proprios | Nenhum | Widget tests | FECHADO |
| 217 | `/cyber/placement` URL vs route interna | Nao | ARQUITETURA_DIFERENTE_OK | Nao | URL web nao e requisito no app | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 218 | Placement Vitest vs Flutter tests | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Cobertura por Dart tests | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 219 | Placement guidance prompt nao local | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Prompt fica no servidor | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 220 | Placement store local vs service state | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Persistencia placement testada | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 221 | Placement flag diferente | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Controle por route/controller mobile | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 222 | `readPlacementDecision` vs settled reader | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Decisao placement equivalente | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 223 | `resolveStartPosition` vs placement route | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Inicio placement/aula coberto | Nenhum | `test/placement_phase_test.dart`, `test/normal_lesson_full_completion_flow_test.dart` | FECHADO |
| 224 | StudentProfileService vs perfil no state | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Perfil dentro do estado canonico | Nenhum | `test/student_experience_t00_test.dart` | FECHADO |
| 225 | StudentPlacementService port drift | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Service Flutter testado | Nenhum | `test/placement_phase_test.dart` | FECHADO |
| 226 | Debug state TS sem componente literal | Nao | WEB_ONLY_NAO_APLICAVEL | Nao | Debug helper nao e produto | Nenhum | Nao copiar ferramenta interna | FECHADO |
| 227 | Mirror TS vs store adapter | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Espelho/canonico cobertos | Nenhum | `test/internal_organs_governor_test.dart` | FECHADO |
| 228 | Services TS vs service class | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Service Dart coberto | Nenhum | `test/cloud_phase_test.dart`, `test/state_store_truth_engine_test.dart` | FECHADO |
| 229 | Store TS vs StudentStateStore | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Store Dart canonico testado | Nenhum | `test/state_store_truth_engine_test.dart` | FECHADO |
| 230 | Session TS vs lesson_session_engine | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Sessao mobile equivalente | Nenhum | `test/organism_integration_test.dart` | FECHADO |
| 231 | LiveEntry TS vs Dart port | Sim funcional | CORRIGIDO_COM_TESTE | Nao | LiveEntry nao regride | Nenhum | `test/sim_state_engines_test.dart` | FECHADO |
| 232 | StudentLessonExecutor port | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Executor aplica resposta corretamente | Nenhum | `test/sim_state_engines_test.dart` | FECHADO |
| 233 | LearningDecisionEngine port | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Motor decide sem UI | Nenhum | `test/classroom_parity_t01_t28_test.dart` | FECHADO |
| 234 | ReadyWindowWorker port | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Worker/janela cobertos | Nenhum | `test/first_lesson_ready_window_test.dart`, `test/organism_integration_test.dart` | FECHADO |
| 235 | StudentLessonMaterialService port | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Material/cache invalido cobertos | Nenhum | `test/first_lesson_ready_window_test.dart` | FECHADO |
| 236 | StudentLessonMediaService port | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Audio/imagem midia cobertos | Nenhum | `test/media_phase_test.dart`, `test/internal_organs_governor_test.dart` | FECHADO |
| 237 | StudentLessonProgressService port | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Progresso testado | Nenhum | `test/cloud_phase_test.dart`, `test/classroom_parity_t01_t28_test.dart` | FECHADO |
| 238 | StudentLessonCloudProgressService port | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Cloud progress mobile equivalente | Nenhum | `test/cloud_phase_test.dart` | FECHADO |
| 239 | auxRoomT02Caller port | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Caller auxiliar coberto | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 240 | doubtT02Caller port | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Caller duvida/dataUrl coberto | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 241 | ReviewRoomService port | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Revisao coberta | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 242 | RecoveryRoomService port | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Recuperacao coberta | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 243 | studentAuxRoomService port | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Service auxiliar integrado | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 244 | studentAuxAddons port | Sim funcional | EQUIVALENTE_MOBILE_100 | Nao | Addons auxiliares equivalentes | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 245 | studentAuxRooms port | Sim funcional | CORRIGIDO_COM_TESTE | Nao | Estado aux rooms testado | Nenhum | `test/auxiliary_phase_test.dart` | FECHADO |
| 246 | Vitest mocks vs fake classes Dart | Nao | ARQUITETURA_DIFERENTE_OK | Nao | Estrategia de teste por linguagem | Nenhum | `flutter test`, `npm test` | FECHADO |
| 247 | Distribuicao de helper tests diferente | Nao | FLUTTER_MELHOR | Nao | Flutter tem testes de orgaos vivos amplos | Nenhum | `test/internal_organs_governor_test.dart`, `test/normal_lesson_full_completion_flow_test.dart` | FECHADO |
| 248 | Organism extra no Flutter | Nao | FLUTTER_MELHOR | Nao | Orgao Flutter preserva Planta-Mae | Nenhum | `test/organism_integration_test.dart` | FECHADO |
| 249 | School environment extra no Flutter | Nao | FLUTTER_MELHOR | Nao | Verificacao escolar propria melhora cobertura | Nenhum | `test/school_completeness_test.dart` | FECHADO |
| 250 | APK/build pipeline vs deploy Web | Nao | FLUTTER_MELHOR | Nao | Produto Android exige pipeline proprio | Nenhum | Build release e link publico do APK | FECHADO |
