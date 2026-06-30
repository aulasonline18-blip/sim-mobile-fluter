# B1 - Auditoria da logica pedagogica da aula, T00, T02, duvida, revisao e recuperacao

## 1. Resumo executivo

B1 SIM.

O contrato pedagogico vivo foi mapeado de objetivo -> T00 -> curriculo/ficha -> T02 -> aula normal -> layers -> resposta -> sinal -> decisao -> duvida -> revisao -> recuperacao -> estado/cache/retomada.

Nenhum codigo foi alterado nesta auditoria. Este documento e o unico artefato criado.

Resumo das diferencas que vao para B2:

| ID B2 | Problema | Prova | Orgao correto | Arquivo candidato | Teste obrigatorio |
|---|---|---|---|---|---|
| LESSON-B2-001 | API propria nao valida T02 com a mesma rigidez do SimWeb; aceita campos vazios e defaulta `correct_answer` para A. | Web valida em `src/lib/moduleCaller.functions.ts:544-618`; API normaliza permissivamente em `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js:1-7`; Flutter tambem defaulta em `lib/sim/external_ai/sim_server_ai_clients.dart:234-263`. | API/Synapse T02 gateway + parser Flutter. | `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js`, `lib/sim/external_ai/sim_server_ai_clients.dart`. | T02 invalido deve retornar erro controlado, nao aula falsa. |
| LESSON-B2-002 | API propria nao expoe retry T02 por contrato invalido igual ao Web. | Web faz ate 3 tentativas em `moduleCaller.functions.ts:323-360`; API chama uma vez em `complete-lesson-controller.js:5-6`. | API/Synapse T02 gateway. | `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js`. | T02 malformado na 1a tentativa, valido na 2a, deve passar. |
| LESSON-B2-003 | Flutter ignora eventos SSE informativos `t00_partial_ready`, fallback gateway e `t00_quality_check`; nao quebra fluxo, mas perde telemetria/estado fino do Web. | Web emite em `routes/api/bootstrap-t00.ts:145-150`, `169-197`, `334-338`; Flutter trata apenas profile/partial/final/done/fatal em `student_experience_t00_adapter.dart:102-218`. | StudentExperienceT00Adapter / eventos de experiencia. | `lib/sim/experience/student_experience_t00_adapter.dart`. | Eventos T00 informativos devem ser preservados sem afetar primeiro item. |
| LESSON-B2-004 | Duvida com foto no Flutter envia metadado `hasDataUrl`, mas nao prova envio do `dataUrl` real no payload ate a API. | Flutter monta `doubt_image` sem `dataUrl` em `lib/sim/auxiliary/doubt_t02_caller.dart:43-53`; API espera `doubt_image.dataUrl` em `src/t02/complete-lesson-controller.js:4`. | Doubt caller / T02 payload. | `lib/sim/auxiliary/doubt_t02_caller.dart`. | Duvida com imagem deve chegar ao endpoint com data URL valida ou decisao formal de nao enviar imagem. |
| LESSON-B2-005 | Revisao/recuperacao no Flutter estao mais vivas que no Web antigo, mas precisam de prova integrada de que nao baguncam aula principal e limpam pendencias corretamente. | Flutter chama aux T02 em `student_aux_room_service.dart:153-202`; estado pendente em `student_aux_rooms.dart:58-229`; Web mostra infraestrutura com flags/no-op em `studentAuxRooms.ts:1-14` e caller travado em `auxRoomT02Caller.ts:1-21`. | StudentAuxRoomService / AuxRooms state / telas auxiliares. | `lib/sim/auxiliary/*`, `lib/features/classroom/aux_room_screens.dart`. | Revisao e recuperacao integradas: criam fila, chamam T02, registram tentativa, limpam pendencia e retornam para aula. |
| LESSON-B2-006 | Cache/material pronto ainda aceita material com campos vazios/default A ao restaurar. | `student_lesson_material_service.dart:253-273` e `lesson_material_cache.dart:153-177` recriam conteudo sem validar strings obrigatorias. | Lesson material service/cache. | `lib/sim/lesson/student_lesson_material_service.dart`, `lib/sim/lesson/lesson_material_cache.dart`. | Material cacheado invalido deve ser descartado e refeito por T02, nao exibido. |

## 2. Estamos em B1?

SIM.

Todos os itens solicitados foram mapeados com arquivo/funcoes. As diferencas saudaveis ficaram fechadas na lista B2 acima. Todos os itens receberam classificacao final.

## 3. Escopo

Incluido:

- objetivo do aluno;
- payload T00;
- eventos SSE T00;
- curriculo parcial e final;
- `ficha_for_next`, `profile`, `guidance_for_T02`, `student_profile_internal`, `interpreted_fields`;
- payload T02 da aula normal;
- resposta T02;
- layers L1/L2/L3;
- resposta A/B/C;
- feedback;
- `visual_trigger`;
- `audioText`;
- sinais 1/2/3;
- decisao pedagogica;
- duvida;
- revisao;
- recuperacao;
- estado salvo;
- cache/prefetch;
- erro/retry;
- retomada.

Nao incluido: amparo como frente propria, avatar, redesign visual, nova IA, nova UX.

## 4. Fontes lidas

Repositorios:

| Fonte | Branch | HEAD | Status |
|---|---:|---:|---|
| Flutter `/root/sim-mobile-fluter` | main | 25d2663 | `HEAD = origin/main`; working tree ja estava suja antes desta auditoria |
| API `/root/sim-work/sim-api` | main | 4ed2d6e | limpo, `HEAD = origin/main` |
| SimWeb `/root/sim-work/sim-web` | main | d113cf4 | limpo, `HEAD = origin/main` |

Planta-Mae:

- `PLANTA-MAE DO SIM IDEAL.txt:43-52`: IA gera conteudo, software governa fluxo, aluno responde, sistema valida, texto nao espera imagem/audio/cache pesado, IA nao e dona de estado/progresso/rota.
- `PLANTA-MAE DO SIM IDEAL.txt:81-101`: Assistente governa estado, fluxo, memoria, curriculo, revisao, reforco, cache, backup, chamadas IA e validacao final.
- `PLANTA-MAE DO SIM IDEAL.txt:319-354`: roteador do Tutor chama IA certa com contrato certo; backend protege chaves, aplica rate limit e valida JSON/contrato.

Arquivos principais Flutter:

- `lib/sim/experience/bootstrap_payload.dart`
- `lib/sim/external_ai/sim_server_ai_clients.dart`
- `lib/sim/experience/student_experience_t00_adapter.dart`
- `lib/sim/experience/t00_profile_writer.dart`
- `lib/sim/experience/partial_curriculum_writer.dart`
- `lib/sim/experience/student_experience_t02_adapter.dart`
- `lib/sim/lesson/lesson_orchestrator.dart`
- `lib/sim/lesson/lesson_models.dart`
- `lib/sim/lesson/student_lesson_material_service.dart`
- `lib/sim/lesson/lesson_material_cache.dart`
- `lib/sim/classroom/lesson_material_controller.dart`
- `lib/sim/classroom/lesson_answer_progress_controller.dart`
- `lib/sim/state/learning_decision_engine.dart`
- `lib/sim/state/student_lesson_executor.dart`
- `lib/sim/state/student_learning_state.dart`
- `lib/sim/auxiliary/doubt_t02_caller.dart`
- `lib/sim/auxiliary/lesson_doubt_controller.dart`
- `lib/sim/auxiliary/aux_room_t02_caller.dart`
- `lib/sim/auxiliary/student_aux_room_service.dart`
- `lib/sim/auxiliary/student_aux_rooms.dart`

Arquivos principais API:

- `/root/sim-work/sim-api/src/app/router.js`
- `/root/sim-work/sim-api/src/t00/bootstrap-controller.js`
- `/root/sim-work/sim-api/src/t00/t00-parser.js`
- `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js`
- `/root/sim-work/sim-api/src/doubt/doubt-controller.js`
- `/root/sim-work/sim-api/src/review/review-controller.js`
- `/root/sim-work/sim-api/src/recovery/recovery-controller.js`

Arquivos principais SimWeb:

- `/root/sim-work/sim-web/src/cyber/experience/StudentExperienceT00Adapter.ts`
- `/root/sim-work/sim-web/src/cyber/curriculo/bootstrapPayload.ts`
- `/root/sim-work/sim-web/src/routes/api/bootstrap-t00.ts`
- `/root/sim-work/sim-web/src/cyber/T02Service.ts`
- `/root/sim-work/sim-web/src/lib/moduleCaller.functions.ts`
- `/root/sim-work/sim-web/src/core/S13_ModuleRouter.ts`
- `/root/sim-work/sim-web/src/cyber/aula/useLessonAnswerProgressController.ts`
- `/root/sim-work/sim-web/src/sim/state/doubtT02Caller.ts`
- `/root/sim-work/sim-web/src/sim/state/auxRoomT02Caller.ts`
- `/root/sim-work/sim-web/src/sim/state/studentAuxRooms.ts`

Testes existentes usados como prova:

- `test/normal_lesson_full_completion_flow_test.dart`
- `test/classroom_parity_t01_t28_test.dart`
- `test/first_lesson_ready_window_test.dart`

## 5. Mapa T00

### 5.1 Payload exato enviado para T00 no Flutter

Flutter monta o contrato base em `buildT00Phase1Body`:

Arquivo: `lib/sim/experience/bootstrap_payload.dart:3-50`.

Payload:

```json
{
  "ficha": {
    "free_text": "data.objetivo || ''",
    "attachments_text": "data.attachments_text || ''",
    "preferred_name": "data.preferred_name || ''",
    "language": "lang",
    "idioma": "data.idioma",
    "stableLang": "data.stableLang || data.STABLE_LANG",
    "STABLE_LANG": "data.STABLE_LANG || data.stableLang",
    "nivel": "data.nivel || 'incerto'",
    "ACADEMIC_LEVEL": "data.ACADEMIC_LEVEL || academic",
    "academic_level": "data.academic_level || academic",
    "student_age": "data.student_age",
    "age_range": "data.age_range",
    "school_year": "data.school_year",
    "country_or_curriculum": "data.country_or_curriculum",
    "official_curriculum_reference": "data.official_curriculum_reference",
    "GEOGRAPHIC_ZONE": "data.GEOGRAPHIC_ZONE",
    "subject": "data.subject",
    "target_topic": "data.target_topic",
    "TARGET_TOPIC": "data.TARGET_TOPIC",
    "objetivo": "data.objetivo || ''",
    "learning_goal": "data.learning_goal",
    "exam_goal": "data.exam_goal",
    "SESSION_GOAL": "data.SESSION_GOAL",
    "prior_knowledge": "data.prior_knowledge",
    "known_weaknesses": "data.known_weaknesses",
    "difficulty_level": "data.difficulty_level",
    "student_profile_notes": "data.student_profile_notes || data.objetivo || ''",
    "emotional_learning_context": "data.emotional_learning_context",
    "cognitive_learning_context": "data.cognitive_learning_context",
    "learning_care_notes": "data.learning_care_notes",
    "student_profile_public_summary": "data.student_profile_public_summary",
    "student_profile_internal": "data.student_profile_internal",
    "interpreted_fields": "data.interpreted_fields"
  }
}
```

Cliente vivo: `SimServerT00Client.runBootstrap` em `lib/sim/external_ai/sim_server_ai_clients.dart:28-56`.

O cliente HTTP envia:

```json
{
  "ficha": {
    "...request.onboarding": "...",
    "lessonLocalId": "request.lessonLocalId",
    "language": "request.lang",
    "stableLang": "request.lang",
    "academic_level": "request.academic",
    "free_text": "request.onboarding.free_text || request.onboarding.objetivo || ''"
  },
  "timeoutMs": 140000
}
```

Endpoint: `config.t00Path ?? /api/bootstrap-t00`; Authorization vem de `config.streamHeaders()` em `sim_server_ai_clients.dart:39-43`.

### 5.2 Payload exato enviado para T00 no SimWeb

SimWeb monta contrato equivalente em `src/cyber/curriculo/bootstrapPayload.ts:3-48`, com os mesmos campos principais.

Endpoint vivo: `runBootstrapStream("/api/bootstrap-t00", buildT00Phase1Body(...))` em `src/cyber/experience/StudentExperienceT00Adapter.ts:148-180`.

Rota server: `src/routes/api/bootstrap-t00.ts:60-80`.

Autenticacao/credito Web:

- `requireRouteAuth(request)` em `bootstrap-t00.ts:64`;
- `requirePositiveCreditBalance(auth)` em `bootstrap-t00.ts:66-67`.

API propria:

- rota protegida por `protect` em `/root/sim-work/sim-api/src/app/router.js:48-66`;
- `auth.requireAuth(req)` em `router.js:51`;
- validacao de propriedade em `bootstrap-controller.js:2`;
- free text minimo em `bootstrap-controller.js:2`.

### 5.3 Diferenca T00 Flutter x SimWeb

| Campo/Evento T00 | SimWeb | Flutter | Status | Diferenca | Vai para B2? |
|---|---|---|---|---|---|
| Endpoint | `/api/bootstrap-t00` | `/api/bootstrap-t00` via API propria | COMPLETO | Mesmo caminho funcional; host/baseUrl muda por config. | Nao |
| Metodo | POST SSE | POST SSE | COMPLETO | Igual. | Nao |
| Authorization | `requireRouteAuth` no Web | `config.streamHeaders()` + `router.protect` na API | COMPLETO | Equivalente proprio. | Nao |
| Credito | Web exige saldo positivo antes do T00 | API propria protege rota; creditos ficam fora desta auditoria pedagogica | PARCIAL | Divergencia de billing nao afeta contrato pedagogico, mas pode afetar uso. | Nao nesta B1 |
| `free_text` | `ficha.free_text`, minimo 10 chars | `objetivo/free_text`, minimo API 10 chars | COMPLETO | Igual no contrato vivo. | Nao |
| anexos | `attachments_text.slice(0,24000)` | `attachments_text` enviado; API corta 24000 | COMPLETO | Igual na API propria. | Nao |
| idioma | `language/stableLang/STABLE_LANG/idioma` | `language/stableLang/academic_level` | COMPLETO | Flutter sobrescreve `stableLang` com `request.lang`, aceitavel. | Nao |
| objetivo | `objetivo/free_text/target_topic` | `objetivo/free_text` | COMPLETO | `target_topic` so vai se onboarding tiver. | Nao |
| `t00_profile` | Emitido no streaming e final com `ficha_for_next` | Persistido por `persistT00ProfileEvent` | COMPLETO | Igual quando API envia `ficha_for_next`. | Nao |
| `t00_item_partial` | Libera primeiro item | Libera primeiro item | COMPLETO | Igual. | Nao |
| `t00_partial_ready` | Emitido no Web | Ignorado no Flutter | PARCIAL | Perde telemetria/estado fino. | Sim, LESSON-B2-003 |
| `t00_quality_check` | Emitido no Web/API propria | Ignorado no Flutter | PARCIAL | Qualidade fica dentro de `ficha_for_next` quando perfil traz, mas evento nao e persistido. | Sim, LESSON-B2-003 |
| `t00_final` | Salva curriculo final | Salva curriculo final | COMPLETO | Igual. | Nao |
| `done` | Fim do stream | Flutter so completa se ja tem first; nao apaga curriculo | COMPLETO | Correto. | Nao |
| fallback gateway events | Web emite started/succeeded/failed | Flutter nao trata | PARCIAL | Telemetria perdida. | Sim, LESSON-B2-003 |

### 5.4 Como primeiro item e liberado

SimWeb:

- `StudentExperienceT00Adapter.ts:124-134` anexa parcial.
- `StudentExperienceT00Adapter.ts:96-122` resolve o primeiro item.

Flutter:

- `student_experience_t00_adapter.dart:123-160` anexa parcial.
- quando `result.count == 1`, escreve snapshot `primeiroItemRecebido` e completa o `Completer`.

Conclusao: primeiro item e liberado pelo evento `t00_item_partial`, nao pelo `t00_final`.

### 5.5 Como curriculo final e salvo

SimWeb:

- `StudentExperienceT00Adapter.ts:181-205` normaliza `result.curriculo`, grava `provisional:false`, `status:"expanded"`.

Flutter:

- `student_experience_t00_adapter.dart:163-207` normaliza `curriculo/curriculum`, grava `StudentCurriculum(provisional:false)` e `CurriculumStatusValue.expanded`.

Conclusao: completo.

### 5.6 Onde ficam `ficha_for_next`, `profile`, `guidance_for_T02`

API propria:

- `bootstrap-controller.js:2` monta `ficha_for_next` com `student_profile_internal`, `guidance_for_T01`, `guidance_for_T02`, estrategias e status.

SimWeb:

- `bootstrap-t00.ts:235-290` monta `fichaForNext`.

Flutter:

- `t00_profile_writer.dart:14-63` escreve patch no `StudentProfile`.
- `student_experience_t02_adapter.dart:44-64` mescla `stateProfile` com onboarding e preserva `guidance_for_T02`.

Conclusao: completo para fluxo vivo.

## 6. Mapa T02 aula normal

### 6.1 Quem chama T02

Flutter:

- primeira aula: `StudentExperienceT02Adapter.prepareFirstMinimumLesson` em `student_experience_t02_adapter.dart:21-151`;
- aula normal/cache: `LessonMaterialController.carregar` em `lesson_material_controller.dart:19-118`;
- chamada central: `LessonOrchestrator._fetchText` em `lesson_orchestrator.dart:146-176`.

API:

- `/api/complete-lesson` em `router.js:78` chama `t02.handle(req,res,'lesson')`.

SimWeb:

- `fetchT02LessonText` em `src/cyber/T02Service.ts:97-130`;
- `callT02Content` via `S13_ModuleRouter.ts:54-59`;
- server fn `callModuleServerFn` em `moduleCaller.functions.ts:240-367`.

### 6.2 Payload T02 Flutter/API

Flutter envia em `sim_server_ai_clients.dart:201-218`:

```json
{
  "mode": "lesson|doubt|auxiliary|placement",
  "lessonLocalId": "...",
  "item": "request.item",
  "stable_lang": "request.lang",
  "academic_level": "request.academic",
  "layer": "1|2|3",
  "err_count": "request.errCount",
  "lesson_mode": "request.mode",
  "history": "request.history",
  "marker": "request.marker?",
  "addendum": "request.addendum?",
  "amparo_level": "request.amparoLvl?",
  "...request.profile": "..."
}
```

API converte para userPayload em `complete-lesson-controller.js:3`:

- `mode`;
- `aux_mode`;
- `output_contract`;
- `lessonLocalId`;
- `item`;
- `marker`;
- `target_topic`;
- `layer`;
- `err_count`;
- `lesson_mode`;
- `history.slice(-12)`;
- `signal`;
- `stable_lang`;
- `language`;
- `preferred_name`;
- idade/serie/nivel/curriculo/subject;
- `learning_goal`, `exam_goal`, `real_use_goal`;
- `prior_knowledge`, `known_weaknesses`, `recent_errors`;
- padroes cognitivos/motivacionais;
- `student_profile_notes`;
- `student_profile_internal`;
- `guidance_for_T02`;
- `interpreted_fields`;
- `source_status`;
- `visual_policy`;
- `student_doubt`;
- `doubt_image`;
- `current_content`.

### 6.3 Payload T02 SimWeb

`src/cyber/T02Service.ts:100-126` envia para `callT02Content`:

```json
{
  "item_name": "params.item",
  "stable_lang": "params.lang",
  "academic_level": "params.academic_level || params.academic",
  "layer": "params.layer",
  "err_count": "params.errCount || 0",
  "mode": "params.mode",
  "conquest_history": "params.history.slice(-10)",
  "amparo_level": "quando mode=amparo",
  "marker": "params.marker",
  "student_profile_internal": "...",
  "guidance_for_T02": "...",
  "preferred_name": "...",
  "student_profile_notes": "...",
  "interpreted_fields": "...",
  "target_topic": "...",
  "subject": "...",
  "exam_goal": "...",
  "session_goal": "...",
  "geographic_zone": "...",
  "country_or_curriculum": "...",
  "original_text_preserved": "..."
}
```

### 6.4 Comparacao campo a campo T02

| Campo T02 | SimWeb envia? | Flutter envia? | Igual? | Diferenca | Risco |
|---|---|---|---|---|---|
| item | Sim, `item_name` | Sim, `item` | Equivalente | API propria normaliza `item`. | Baixo |
| marker | Sim | Sim | Sim | Nenhuma. | Baixo |
| layer | Sim | Sim | Sim | Uma chamada por layer. | Baixo |
| history | Sim, `conquest_history` ultimos 10 | Sim, `history`; API corta 12 | Parcial | Nome/tamanho divergem, mas sem perda funcional evidente. | Baixo |
| stable_lang | Sim | Sim | Sim | API fallback Portuguese. | Baixo |
| academic_level | Sim | Sim | Sim | Igual. | Baixo |
| mode/lesson_mode | Sim `mode` | Sim `mode` + `lesson_mode` | Sim | API propria tem ambos. | Baixo |
| err_count | Sim | Sim | Sim | Igual. | Baixo |
| profile internal | Sim | Sim | Sim | Completo. | Baixo |
| guidance_for_T02 | Sim | Sim | Sim | Completo. | Baixo |
| preferred_name | Sim | Sim | Sim | Completo. | Baixo |
| interpreted_fields | Sim | Sim | Sim | Completo. | Baixo |
| subject/target_topic/session_goal | Sim | Sim quando existe no profile | Sim | Dependente do T00/onboarding. | Baixo |
| visual_policy/source_status | Parcial/possivel | Sim se profile tiver | Parcial | Nao e obrigatorio na aula normal. | Baixo |
| output_contract | Web valida por prompt/server fn | API propria explicita em payload | Equivalente | Nao problemico. | Baixo |
| validacao contrato | Sim, strict + retry | API propria permissiva | Nao | Divergencia real. | Alto: B2 |

## 7. Mapa resposta T02

### 7.1 Campos reais

| Campo | Obrigatorio? | SimWeb | API propria | Flutter |
|---|---|---|---|---|
| `explanation` | Sim | Validado nao vazio em `moduleCaller.functions.ts:552-554` | Normaliza string vazia se faltar em `complete-lesson-controller.js:2` | Aceita string vazia em `sim_server_ai_clients.dart:244` |
| `question` | Sim | Validado nao vazio em `moduleCaller.functions.ts:555-557` | Normaliza string vazia | Aceita string vazia |
| `options.A/B/C` | Sim | Valida A/B/C nao vazios e proibe D em `moduleCaller.functions.ts:558-569` | Normaliza vazios | Aceita vazios |
| `correct_answer` | Sim/nullable controlado | Aceita null/A/B/C; invalido falha em `moduleCaller.functions.ts:570-573` | Invalido vira A | Invalido vira A |
| `why_correct` | Recomendado | Nao aparece como obrigatorio no validator | Normaliza string | Aceita |
| `why_wrong` | Recomendado | Nao obrigatorio | Aceita objeto | Aceita |
| `visual_trigger` | Opcional, mas se existe deve ser valido | Valida shape em `moduleCaller.functions.ts:574-616` | Repassa sem validar shape forte | Repassa se Map |
| `audioText` | Derivado, nao vindo do T02 | `T02Service.ts:128` deriva explanation + question | Flutter deriva em `LessonContent.audioText` | Completo |
| marker/layer metadata | Payload, nao resposta obrigatoria | Guardado pelo runtime | Guardado por `preparedMaterialFromLesson` | Completo |

### 7.2 JSON malformado, fallback falso e mock

SimWeb:

- Usa `tolerantJsonParse` para reparar problemas comuns, mas se contrato continuar invalido, falha.
- Tenta T02 ate 3 vezes em `moduleCaller.functions.ts:323-360`.
- Comentarios de arquitetura em `moduleCaller.functions.ts:301-305`: T02 oficial, sem M2 antigo, sem fallback de aula.

API propria:

- `extractJson` tenta parse/fence/primeiro objeto em `complete-lesson-controller.js:1`.
- `normalizeLessonJson` retorna objeto mesmo com campos vazios e default A.
- Isso nao e mock, mas e permissivo demais e pode virar aula falsa.

Flutter:

- `_parseT02Material` tambem aceita campos vazios e default A.

Classificacao: PARCIAL, vai para B2.

## 8. Mapa layers

### 8.1 Regra viva

O item opera com L1/L2/L3 (`LessonLayer` em `student_learning_state.dart:26-41`).

T02 e chamado uma vez por item/layer:

- chave Flutter: `lessonKeyFor` inclui `layer.value` em `lesson_models.dart:92-103`;
- request Flutter: `lesson_orchestrator.dart:146-160`;
- request Web: `T02Service.ts:23-34` inclui `params.layer`.

L1/L2/L3 nao sao preparadas em uma unica resposta T02. Cada layer tem material proprio.

### 8.2 Diagrama textual

```text
M1/L1 -> resposta A/B/C -> sinal 1/2/3 -> processAnswerWithEngine
  se correto + sinal 1 -> L3
  senao -> L2

M1/L2 -> resposta A/B/C -> sinal 1/2/3 -> processAnswerWithEngine
  se incorreto ou sinal 3 -> reforcar/refazer L2
  senao -> L3

M1/L3 -> resposta A/B/C -> sinal 1/2/3 -> processAnswerWithEngine
  se incorreto ou sinal 3 -> reforcar/refazer L3
  senao -> proximo item L1

Ultimo item/L3 consolidado -> itemIdx = totalItems -> conclusao
```

Prova Flutter:

- `learning_decision_engine.dart:90-118`: L3 consolidada avanca item; L3 fraca reforca L3.
- `learning_decision_engine.dart:119-138`: L2 consolidada vai L3; L2 fraca reforca L2.
- `learning_decision_engine.dart:139-156`: L1 correta+sinal1 vai L3; senao vai L2.
- `student_lesson_executor.dart:67-135`: aplica decisao em progress.
- `normal_lesson_full_completion_flow_test.dart:167-177`: caminho 3 itens x 3 layers.

### 8.3 Regras dos sinais

| Sinal | Regra real Flutter | Prova |
|---|---|---|
| 1 | Em L1, se correto, pula para L3; em L3 consolidada avanca item; tambem limpa pendencia se correta. | `learning_decision_engine.dart:139-147`, `student_aux_rooms.dart:58-65` |
| 2 | Nao cria certeza; tende a intermediacao/L2/L3 conforme layer e cria pendencia de duvida. | `learning_decision_engine.dart:149-156`, `student_aux_rooms.dart:86-90` |
| 3 | Marca fragilidade alta; em L2/L3 reforca mesma layer; cria pendencia de recuperacao. | `learning_decision_engine.dart:91-100`, `119-128`, `student_aux_rooms.dart:73-90` |

Testes:

- `classroom_parity_t01_t28_test.dart:234-260`: L1 certo+sinal1 -> L3; erro L1 -> L2.
- `normal_lesson_full_completion_flow_test.dart:226-312`: percorre 9 passos e conclui.

## 9. Mapa decisao pedagogica

| Pergunta | Resposta | Prova |
|---|---|---|
| Quem decide avanco? | Software: `LearningDecisionEngine` + `StudentLessonExecutor`; controller aplica e persiste. | `learning_decision_engine.dart:41-169`, `student_lesson_executor.dart:157-307`, `lesson_answer_progress_controller.dart:120-190` |
| UI decide pedagogia? | Nao. UI/controller recebe eventos de resposta/sinal; decisao vem do estado/engine. | `lesson_answer_progress_controller.dart:39-47`, `48-219` |
| Quem salva tentativa? | `processAnswerWithEngine` cria `LessonAttempt`; controller tambem emite evento `ANSWER_SUBMITTED`. | `student_lesson_executor.dart:185-208`, `lesson_answer_progress_controller.dart:204-218` |
| Quem salva sinal? | `LessonAttempt.sinal`; eventos `STUDENT_DECISION_APPLIED` e `ANSWER_SUBMITTED`. | `student_lesson_executor.dart:187-194`, `245-270` |
| Quem agenda revisao/recuperacao? | `student_aux_rooms.dart` a partir de tentativas/sinais; servicos auxiliares constroem filas. | `student_aux_rooms.dart:58-229`, `student_aux_room_service.dart:54-151` |
| Quem impede avanco indevido? | `LearningDecisionEngine` e `applyStudentDecision`. | `learning_decision_engine.dart:41-169`, `student_lesson_executor.dart:67-135` |
| Quem impede pular aula? | Runtime so avanca quando fase esta concluida. | `lesson_answer_progress_controller.dart:398-407` |

Classificacao: saudavel e alinhado com Planta-Mae.

## 10. Mapa duvida

### 10.1 Fluxo Flutter

- UI abre/fecha duvida em `lib/features/classroom/aula_screen.dart` e `lib/features/session/lab_session.dart`.
- `LessonDoubtController.submitDoubt` valida input e chama caller em `lesson_doubt_controller.dart:31-81`.
- `DoubtT02Caller.call` monta `T02LessonRequest` com item, layer, marker, profile, historico `[currentContent, text]`, `student_doubt`, imagem e adendo em `doubt_t02_caller.dart:15-61`.
- `SimServerT02Client.doubt` chama `_call(... mode:'doubt')` em `sim_server_ai_clients.dart:181-184`.
- API roteia `/api/doubt` em `router.js:79`.
- API inclui adendo de duvida em `complete-lesson-controller.js:5`.

### 10.2 Fluxo SimWeb

- `callT02ForDoubt` monta payload com `aux_mode:"doubt"`, `student_doubt`, `doubt_image`, `current_content`, profile e layer em `src/sim/state/doubtT02Caller.ts:83-124`.
- Valida imagem data URL ate 8MB em `doubtT02Caller.ts:86-93`.
- Chamada passa pelo T02 unico (`callT02Content`) em `doubtT02Caller.ts:99-113`.
- Visual pago de duvida e bloqueado sem confirmacao em `doubtT02Caller.ts:126-144`.

### 10.3 Tabela duvida

| Campo duvida | SimWeb | Flutter/API | Status | B2 |
|---|---|---|---|---|
| Botao/abertura | `useLessonDoubtController`/UI | `LabSession`/`AulaScreen` | COMPLETO | Nao |
| Texto aluno | `student_doubt` | `student_doubt` | COMPLETO | Nao |
| Default sem texto | Texto default | Texto default | COMPLETO | Nao |
| Item atual | `item.text/marker` | `itemText/marker` | COMPLETO | Nao |
| Layer | Envia layer | Envia layer | COMPLETO | Nao |
| Profile/ficha | Envia profile e internal | Envia `AuxRoomProfile.toJson` | COMPLETO | Nao |
| Conteudo atual | `current_content` estruturado | `history` com currentContent + texto | PARCIAL | Possivel alinhamento se necessario |
| Foto/anexo | Envia `dataUrl` | Flutter caller mostra metadado e `hasDataUrl`; API espera `dataUrl` | PARCIAL | LESSON-B2-004 |
| Resposta | `explanation` + `visual_trigger` | `DoubtResponse.explanation` + `visualTrigger` | COMPLETO | Nao |
| Muda progresso/layer/item | Nao | Nao encontrado alterando progresso principal | COMPLETO | Nao |
| Erro | Mensagem de erro controlada | `defaultDoubtError` | COMPLETO | Nao |

## 11. Mapa revisao

### 11.1 SimWeb

Web possui infraestrutura de estado para revisao, mas o proprio arquivo indica fase historica desligada:

- `studentAuxRooms.ts:1-14`: infraestrutura shadow/no-op quando flags desligadas.
- `buildReviewQueue` em `studentAuxRooms.ts:218-282`: fila prioriza pendencias e completa sequencialmente.
- `auxRoomT02Caller.ts:1-21`: caller auxiliar implementado com travas/flags.
- `auxRoomT02Caller.ts:183-220`: chamada T02 unica com adendo quando habilitada.

### 11.2 Flutter

Flutter tem implementacao ativa:

- filas em `student_aux_rooms.dart:166-202`;
- `StudentAuxRoomService.buildReviewQueueForLesson` em `student_aux_room_service.dart:54-106`;
- prepara questao chamando T02 em `student_aux_room_service.dart:153-202`;
- registra resposta em `student_aux_room_service.dart:204-228`;
- completa sessao em `student_aux_room_service.dart:230-247`.

### 11.3 Tabela revisao

| Campo revisao | SimWeb | Flutter | Status | B2 |
|---|---|---|---|---|
| Quem cria fila | `buildReviewQueue` | `buildReviewQueueForLesson` | COMPLETO | Nao |
| Qual sinal cria | Sinal 2 ou erro/sinal 3 entra em pending; revisao usa pendencias | Igual em `student_aux_rooms.dart` | COMPLETO | Nao |
| Guarda marker/layer/item | Sim | Guarda marker/layer; itemIdx aparece nulo no registro atual do Flutter | PARCIAL | LESSON-B2-005 |
| Payload T02 | Aux T02 com `aux_mode review`, signal, marker, item, addon | Aux T02 com mode review, layer L1 tecnico, addendum, profile | PARCIAL | LESSON-B2-005 |
| Resposta | Conteudo T02 | `AuxRoomContent.fromLesson` | COMPLETO | Nao |
| Conclui/limpa pendencia | Infraestrutura | Implementado, precisa prova integrada | PARCIAL | LESSON-B2-005 |
| Nao bagunca aula principal | Web no-op/flags | Flutter separado em aux service/UI | PARCIAL por falta de prova integrada | LESSON-B2-005 |

## 12. Mapa recuperacao

### 12.1 SimWeb

- `studentAuxRooms.ts:288-320`: `buildRecoveryQueue` usa pendencias.
- `shouldBlockFinalCompletionForRecovery` existe no Web e no Flutter com regra de pendencia.
- Caller T02 auxiliar segue mesma estrutura da revisao.

### 12.2 Flutter

- `student_aux_rooms.dart:204-229`: fila de recuperacao e bloqueio final por pendencias.
- `student_aux_room_service.dart:108-151`: constroi fila e mapa de sinal por marker.
- `student_aux_room_service.dart:249-314`: eventos `RECOVERY_REQUIRED`, `RECOVERY_STARTED`, `FINAL_COMPLETION_BLOCKED_BY_PENDING`, `RECOVERY_COMPLETED`.
- `AuxRoomT02Caller.call` chama `client.auxiliaryRoom` com mode `recovery` em `aux_room_t02_caller.dart:131-159`.

### 12.3 Tabela recuperacao

| Campo recuperacao | SimWeb | Flutter | Status | B2 |
|---|---|---|---|---|
| Quem cria fila | `buildRecoveryQueue` | `buildRecoveryQueueForLesson` | COMPLETO | Nao |
| Qual sinal cria | Sinal 3 ou erro | Sinal 3 ou erro | COMPLETO | Nao |
| Recuperacao volta para layer 1 | Aux payload Web nao usa layer normal; Flutter usa `LessonLayer.l1` tecnico | PARCIAL | LESSON-B2-005 |
| Usa adendo | Sim, `getAuxRoomAddon` | Sim, `getAuxRoomAddonReference` | COMPLETO | Nao |
| Payload T02 | Aux T02 unico | Aux T02 unico pela API propria | PARCIAL | LESSON-B2-005 |
| Bloqueia conclusao | Web previsto por gate | Flutter `shouldBlockFinalCompletionForRecovery` | COMPLETO, precisa prova integrada | LESSON-B2-005 |
| Limpa pendencia | Previsto | `clearPendingIfSignalOne` | COMPLETO, precisa prova integrada | LESSON-B2-005 |
| Volta para aula principal | Aux screens/session | Aux screens/session | PARCIAL por falta de prova integrada | LESSON-B2-005 |

## 13. Mapa estado/cache

| Pergunta | Local Flutter | Status |
|---|---|---|
| Onde fica curriculo? | `StudentLearningState.curriculum`, tipos em `student_learning_state.dart:194-230` | COMPLETO |
| Onde fica current item/layer/marker? | `LessonCurrent` em `student_learning_state.dart:287-313` | COMPLETO |
| Onde fica progresso? | `LessonProgress` em `student_learning_state.dart:315-360+` | COMPLETO |
| Onde fica material atual? | `currentLessonMaterial` usado em `student_lesson_material_service.dart:276-327` | COMPLETO |
| Onde ficam materiais prontos? | `readyLessonMaterials`, lido em `student_lesson_material_service.dart:241-273` | COMPLETO |
| Onde fica fila de proximas aulas? | `queuedActions` em `maintainLessonReadyWindow`, `student_lesson_material_service.dart:205-239` | COMPLETO |
| Onde fica revisao pendente? | `auxRooms.pendingMap`, `student_aux_rooms.dart:27-56` | COMPLETO |
| Onde fica recuperacao pendente? | `auxRooms.pendingMap/recovery`, `student_aux_rooms.dart:204-229` | COMPLETO |
| Onde ficam tentativas? | `StudentLearningState.attempts`, escrito em `student_lesson_executor.dart:185-208` | COMPLETO |
| Onde ficam sinais? | `LessonAttempt.sinal`, `student_learning_state.dart:6-23` e executor | COMPLETO |
| Onde fica historico? | `LessonProgress.historia`, `QuestionHistoryEntry` no controller | COMPLETO |
| Onde fica erro/loading? | `ClassroomPhase.loading/engineError`, eventos `*_FAILED` | COMPLETO |
| Onde fica retry? | Web retry T02 no server; API propria nao tem retry T02 por contrato | PARCIAL |
| Onde fica cache T02? | `LessonMaterialCache` 3 aulas/24h, `lesson_material_cache.dart:10-124` | COMPLETO |
| Onde fica prefetch? | `DopamineReadyWindowEngine`, `maintainLessonReadyWindow` | COMPLETO |
| Onde fica persistido? | `StudentLearningState.toJson/fromJson` e stores; roundtrip ja existe em testes de cloud | COMPLETO |
| Onde fica sync/backup? | Fora do escopo profundo desta B1; ja mapeado em docs B-sync | REFERENCIA |

Ordem de material:

1. `StudentLearningState.readyLessonMaterials`;
2. cache em memoria/persistido;
3. T02 via orchestrator.

Prova: `student_lesson_material_service.dart:67-118` e comentario `Planta-Mae §10` em `student_lesson_material_service.dart:329-330`.

## 14. Comparacao SimWeb x Flutter/API

| Comportamento | SimWeb | Flutter/API | Classificacao |
|---|---|---|---|
| T00 por SSE | Sim | Sim | COMPLETO |
| Primeiro item por parcial | Sim | Sim | COMPLETO |
| T00 final substitui curriculo provisional | Sim | Sim | COMPLETO |
| `done` nao apaga curriculo | Sim | Sim | COMPLETO |
| `ficha_for_next` para T02 | Sim | Sim | COMPLETO |
| T02 uma chamada por layer | Sim | Sim | COMPLETO |
| `audioText` derivado de explicacao+pergunta | Sim | Sim | COMPLETO |
| `visual_trigger` preservado | Sim | Sim | COMPLETO |
| Validacao T02 estrita | Sim | Nao totalmente | PARCIAL |
| Retry T02 por contrato invalido | Sim | Nao na API propria | AUSENTE |
| Motor de decisao no software | Sim | Sim | COMPLETO |
| UI nao decide pedagogia | Sim | Sim | COMPLETO |
| Duvida texto | Sim | Sim | COMPLETO |
| Duvida foto | Sim | Parcial | PARCIAL |
| Revisao | Web infra/flags; Flutter vivo | Parcial por prova integrada | PARCIAL |
| Recuperacao | Web infra/flags; Flutter vivo | Parcial por prova integrada | PARCIAL |
| Cache/prefetch 3 aulas | Sim | Sim | COMPLETO |
| Retomada por estado | Sim | Sim | COMPLETO |

## 15. Lista do que esta completo

- Payload T00 principal.
- Endpoint T00 protegido.
- Eventos T00 `t00_profile`, `t00_item_partial`, `t00_final`, `done`, `fatal`.
- Primeiro item por parcial.
- Curriculo final.
- Persistencia de `ficha_for_next/guidance_for_T02/student_profile_internal/interpreted_fields`.
- Payload T02 normal com item, marker, layer, historico, profile, idioma e nivel.
- Uma chamada T02 por layer.
- Resposta T02 convertida para `LessonContent`.
- `visual_trigger` preservado ate `LessonContent`.
- `audioText` derivado.
- Resposta A/B/C.
- Tentativa/sinal salvos no estado.
- Decisao por engine/software.
- Avanco layer/item/conclusao.
- Cache/prefetch de material.
- Retomada por `StudentLearningState`.
- Duvida por texto.
- Infraestrutura de revisao/recuperacao.

## 16. Lista do que esta parcial

- Validacao T02 no Flutter/API propria.
- Retry T02 da API propria quando contrato invalido.
- Eventos informativos T00/fallback gateway/quality check no Flutter.
- Duvida com foto no Flutter ate API.
- Revisao/recuperacao precisam prova integrada fechada.
- Cache/material pronto precisa rejeitar material pedagogico invalido.

## 17. Lista do que esta ausente

- Retry T02 por contrato invalido na API propria equivalente ao Web.

## 18. Lista do que esta mockado/falso

Nao foi encontrado mock de aula normal vivo nesta auditoria.

Risco de falso positivo: parser permissivo pode transformar resposta invalida em aula aparentemente valida com campos vazios/default A. Classificado como PARCIAL, nao como mock intencional.

## 19. Lista do que esta no orgao errado

Nao foi encontrada logica pedagogica decisoria dentro da UI.

Ponto de atencao: `LessonAnswerProgressController` orquestra evento de resposta e chama engines/servicos; isso esta aceitavel porque a decisao real vem de `processAnswerWithEngine`/`LearningDecisionEngine`, nao do widget.

## 20. Lista final fechada para B2

| ID B2 | Problema | Prova | Orgao correto | Arquivo candidato | Teste obrigatorio |
|---|---|---|---|---|---|
| LESSON-B2-001 | Alinhar validacao T02 API/Flutter ao contrato saudavel do Web. | Web `validateT02Contract`; API/Flutter defaults permissivos. | API T02 gateway + Flutter parser. | `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js`, `lib/sim/external_ai/sim_server_ai_clients.dart`. | T02 sem explanation/question/options nao vira aula. |
| LESSON-B2-002 | Implementar retry T02 por contrato invalido na API propria ou equivalente aprovado. | Web tenta 3 vezes; API propria tenta 1. | API T02 gateway. | `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js`. | 1a resposta invalida, 2a valida. |
| LESSON-B2-003 | Persistir/espelhar eventos T00 informativos sem quebrar fast path. | `t00_partial_ready`, fallback gateway, quality check ignorados pelo Flutter. | StudentExperienceT00Adapter/event store. | `lib/sim/experience/student_experience_t00_adapter.dart`. | Eventos SSE extras nao quebram e ficam auditaveis. |
| LESSON-B2-004 | Corrigir/provar envio de imagem real na duvida com foto. | Flutter envia metadado; API espera dataUrl. | Doubt caller/API payload. | `lib/sim/auxiliary/doubt_t02_caller.dart`, API T02. | Duvida com foto contem data URL e API recebe inlineData. |
| LESSON-B2-005 | Provar revisao/recuperacao integradas sem baguncar aula principal. | Servicos existem, mas precisam fluxo integrado fechado. | StudentAuxRoomService/AuxRooms/UI. | `lib/sim/auxiliary/*`, `lib/features/classroom/aux_room_screens.dart`. | Revisao e recuperacao com fila, T02, tentativa, limpeza e retorno. |
| LESSON-B2-006 | Rejeitar material cacheado/pronto invalido. | Cache/ready state aceita campos vazios/default A. | LessonMaterialService/Cache. | `lib/sim/lesson/student_lesson_material_service.dart`, `lib/sim/lesson/lesson_material_cache.dart`. | Cache invalido e descartado/refeito. |

## 21. Prova de cobertura

### 21.1 T00 mapeado

- Flutter payload: `bootstrap_payload.dart:3-50`.
- Flutter cliente: `sim_server_ai_clients.dart:28-56`.
- Flutter adapter: `student_experience_t00_adapter.dart:23-281`.
- Flutter profile writer: `t00_profile_writer.dart:14-63`.
- Flutter partial writer: `partial_curriculum_writer.dart:39-102`.
- API T00: `bootstrap-controller.js:1-5`, `t00-parser.js:1-6`.
- SimWeb T00 adapter: `StudentExperienceT00Adapter.ts:73-278`.
- SimWeb payload: `bootstrapPayload.ts:3-48`.
- SimWeb route: `bootstrap-t00.ts:60-340`.

### 21.2 T02 mapeado

- Flutter contract: `pedagogical_module_contracts.dart:28-90`.
- Flutter client/parser: `sim_server_ai_clients.dart:160-264`.
- Flutter orchestrator: `lesson_orchestrator.dart:146-176`.
- Flutter first lesson: `student_experience_t02_adapter.dart:21-151`.
- Flutter material controller: `lesson_material_controller.dart:19-207`.
- API T02 route: `router.js:78-81`.
- API T02 controller: `complete-lesson-controller.js:1-8`.
- SimWeb T02 service: `T02Service.ts:97-130`.
- SimWeb S13: `S13_ModuleRouter.ts:54-59`.
- SimWeb validation/retry: `moduleCaller.functions.ts:301-360`, `499-618`.

### 21.3 Layers/decisao mapeadas

- Flutter engine: `learning_decision_engine.dart:41-169`.
- Flutter executor: `student_lesson_executor.dart:49-307`.
- Flutter controller: `lesson_answer_progress_controller.dart:39-515`.
- SimWeb controller: `useLessonAnswerProgressController.ts:37-247`.
- Teste fluxo completo: `normal_lesson_full_completion_flow_test.dart:167-312`.
- Teste paridade sinais: `classroom_parity_t01_t28_test.dart:230+`.

### 21.4 Duvida mapeada

- Flutter input/controller/caller: `lesson_doubt_controller.dart:31-81`, `doubt_t02_caller.dart:15-61`.
- API route/controller: `router.js:79`, `complete-lesson-controller.js:3-6`.
- SimWeb caller: `doubtT02Caller.ts:83-144`.

### 21.5 Revisao/recuperacao mapeadas

- Flutter aux caller: `aux_room_t02_caller.dart:52-160`.
- Flutter aux service: `student_aux_room_service.dart:54-314`.
- Flutter aux state: `student_aux_rooms.dart:58-244`.
- SimWeb aux caller: `auxRoomT02Caller.ts:1-220`.
- SimWeb aux state: `studentAuxRooms.ts:1-320`.

### 21.6 Estado/cache/retomada mapeados

- `StudentLearningState`: `student_learning_state.dart:1-360+`.
- Material service: `student_lesson_material_service.dart:67-118`, `241-327`, `329-360`.
- Cache: `lesson_material_cache.dart:10-181`.
- Teste de persistencia no fluxo normal: `normal_lesson_full_completion_flow_test.dart:264-283`.

### 21.7 Classificacao fechada

Itens completos:

- T00 principal.
- T02 normal principal.
- Layers L1/L2/L3.
- Decisao de avanco.
- Estado e retomada.
- Duvida por texto.
- Cache/prefetch.

Itens parciais/ausentes:

- LESSON-B2-001 a LESSON-B2-006.

Itens sem classificacao:

- Nenhum.

Itens sem verificacao:

- Nenhum dentro do escopo B1.

## 22. Veredito final

B1 SIM.

O contrato pedagogico vivo foi mapeado e comparado. A lista B2 esta fechada com 6 itens. Nenhum codigo foi alterado, nenhum commit foi feito e nenhum push foi feito.
