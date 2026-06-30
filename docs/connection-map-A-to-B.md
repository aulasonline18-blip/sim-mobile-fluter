# Connection Map A to B

Base verificada em 2026-06-30.

- Flutter: `/root/sim-mobile-fluter`, `main`, commit `ee13bd6` (`planta sim ideal`).
- Planta-Mae: `PLANTA-MÃE DO SIM IDEAL.txt`, adicionada no commit `ee13bd6`.
- API: `/root/sim-work/sim-api`, `main`, commit `3a188f4` (`refactor: modularize sim api responsibilities`).

## Mapa Do Fluxo Vital

| # | Ponto | Arquivo | Funcao | Responsabilidade | Quem chama | Quem e chamado | Prova por trecho | Status | Risco |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Objetivo entra | `lib/features/session/lab_session.dart` | `saveObjectiveEntry` | Valida texto, gera `lessonLocalId`, salva perfil inicial e abre `/cyber/curriculo`. | `ObjetoScreen`/UI de onboarding | `_saveProfileToState`, `navigationState.openRoute` | Linhas 281-299: recorta texto, salva `freeText`, chama `_saveProfileToState`, define `entryStatus`. | Conectado | Sem `prefs`, testes/widget podem cair em caminhos dev. |
| 2 | Inicio do fluxo real | `lib/features/session/lab_session.dart` | `launchExperience` | Monta onboarding rico, cria organismo e chama experience engine. | `PhaseBoundaryScreen` | `simOrganismProvider.forLesson`, `prepareStudentExperienceEntry` | Linhas 302-366: cria args, chama engine, abre `/cyber/aula` e `openAulaRuntime`. | Conectado | Guarda `if (prefs == null && route == '/cyber/curriculo') return` evita fluxo real em testes sem prefs. |
| 3 | Organismo conecta orgaos | `lib/sim/organism/sim_organism.dart` | `SimOrganism.production` | Instancia T00/T02, cache, orchestrator, ready window, runtime, cloud queue. | `SimOrganismProvider.forLesson` | `SimServerT00Client`, `SimServerT02Client`, `StudentExperienceEngine`, `LessonRuntimeEngine` | Linhas 128-165 conectam T00/T02/experience; 189-205 conectam runtime/answer controller; 215-221 conectam shadow decision/worker. | Conectado | Placement T02 esta desabilitado (`enabled: false`) por decisao atual. |
| 4 | T00 client HTTP/SSE | `lib/sim/external_ai/sim_server_ai_clients.dart` | `SimServerT00Client.runBootstrap` | Chama servidor por SSE em `/api/bootstrap-t00`, envia ficha e headers auth. | `StudentExperienceT00Adapter` | `transport.postEventStream` | Linhas 28-55: body `ficha`, `config.uri(config.t00Path ?? simT00BootstrapPath)`, parse `data:`. | Conectado | Depende de token Supabase real nos headers. |
| 5 | Endpoint T00 API | `/root/sim-work/sim-api/src/app/router.js` | router | Protege e roteia `/api/bootstrap-t00`. | HTTP client Flutter | `t00(req,res)` | Linhas 47-61: rota protegida e POST `/api/bootstrap-t00`. | Conectado | Erros 401 ainda retornavam JSON simples sem `requestId` antes da correcao planejada. |
| 6 | Stream T00 API | `/root/sim-work/sim-api/src/t00/bootstrap-controller.js` | `createBootstrapController` | Responde SSE, emite `t00_profile`, `t00_item_partial`, `t00_final`, `done`. | Router API | Gemini streaming, parser T00 | Linhas 2-4: `text/event-stream`, `send({type:'t00_item_partial'})`, finaliza com `t00_final`. | Conectado | Teste com Gemini real depende de credenciais/modelo. |
| 7 | Processamento T00 no Flutter | `lib/sim/experience/student_experience_t00_adapter.dart` | `_drainT00Stream` | Consome chunks, salva profile, parcial e final. | `startT00UntilFirstItem` | `appendPartialCurriculumItemToState`, service state | Linhas 94-101 chamam client; 123-158 tratam `t00_item_partial`; 163-207 tratam final. | Conectado | Falha apos parcial vira fallback parcial, comportamento desejado. |
| 8 | Primeiro item salvo | `lib/sim/experience/partial_curriculum_writer.dart` | `appendPartialCurriculumItemToState` | Normaliza item parcial e escreve `StudentCurriculum` parcial no `StudentLearningState`. | T00 adapter | `StudentLearningStateService.mutate` | Usado em `student_experience_t00_adapter.dart` linhas 127-134. | Conectado | Dedupe por lista parcial em memoria, nao por estado persistido. |
| 9 | Fast path | `lib/sim/experience/student_experience_t00_adapter.dart` | `_drainT00Stream` | Completa o `Completer` no primeiro item parcial e deixa T00 continuar em background. | T00 stream | `completer.complete(first)` | Linhas 135-158: se `count == 1`, publica evento e completa. | Conectado | Coberto por teste de onboarding. |
| 10 | Engine chama T02 | `lib/sim/experience/student_experience_engine.dart` | `prepareStudentExperienceEntry` | Depois do primeiro item, chama primeira aula T02. | `LabSession.launchExperience` | `StudentExperienceT02Adapter.prepareFirstMinimumLesson` | Linhas 59-88: recebe `first`, publica fast path, chama T02 adapter. | Conectado | Se `t02` for nulo em teste, aula nao e preparada. |
| 11 | Payload T02 rico | `lib/sim/experience/student_experience_t02_adapter.dart` | `prepareFirstMinimumLesson` | Monta `CompleteLessonParams` com item, marker, layer, lang, academic, profile/envelope. | Experience engine | `StudentLessonMaterialService.resolveLessonMaterialFromStateOrEngine` | Linhas 44-64 e 170-216: merge profile/onboarding e envelope com `stable_lang`, `academic_level`, `guidance_for_T02`, etc. | Conectado | Precisa manter keys compativeis com API. |
| 12 | T02 HTTP | `lib/sim/external_ai/sim_server_ai_clients.dart` | `SimServerT02Client._call` | Chama `/api/complete-lesson`, envia payload rico e parseia material. | `LessonOrchestrator._fetchText` | `transport.postJson` | Linhas 194-212: body inclui `item`, `stable_lang`, `academic_level`, `layer`, `history`, `marker`, profile. | Conectado | `config.t02Path` precisa estar definido. |
| 13 | Endpoint T02 API | `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js` | `buildT02Payload`/`handle` | Valida dono, monta payload T02, chama Gemini e normaliza material. | Router API | Gemini text | Linhas 3-6: inclui `lessonLocalId`, `item`, `marker`, `layer`, `stable_lang`, `academic_level`, profile e envia JSON. | Conectado | Sem teste unitario local antes desta missao. |
| 14 | Material salvo | `lib/sim/lesson/student_lesson_material_service.dart` | `resolveLessonMaterialFromStateOrEngine` | Usa cache/state ou chama orchestrator ativo; salva `currentLessonMaterial` e `readyLessonMaterials`. | T02 adapter, material controller | `LessonOrchestrator.prefetchCompleteLesson` | Linhas 64-113, 286-310: le state/cache, chama T02 ativo, espelha material. | Conectado | Fonte `studentStateAfterWait` tambem cobre T02 ativo; nome e historico. |
| 15 | Cache/dedupe | `lib/sim/lesson/lesson_orchestrator.dart` | `prefetchCompleteLesson` | Usa `lessonKeyFor`, cache e `_textInflight`; prioridade ativa/background. | Material service, ready window | `_fetchText`, cache, event bus | Linhas 29-60: cache hit, inflight hit, active direto, background por semaforo. | Conectado | Cache key inclui `lessonLocalId`, evita reuse cross-lesson. |
| 16 | Cache LRU/TTL | `lib/sim/lesson/lesson_material_cache.dart` | `LessonMaterialCache` | Mantem 3 aulas, TTL 24h e SharedPreferences. | Orchestrator | SharedPreferences | Teste existente `LessonMaterialCache keeps only three living lessons`; constantes no arquivo. | Conectado | Persistencia strip de imagem por design. |
| 17 | Primeira aula exibida | `lib/features/session/lab_session.dart` + `lib/sim/classroom/lesson_runtime_engine.dart` | `openAulaRuntime`/`open` | Abre runtime e hidrata aula do estado/material pronto. | `launchExperience`, UI aula | `LessonRuntimeEngine.open` | `lab_session.dart` linhas 582-607; `lesson_runtime_engine.dart` linhas 58-119. | Conectado | Caminho dev em `prefs == null` pode mascarar teste de UI; teste vital deve usar engines reais. |
| 18 | Captura A/B/C | `lib/features/session/lab_session.dart` | `chooseAulaAnswer` | Converte letra em `AnswerLetter` e chama runtime select. | `AulaLabScreen` | `LessonRuntimeEngine.select` | Linhas 629-643; runtime linhas 122-126; controller linhas 39-46. | Conectado | Dev fallback quando sem prefs. |
| 19 | Captura 1/2/3 | `lib/features/session/lab_session.dart` | `submitAulaSignal` | Converte inteiro em `DecisionSignal` separado da letra. | `AulaLabScreen` | `LessonRuntimeEngine.signal` | Linhas 645-665; runtime linhas 128-139. | Conectado | Dev fallback quando sem prefs. |
| 20 | Tentativa salva | `lib/sim/state/student_lesson_executor.dart` | `processAnswerWithEngine` | Cria `LessonAttempt` com marker, layer, letra, sinal, correct e grava attempts. | `LessonAnswerProgressController.enviarSinal` | `decideNextActionFromState`, `applyStudentDecision` | Linhas 185-208 criam tentativa; 272-298 persistem attempts/eventos. | Conectado | Delay fixo 350ms no controller. |
| 21 | Motor decide | `lib/sim/state/learning_decision_engine.dart` | `decideNextActionFromState` | Decide `advanceLayer`, `advanceItem`, `needsReinforcement`, etc. | `processAnswerWithEngine`, shadow runner | `applyStudentDecision` | Linhas 41-169; executor linhas 210-235. | Conectado | Mastery layer adiciona outra decisao em controller. |
| 22 | Decisao aplicada/logada | `lib/sim/classroom/lesson_answer_progress_controller.dart` | `_applyPostMasteryDecision` | Reavalia mastery, aplica proximo progresso e registra `NEXT_ACTION_DECIDED`. | `enviarSinal` | `decideNextActionFromState`, `applyStudentDecision` | Linhas 221-324: salva next_action e eventos. | Conectado | Pode gerar decisao apos executor; teste vital deve verificar evento. |
| 23 | Janela A/B/C | `lib/sim/lesson/dopamine_ready_window_engine.dart` | `maintainDopamineReadyWindow` | Monta/solicita slots A/B/C; slot A ativo, B/C background; falha B/C nao bloqueia. | Material service, answer controller, worker | Orchestrator/cache/state | Linhas 90-230: eventos, prioridade `index == 0 ? active : background`, catch B/C sem rethrow. | Conectado | Falha no slot A rethrow, correto. |
| 24 | Ready window apos primeira aula | `lib/sim/experience/student_experience_t02_adapter.dart` | `prepareFirstMinimumLesson` | Dispara `prepareReadyWindowInBackground` sem aguardar B/C apos material minimo. | Experience engine | StudentLessonMaterialService | Linhas 121-150. | Conectado | Coberto por `first_lesson_ready_window_test.dart`. |
| 25 | Ready window apos resposta | `lib/sim/classroom/lesson_answer_progress_controller.dart` | `enviarSinal`/`avancar` | Solicita janela depois de sinal e apos avancar. | Runtime signal/advance | Material service | Linhas 174-190 e 476-489. | Conectado | Jobs entram em fila; worker precisa estar ativo. |
| 26 | Worker de background | `lib/sim/lesson/ready_window_worker.dart` | `startReadyWindowWorker`/`drainReadyWindowJobs` | Escuta writes e drena jobs ativos/background para lesson ativa. | `SimOrganism.production` | `DopamineReadyWindowEngine.run...` | `sim_organism.dart` linhas 147-150 e 220-221. | Conectado | Teste vital deve provar ao menos solicitacao; drenagem ja coberta por testes de ready window. |
| 27 | Sync/cloud | `lib/sim/state/student_state_store_adapter.dart` + `lib/sim/cloud/student_learning_sync.dart` | `write`/`mutate`/`enqueuePatch` | Cada write no store enfileira sync cloud. | Orgaos via stateService | `CloudQueue.enqueueStudentStateSync` | Adapter linhas 78-99; `sim_organism.dart` linhas 208-219. | Conectado | Sem auth real, queue fica pendente/inert em alguns testes. |
| 28 | Retomada | `lib/sim/state/shared_prefs_state_storage.dart` + `lib/sim/organism/sim_organism_provider.dart` | storage/provider | Rele `StudentLearningState` via SharedPreferences/Store e recria organismo. | App boot/provider | StateStore local/cloud | Coberto por `fase1_persistence_test.dart` e `cloud_phase_test.dart`. | Conectado | Precisa build real para validar SharedPreferences no APK. |

## API Server Map

| Ponto | Arquivo | Funcao | Prova | Status | Risco |
|---|---|---|---|---|---|
| Entrada pequena | `/root/sim-work/sim-api/server.js` | entrypoint | Delega para app modular. | Conectado | Nenhum, se `node --check` passar. |
| Router | `/root/sim-work/sim-api/src/app/router.js` | `createApp` | Protege rotas de IA/media e roteia health/T00/T02. | Conectado | 401 sem `requestId` antes de correcao. |
| Auth | `/root/sim-work/sim-api/src/auth/jwt-verifier.js` | `requireAuth` | Bearer obrigatorio, valida JWKS/secret/Supabase user/lab claims. | Conectado | Testes precisam token lab ou env real. |
| Health | `/root/sim-work/sim-api/src/health/health-controller.js` | `health` | Retorna status, prompts, auth flags sem segredos. | Conectado | Nao expunha `jwks` explicitamente antes de correcao planejada. |
| T00 | `/root/sim-work/sim-api/src/t00/bootstrap-controller.js` | `handle` | SSE com `t00_item_partial`, `t00_final`, `fatal`. | Conectado | Gemini real pode falhar; parse unitario necessario. |
| T02 | `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js` | `buildT02Payload`, `handle` | Payload inclui item, marker, layer, stable_lang, academic_level, profile. | Conectado | Normalizacao deve ser testada sem Gemini. |
| Logs | `/root/sim-work/sim-api/src/logs/request-logger.js` | `securityLog` | Log inclui `requestId` se header vier. | Parcial | Resposta de erro precisa incluir requestId. |

## Conclusao Parcial Do Mapeamento

As funcoes principais nao estao apenas movidas: elas estao conectadas no fluxo real do organismo. Riscos ainda exigem prova executavel:

1. Criar teste vital integrado sem fallback dev.
2. Criar/rodar testes API para auth, health, payload T02 e parser T00.
3. Garantir erro com `requestId` no servidor.
4. Rodar analyze/test/build e healthcheck.

## Tabela De Criterios B

Atualizada apos execucao do loop em 2026-06-30.

| Criterio B | Status | Prova | Se falhou, causa | Correcao |
|---|---|---|---|---|
| 1. O app compila. | PASSOU | `/opt/flutter/bin/flutter build apk --release --dart-define=FLUTTER_APP_MODE=production` gerou `build/app/outputs/flutter-apk/app-release.apk`. | - | - |
| 2. Os testes principais passam. | PASSOU | `/opt/flutter/bin/flutter test` terminou com `All tests passed!`; teste vital `test/organism_vital_flow_test.dart` incluido. | - | - |
| 3. O servidor inicia sem erro. | PASSOU | `node --check server.js`; `PORT=3105 node server.js`; `systemctl status sim-api` ativo. | - | - |
| 4. O app chama o servidor correto. | PASSOU | `lib/main.dart` instancia `SimOrganismProvider(config: SimAiServerConfig(baseUrl: simApiBaseUrl))`; `lib/sim/config/sim_environment.dart` default `http://167.179.109.137:3000`. | - | - |
| 5. A autenticacao funciona. | PASSOU | `npm test` cobre ausencia de token, token invalido e token lab valido; testes Flutter `foundation_interactions_test.dart`/`cloud_phase_test.dart` cobrem identidade Supabase. | - | - |
| 6. O T00/bootstrap e chamado no fluxo real. | PASSOU | `StudentExperienceEngine.prepareStudentExperienceEntry` chama `StudentExperienceT00Adapter.startT00UntilFirstItem`; teste vital valida `VitalT00Client.requests.length == 1`. | - | - |
| 7. O primeiro item do curriculo e recebido. | PASSOU | Teste vital emite `t00_item_partial` M1 e valida `state.curriculum.items.first.marker == M1`. | - | - |
| 8. O primeiro item e salvo no estado/curriculo correto. | PASSOU | `appendPartialCurriculumItemToState` usado pelo adapter; teste vital valida curriculo no `StudentLearningState`. | - | - |
| 9. O T02 e chamado para o primeiro item. | PASSOU | Teste vital valida `VitalT02Client.requests.isNotEmpty` e primeiro request M1/L1. | - | - |
| 10. O payload do T02 contem os campos necessarios. | PASSOU | Teste vital valida item, marker, layer, lang, academic e profile; `npm test` valida `buildT02Payload` com `stable_lang`, `academic_level`, `student_profile_internal`, `guidance_for_T02`. | - | - |
| 11. A resposta do T02 e salva como material da aula. | PASSOU | Teste vital valida `currentLessonMaterial.text_status == ready` e `readyLessonMaterials` preenchido. | - | - |
| 12. A primeira aula e exibida sem esperar imagem/audio. | PASSOU | Teste vital abre `LessonRuntimeEngine.open`, fase `lendo`, conteudo textual pronto; material textual verificado sem imagem/audio. | - | - |
| 13. A resposta A/B/C do aluno e capturada. | PASSOU | Teste vital chama `runtime.select(AnswerLetter.A)` e valida fase com letra A. | - | - |
| 14. O sinal de confianca 1/2/3 e capturado separadamente. | PASSOU | Teste vital chama `runtime.signal(DecisionSignal.one)` e valida tentativa com `sinal == one`. | - | - |
| 15. A tentativa e salva no StudentLearningState. | PASSOU | Teste vital valida `state.attempts.single` com marker, letra, sinal e `correct == true`. | - | - |
| 16. O motor pedagogico e chamado depois da tentativa. | PASSOU | Teste vital valida eventos `STUDENT_DECISION_APPLIED` e `NEXT_ACTION_DECIDED`. | - | - |
| 17. O motor decide avanco/repeticao/recuperacao/revisao. | PASSOU | `learning_decision_engine.dart` coberto por `sim_state_engines_test.dart`, `classroom_parity_t01_t28_test.dart` e teste vital valida decisao `advanceLayer`. | - | - |
| 18. A janela dopaminica prepara slots A/B/C. | PASSOU | Teste vital valida eventos `DOPAMINE_WINDOW_REQUESTED` e requisicoes L2/L3; `first_lesson_ready_window_test.dart` valida slots A/B/C. | - | - |
| 19. Slot A tem prioridade ativa. | PASSOU | `DopamineReadyWindowEngine` usa `slotPriority = index == 0 ? active : background`; coberto por testes de ready window e mapa de codigo. | - | - |
| 20. Slots B/C rodam em background. | PASSOU | Teste vital valida preparos L2/L3 apos delay de background; engine marca slots seguintes como `background`. | - | - |
| 21. Falha em B/C nao bloqueia a aula. | PASSOU | `DopamineReadyWindowEngine` rethrow apenas para `index == 0`; testes de janela e fluxo vital passam com aula textual ja aberta. | - | - |
| 22. Cache/dedupe evita chamadas duplicadas. | PASSOU | `LessonOrchestrator.prefetchCompleteLesson` usa `lessonKeyFor`, cache e `_textInflight`; suites `bloco1_completion_test.dart` e `classroom_parity_t01_t28_test.dart` passam. | - | - |
| 23. Fechar e reabrir o app mantem posicao e estado. | PASSOU | `fase1_persistence_test.dart`, `cloud_phase_test.dart` e `state_store_truth_engine_test.dart` passam. | - | - |
| 24. Erros do servidor geram logs claros. | PASSOU | `server-contract.test.js` valida `requestId` em 401/token invalido/400; `request-logger` registra `requestId`. | - | Corrigido `sendJson`/router para propagar `requestId`. |
| 25. Nenhuma funcao critica ficou apenas movida sem uso real. | PASSOU | Mapa acima mostra chamadores e chamados; teste vital atravessa T00, T02, material, runtime, tentativa, motor e janela. | - | - |
| 26. Nenhum orgao faz funcao errada. | PASSOU | Planta preservada: IA gera conteudo, software governa estado/fluxo; teste vital usa engines reais, nao `main.dart`. | - | - |
| 27. Nao existe mock/fallback de producao escondendo falha. | PASSOU | Teste vital injeta fakes apenas no teste; producao usa `SimOrganism.production`; nenhum prompt/chave foi movido para Flutter. | - | - |
| 28. O fluxo foi provado por teste automatizado ou evidencia executavel. | PASSOU | `test/organism_vital_flow_test.dart`, `npm test`, healthcheck local/public, `flutter analyze`, `flutter test`, build release. | - | - |

## Evidencias Executadas

- Flutter analyze: passou sem issues.
- Flutter test: passou, 155 testes.
- Teste vital novo: passou.
- API `node --check`: passou para entrypoint, router, auth, health, http utils e teste.
- API `npm test`: passou com `server contract tests passed`.
- API local: `GET /api/health` em `127.0.0.1:3105` retornou `status: ok`.
- API publica apos restart: `GET http://167.179.109.137:3000/api/health` retornou `status: ok`.
- Build release: passou e gerou `build/app/outputs/flutter-apk/app-release.apk`.
- Prompts: nenhum arquivo de prompt alterado.
