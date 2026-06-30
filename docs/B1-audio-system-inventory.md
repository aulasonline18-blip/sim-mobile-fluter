# B1 - Inventario total do sistema de audio do SimWeb e comparacao com SimApp

## 1. Resumo executivo

Estado final desta auditoria: **B1 SIM**.

O sistema saudavel de audio do SimWeb foi identificado em codigo, classificado e comparado com o SimApp Flutter. Foram encontrados **18 comportamentos vivos** de audio no SimWeb. No Flutter/API do app, o resultado da comparacao e:

| Status Flutter | Quantidade |
|---|---:|
| COMPLETO | 11 |
| PARCIAL | 5 |
| EXISTE MAS NAO CONECTADO | 1 |
| AUSENTE | 1 |
| NAO DEVE COPIAR | 0 |

Lista final para B2:

1. Conectar preparo antecipado de `audioText` no fluxo vivo/cache/prefetch do Flutter, equivalente ao `audioCore.prepareText` do Web.
2. Garantir fallback para TTS local quando a chamada de audio gerado falhar por excecao HTTP/API.
3. Alinhar voz/idioma entre Flutter e API propria: hoje o Flutter chama sem `voice`, o controller usa default `Kore`, enquanto o Web usa `cedar` no cliente e mapa `Charon/Fenrir` no endpoint.
4. Provar e/ou corrigir parada de audio em todos os avancos/trocas de item/layer/desmontagem da aula.
5. Conectar audio de duvida no fluxo vivo Flutter ou registrar decisao de nao usar audio em duvida no app.
6. Provar e/ou conectar revisao, recuperacao e amparo ao mesmo caminho de audio da aula.
7. Criar teste especifico para erro de audio gerado com fallback nao bloqueante.

## 2. Definicao da cidade A

Nao havia prova fechada de tudo que o SimWeb possui no sistema de audio nem de tudo que ja existe, esta parcial ou falta no SimApp Flutter.

## 3. Definicao da cidade B1

B1 significa: sistema saudavel de audio do SimWeb identificado, classificado, provado em codigo, comparado com Flutter/API do app, e toda diferenca saudavel colocada na lista final para B2.

## 4. Inventario do Flutter atual

| ID Flutter | Arquivo | Funcao/classe | O que faz | Status | Precisa comparar com Web? |
|---|---|---|---|---|---|
| AUD-FLT-001 | `lib/sim/media/audio_preference.dart:5` | `AudioPreference` | Preferencia persistida `sim-audio-enabled-v1`, default ligado, listeners. | COMPLETO | Sim |
| AUD-FLT-002 | `lib/sim/media/audio_core.dart:60` | `AudioCore` | Orquestra geracao, cache em memoria, playback, TTS de plataforma e stop. | PARCIAL | Sim |
| AUD-FLT-003 | `lib/sim/media/audio_core.dart:90` | `speak` | Se audio desligado retorna sem chamar gerador; usa cache; chama cliente; cai para TTS local quando cliente retorna vazio. | PARCIAL | Sim |
| AUD-FLT-004 | `lib/sim/media/audio_core.dart:149` | `audioCacheKey` | Chave por `lessonKey|lang|voice|hash(text)`. | COMPLETO | Sim |
| AUD-FLT-005 | `lib/sim/media/audio_core.dart:167` | `stableLangToBCP47` | Mapeia idioma estavel para BCP-47. | COMPLETO | Sim |
| AUD-FLT-006 | `lib/sim/media/lesson_audio_controller.dart:24` | `playConteudo` | Monta sequencia falada com explicacao, pergunta e alternativas A/B/C. | COMPLETO | Sim |
| AUD-FLT-007 | `lib/sim/media/lesson_audio_controller.dart:58` | `ouvirAula` | Botao alterna ouvir/parar. | COMPLETO | Sim |
| AUD-FLT-008 | `lib/sim/media/student_lesson_media_service.dart:27` | `prepareLessonAudioText` | Prepara texto e registra `AUDIO_READY`. | PARCIAL | Sim |
| AUD-FLT-009 | `lib/sim/media/student_lesson_media_service.dart:94` | `playLessonAudioSequence` | Registra started/ready/failed em `StudentLearningState`. | COMPLETO | Sim |
| AUD-FLT-010 | `lib/sim/media/doubt_audio.dart:4` | `DoubtAudio` | Audio de duvida com sufixo `:doubt`, respeita preferencia. | EXISTE MAS NAO CONECTADO | Sim |
| AUD-FLT-011 | `lib/sim/media/lesson_audio_api_contract.dart:1` | `GenerateLessonAudioRequest` | Normaliza texto, idioma e lessonKey. | COMPLETO | Sim |
| AUD-FLT-012 | `lib/sim/external_ai/sim_server_ai_clients.dart:120` | `SimServerGeneratedAudioClient.generateAudio` | Chama `/api/generate-lesson-audio` com auth/config do app. | COMPLETO | Sim |
| AUD-FLT-013 | `lib/features/session/lab_session.dart:614` | `_audioControllerFor` | Injeta `AudioCore`, client da API e provider de idioma. | PARCIAL | Sim |
| AUD-FLT-014 | `lib/features/session/lab_session.dart:989` | `toggleAudio` | UI inicia/paralisa audio e mostra erro/loading sem travar aula. | COMPLETO | Sim |
| AUD-FLT-015 | `lib/features/classroom/aula_screen.dart:483` | status audio | Renderiza loading/erro/audio ligado. | COMPLETO | Sim |
| AUD-FLT-016 | `lib/features/classroom/aula_screen.dart:744` | `_FixedBubble` | Bolha fixa quando `audioEnabled && audioPlaying`. | COMPLETO | Sim |
| AUD-FLT-017 | `lib/sim/classroom/lesson_answer_progress_controller.dart:39` | `selecionar/enviarSinal` | Para audio ao selecionar resposta e enviar sinal. | PARCIAL | Sim |
| AUD-FLT-018 | `lib/sim/lesson/lesson_models.dart:24` | `LessonContent.audioText` | Deriva audioText de explicacao + pergunta. | COMPLETO | Sim |
| AUD-FLT-019 | `lib/sim/lesson/lesson_material_cache.dart:131` | cache material | Persiste `audioText` junto do material de aula. | COMPLETO | Sim |
| AUD-FLT-020 | `test/media_phase_test.dart:85` | testes audio | Prova preferencia, cache, controller, duvida e contrato API. | COMPLETO | Sim |

## 5. Termos buscados no SimWeb

Busca textual executada com `rg -i --fixed-strings`, excluindo `node_modules`, `dist`, `build` e `coverage`.

| Termo | Resultados |
|---|---:|
| audio | 216 |
| áudio | 23 |
| sound | 2 |
| voice | 25 |
| speech | 16 |
| tts | 13 |
| text to speech | 0 |
| text_to_speech | 0 |
| speak | 36 |
| speaker | 0 |
| mute | 103 |
| unmute | 0 |
| volume | 17 |
| play | 82 |
| pause | 14 |
| stop | 25 |
| bubble | 10 |
| bolha | 0 |
| pulsante | 0 |
| pulse | 20 |
| mouth | 0 |
| boca | 3 |
| professor | 15 |
| avatar | 7 |
| media | 50 |
| cache | 367 |
| prefetch | 27 |
| fallback | 149 |
| error | 808 |
| erro | 1004 |
| audioText | 23 |
| audio_text | 0 |
| narration | 0 |
| narração | 0 |
| stable_lang | 44 |
| language | 186 |
| voiceId | 0 |
| voice_id | 0 |
| elevenlabs | 0 |
| openai audio | 0 |
| gemini audio | 0 |
| generate audio | 0 |
| audio controller | 0 |
| audio service | 0 |
| audio cache | 0 |
| audio player | 0 |
| audio queue | 0 |
| audio enabled | 0 |
| audio disabled | 0 |
| disable audio | 0 |
| enable audio | 0 |

Busca por nome/importacao executada com `rg --files` e `rg -n` sobre imports/chamadas de `audioCore`, `audio-preference`, `useLessonAudioController`, `studentLessonMediaService`, `FixedBubble`, `generate-lesson-audio`.

## 6. Arquivos candidatos encontrados

### SimWeb

| Arquivo candidato | Ocorrencias relevantes | Classificacao |
|---|---:|---|
| `src/cyber/audio.ts` | 83 | Relevante |
| `src/cyber/audio-preference.ts` | 9 | Relevante |
| `src/cyber/aula/useLessonAudioController.ts` | 19 | Relevante |
| `src/cyber/aula/useLessonPlaybackEngine.ts` | import/chamada viva | Relevante |
| `src/cyber/aula/useLessonDoubtController.ts` | import/chamada viva | Relevante |
| `src/cyber/aula/useDoubtAudio.ts` | 10 | Relevante |
| `src/cyber/aula/LessonMainScreen.tsx` | UI toggle/bolha | Relevante |
| `src/cyber/aula/FixedBubble.tsx` | 2 | Relevante |
| `src/cyber/aula/LessonAvatar.tsx` | 8 | Legado visual, sem uso vivo encontrado |
| `src/cyber/lesson-pipeline-runtime.ts` | chamadas `audioCore.prepareText` | Relevante |
| `src/cyber/lesson-material-cache.ts` | 37 | Relevante para cache de material/audioText |
| `src/sim/lesson/studentLessonMediaService.ts` | 30 | Relevante |
| `src/sim/state/studentLearningState.services.ts` | mirror audio | Relevante |
| `src/sim/state/studentLearningState.types.ts` | tipos `AUDIO_JOB_*` | Relevante |
| `src/routes/api/generate-lesson-audio.ts` | 19 | Relevante |
| `public/avatars/sim-professor-v1.jpg` | 0 textual | Asset, sem logica de audio |
| `src/routeTree.gen.ts` | rota gerada | Gerado, descartado como fonte de comportamento |

### Flutter/API app

| Arquivo candidato | Ocorrencias relevantes | Classificacao |
|---|---:|---|
| `lib/sim/media/audio_core.dart` | 52 | Relevante |
| `lib/sim/media/audio_preference.dart` | 22 | Relevante |
| `lib/sim/media/lesson_audio_controller.dart` | 22 | Relevante |
| `lib/sim/media/student_lesson_media_service.dart` | 76 | Relevante |
| `lib/sim/media/doubt_audio.dart` | 12 | Relevante |
| `lib/sim/media/lesson_audio_api_contract.dart` | 15 | Relevante |
| `lib/sim/media/platform_audio_adapter.dart` | 18 | Relevante |
| `lib/sim/external_ai/sim_server_ai_clients.dart` | cliente API | Relevante |
| `lib/features/session/lab_session.dart` | controller/UI state | Relevante |
| `lib/session/lesson_ui_state.dart` | estado UI audio | Relevante |
| `lib/features/classroom/aula_screen.dart` | status/bolha | Relevante |
| `lib/features/classroom/aula_widgets.dart` | toggle topbar | Relevante |
| `lib/sim/ui/widgets/lesson_audio_controls.dart` | widget alternativo | Relevante auxiliar |
| `lib/sim/ui/widgets/fixed_bubble.dart` | widget alternativo | Relevante auxiliar |
| `lib/sim/ui/widgets/lesson_avatar.dart` | avatar | Auxiliar visual |
| `lib/sim/lesson/lesson_models.dart` | `audioText` | Relevante |
| `lib/sim/lesson/lesson_material_cache.dart` | cache `audioText` | Relevante |
| `lib/sim/classroom/lesson_answer_progress_controller.dart` | cancelamento | Relevante |
| `src/media/audio-controller.js` | API propria | Relevante |
| `src/app/router.js` | rota protegida | Relevante |
| arquivos de imagem/math em `lib/sim/media/*visual*`, `math_templates/*`, `paid_image*` | 0 para audio | Descartados para audio |

## 7. Arquivos relevantes

Relevantes no Web: `audio.ts`, `audio-preference.ts`, `useLessonAudioController.ts`, `useLessonPlaybackEngine.ts`, `useLessonDoubtController.ts`, `useDoubtAudio.ts`, `LessonMainScreen.tsx`, `FixedBubble.tsx`, `lesson-pipeline-runtime.ts`, `lesson-material-cache.ts`, `studentLessonMediaService.ts`, `studentLearningState.services.ts`, `studentLearningState.types.ts`, `generate-lesson-audio.ts`.

Relevantes no Flutter/API: `audio_core.dart`, `audio_preference.dart`, `lesson_audio_controller.dart`, `student_lesson_media_service.dart`, `doubt_audio.dart`, `lesson_audio_api_contract.dart`, `platform_audio_adapter.dart`, `sim_server_ai_clients.dart`, `lab_session.dart`, `lesson_ui_state.dart`, `aula_screen.dart`, `aula_widgets.dart`, `lesson_models.dart`, `lesson_material_cache.dart`, `lesson_answer_progress_controller.dart`, `audio-controller.js`, `router.js`.

## 8. Arquivos descartados

| Arquivo | Motivo |
|---|---|
| `src/routeTree.gen.ts` | Arquivo gerado de roteamento; prova existencia da rota, mas nao define comportamento. |
| `public/avatars/sim-professor-v1.jpg` | Asset visual; nao possui controle, geracao, cache ou playback de audio. |
| `src/cyber/aula/LessonAvatar.tsx` | Componente visual de avatar com animacao por `speaking`; nao foi encontrado import no fluxo vivo da aula. Classificado como legado visual. |
| `lib/sim/media/lesson_paid_image_offer.dart` | Sistema de imagem paga; sem comportamento de audio. |
| `lib/sim/media/lesson_visual_models.dart` | Modelos de visual/imagem; `FixedBubbleModel` nao participa do audio vivo. |
| `lib/sim/media/lesson_visual_pipeline.dart` | Pipeline visual; sem audio. |
| `lib/sim/media/paid_image_service.dart` | Imagem paga; sem audio. |
| `lib/sim/media/lesson_image_api_contract.dart` | Contrato de imagem; sem audio. |
| `lib/sim/media/math_templates/*` | Templates SVG/matematica; sem audio. |
| `lib/sim/media/visual_router_n2.dart`, `visual_router_n3.dart`, `s12_visual_pipeline.dart` | Decisao visual; sem audio vivo. |
| `lib/sim/media/image_data_url_compression.dart` | Compressao de imagem; sem audio. |

## 9. Fluxo completo do audio no SimWeb

1. O texto falado nasce do material T02/cache: `lesson-pipeline-runtime.ts:733` cria `CompleteLesson` com `audioText`, e `seedCompleteLesson` monta `audioText` com explicacao + pergunta em `lesson-pipeline-runtime.ts:824`.
2. Quando material pronto ou cacheado aparece, o Web chama `audioCore.prepareText(...)` em `lesson-pipeline-runtime.ts:659`, `:713`, `:738` e `:849`.
3. Na aula viva, `useLessonPlaybackEngine.ts:39` dispara auto-audio quando `conteudo`, teoria pronta e fase `lendo` estao prontos.
4. Antes de tocar, `useLessonPlaybackEngine.ts:41` e `useLessonAudioController.ts:29` checam `getAudioEnabled()`.
5. A preferencia local fica em `src/cyber/audio-preference.ts:7`, com default ligado e storage `sim-audio-enabled-v1`.
6. `useLessonAudioController.ts:33` monta partes: explicacao, pergunta e alternativas A/B/C.
7. `studentLessonMediaService.ts:49` cria chave `lessonLocalId:itemMarker:layer` e chama `audioCore.speakSequence`.
8. `audio.ts:206` recusa audio desligado antes de chamar endpoint ou IA.
9. `audio.ts:66` busca cache em memoria por chave `lessonKey|lang|voice|hash(text)`.
10. Se autenticado, `audio.ts:76` chama `/api/generate-lesson-audio` com `text`, `lang`, `voice` e `lessonKey`.
11. A rota Web `generate-lesson-audio.ts:97` exige auth, valida `text`/`lessonKey`, escolhe voz por idioma, chama Gemini TTS e retorna `data:audio/wav;base64`.
12. Se a rota falha, `audio.ts:89` registra fallback e `audio.ts:220` cai para `speechSynthesis`.
13. O player gerado usa `HTMLAudioElement` em `audio.ts:105`; o fallback usa `SpeechSynthesisUtterance` em `audio.ts:226`.
14. `audio.ts:195` cancela audio atual e speech synthesis.
15. `LessonMainScreen.tsx:243` renderiza o toggle; `LessonMainScreen.tsx:564` renderiza `FixedBubble` quando `audioEnabled && falando`.
16. `useDoubtAudio.ts:4` reaproveita o mesmo `audioCore` para duvida com chave `:doubt`.
17. Eventos laterais sao espelhados em `StudentLearningState` por `mirrorAudioJobToStudentState` em `studentLearningState.services.ts:98`.
18. A lei de runtime em `lesson-pipeline-runtime.ts:625` declara que imagem e audio nunca bloqueiam proxima aula, curriculo ou navegacao.

## 10. Inventario de comportamentos Web

| ID | Comportamento SimWeb | Arquivo Web | Funcao Web | Linha/trecho | Categoria | Saude | Deve copiar? | Existe no Flutter? | Status Flutter | Acao futura |
|---|---|---|---|---|---|---|---|---|---|---|
| AUD-WEB-001 | Material de aula possui `audioText` derivado de explicacao/pergunta. | `lesson-pipeline-runtime.ts` | `prefetchCompleteLesson/seedCompleteLesson` | `733-738`, `824-825` | geracao do texto falado | SAUDAVEL | Sim | Sim | COMPLETO | Nenhuma |
| AUD-WEB-002 | Aula pronta/cacheada chama `audioCore.prepareText`. | `lesson-pipeline-runtime.ts` | `prefetchCompleteLesson/seedCompleteLesson` | `659`, `713`, `738`, `849` | prefetch/cache de audio | SAUDAVEL | Sim | Sim | PARCIAL | Conectar preparo no fluxo vivo/cache do Flutter |
| AUD-WEB-003 | Preferencia local de audio, default ligado, persiste por chave. | `audio-preference.ts` | `get/set/useAudioEnabled` | `7-64` | decisao audio ligado/desligado | SAUDAVEL | Sim | Sim | COMPLETO | Nenhuma |
| AUD-WEB-004 | Se audio desligado, nao chama geracao/IA. | `audio.ts`, `useLessonPlaybackEngine.ts`, `useDoubtAudio.ts` | `speak`, auto playback, doubt | `207-210`, `41-43`, `6-8` | decisao audio ligado/desligado | SAUDAVEL | Sim | Sim | COMPLETO | Nenhuma |
| AUD-WEB-005 | Controller monta narracao com explicacao, pergunta e A/B/C. | `useLessonAudioController.ts` | `playConteudo` | `33-39` | geracao do texto falado | SAUDAVEL | Sim | Sim | COMPLETO | Nenhuma |
| AUD-WEB-006 | Chave de audio por aula/item/layer. | `studentLessonMediaService.ts` | `playLessonAudioSequence` | `59-63` | cache de audio | SAUDAVEL | Sim | Sim | COMPLETO | Nenhuma |
| AUD-WEB-007 | Cache de audio gerado por `lessonKey|lang|voice|hash(text)` com limite 12. | `audio.ts` | `rememberAudio/audioCacheKey` | `27-52`, `66-70` | cache de audio | SAUDAVEL | Sim | Sim | COMPLETO | Nenhuma |
| AUD-WEB-008 | Endpoint Web de audio exige auth, valida payload e retorna data URL WAV. | `generate-lesson-audio.ts` | Route POST | `15-39`, `105-154` | endpoint/API de audio | SAUDAVEL | Sim, por equivalente proprio | Sim | COMPLETO | Nenhuma |
| AUD-WEB-009 | Idioma estavel orienta BCP-47 e voz. | `audio.ts`, `generate-lesson-audio.ts` | `stableLangToBCP47`, `VOICE_BY_LANG` | `127-160`, `84-91` | idioma/voz | SAUDAVEL | Sim | Sim | PARCIAL | Alinhar default de voz Flutter/API |
| AUD-WEB-010 | Falha da rota TTS cai para browser speech. | `audio.ts` | `fetchGeneratedAudio/speak` | `89-97`, `217-222` | erro/fallback | SAUDAVEL | Sim | Sim | PARCIAL | Capturar excecao do cliente e cair para TTS local |
| AUD-WEB-011 | Player gerado usa `Audio`, fallback usa `speechSynthesis`. | `audio.ts` | `playGeneratedAudio/speakWithBrowser` | `105-121`, `226-255` | player | SAUDAVEL | Sim | Sim | COMPLETO | Nenhuma |
| AUD-WEB-012 | Stop cancela audio gerado e speech synthesis. | `audio.ts` | `stop` | `195-203` | cancelamento/avanco | SAUDAVEL | Sim | Sim | PARCIAL | Provar stop em todos os avancos/trocas |
| AUD-WEB-013 | Audio e imagem nao bloqueiam texto, pergunta, curriculo ou navegacao. | `lesson-pipeline-runtime.ts` | `waitTextComplete` | `625-627`, `752-754` | erro/fallback | SAUDAVEL | Sim | Sim | COMPLETO | Nenhuma |
| AUD-WEB-014 | Eventos de audio sao espelhados defensivamente no estado. | `studentLearningState.services.ts` | `mirrorAudioJobToStudentState` | `86-127` | audio em aula normal | SAUDAVEL | Sim | Sim | COMPLETO | Nenhuma |
| AUD-WEB-015 | Toggle visual na aula liga/desliga audio. | `LessonMainScreen.tsx` | header button | `243-257` | componente visual/player | SAUDAVEL | Sim | Sim | COMPLETO | Nenhuma |
| AUD-WEB-016 | Bolha pulsante aparece quando audio esta ativo. | `LessonMainScreen.tsx`, `FixedBubble.tsx` | `FixedBubble` | `564`, `1-7` | bolha pulsante | SAUDAVEL | Sim | Sim | COMPLETO | Nenhuma |
| AUD-WEB-017 | Duvida pode falar resposta usando mesmo core e chave `:doubt`. | `useDoubtAudio.ts`, `useLessonDoubtController.ts` | `speakDoubt` | `4-20`, `60-81` | audio em duvida | SAUDAVEL | Sim | Sim | EXISTE MAS NAO CONECTADO | Conectar no fluxo vivo ou aprovar nao aplicavel |
| AUD-WEB-018 | Revisao/recuperacao/amparo usam o material de aula e devem herdar o caminho de audio normal quando exibem aula. | `useLessonRuntimeEngine.tsx` | aux rooms + playback engine | `20-37` | audio em revisao/recuperacao/amparo | SAUDAVEL | Sim | Parcial | AUSENTE | Provar/conectar audio nos auxiliares |
| AUD-WEB-019 | `LessonAvatar` anima com `speaking`, mas nao aparece importado no fluxo vivo. | `LessonAvatar.tsx` | `LessonAvatar` | `1-31` | legado/doenca | LEGADO | Nao | Auxiliar | NAO DEVE COPIAR | Nao copiar como requisito B2 |

## 11. Classificacao saude/doenca/legado

| Classe | Itens |
|---|---|
| SAUDAVEL | AUD-WEB-001 a AUD-WEB-018 |
| LEGADO | AUD-WEB-019 |
| DOENCA | Nenhum comportamento vivo de audio foi classificado como doenca. |

## 12. Comparacao Web x Flutter

| Comportamento saudavel Web | Status Flutter | Prova Flutter/API |
|---|---|---|
| `audioText` no material | COMPLETO | `lesson_models.dart:24`, `lesson_orchestrator.dart:160-164` |
| Preparo antecipado de audioText | PARCIAL | `student_lesson_media_service.dart:27`, mas sem chamada equivalente no cache/orchestrator vivo |
| Preferencia local persistida | COMPLETO | `audio_preference.dart:5-63` |
| Audio desligado nao chama geracao | COMPLETO | `audio_core.dart:90-94`, `lesson_audio_controller.dart:31` |
| Narracao com explicacao/pergunta/A/B/C | COMPLETO | `lesson_audio_controller.dart:32-41` |
| Chave aula/item/layer | COMPLETO | `student_lesson_media_service.dart:107-111` |
| Cache audio gerado | COMPLETO | `audio_core.dart:78`, `100-114`, `141-155` |
| Endpoint/API app equivalente | COMPLETO | `router.js:49`, `router.js:83`, `audio-controller.js:3` |
| Idioma/voz | PARCIAL | `stableLangToBCP47` completo; default de voz diverge entre Flutter/API |
| Fallback em falha de geracao | PARCIAL | fallback existe quando cliente retorna vazio; excecao HTTP vira falha no service |
| Player gerado/local | COMPLETO | `platform_audio_adapter.dart`, `audio_core.dart:30-34`, `116-126` |
| Stop/cancelamento | PARCIAL | `lesson_answer_progress_controller.dart:44`, `65`; falta prova em todos os avancos/desmontagens |
| Nao bloqueio da aula | COMPLETO | `lab_session.dart:1019-1028`, `aula_screen.dart:483-531` |
| Eventos no estado | COMPLETO | `student_lesson_media_service.dart:171-210`, `StudentAudioState` em `student_learning_state.dart:593` |
| Toggle visual | COMPLETO | `aula_widgets.dart:170-176`, `lesson_audio_controls.dart:13-20` |
| Bolha pulsante | COMPLETO | `aula_screen.dart:744-755`, `fixed_bubble.dart:45-78` |
| Duvida com audio | EXISTE MAS NAO CONECTADO | `doubt_audio.dart:4-24`, teste em `media_phase_test.dart:152-163` |
| Revisao/recuperacao/amparo com audio | AUSENTE | imports existem em `aux_room_screens.dart`, mas nao ha prova de fluxo vivo equivalente |

## 13. Lista do que ja esta completo no Flutter

1. `audioText` derivado de `LessonContent`.
2. Preferencia local persistida com default ligado.
3. Skip de geracao quando audio esta desligado.
4. Sequencia falada com explicacao, pergunta e alternativas.
5. Chave de audio por aula/item/layer.
6. Cache de audio gerado em memoria.
7. Contrato e chamada do endpoint `/api/generate-lesson-audio`.
8. Endpoint proprio protegido pela rota de auth/rate limit da API.
9. Player abstrato com suporte a data URL e TTS local.
10. Estado visual de audio loading/erro/ligado sem bloquear aula.
11. Toggle visual e bolha pulsante.

## 14. Lista do que esta parcial

1. Preparo antecipado/cache/prefetch de `audioText`.
2. Fallback de excecao HTTP/API para TTS local.
3. Alinhamento de voz default entre Flutter e API propria.
4. Cancelamento em todos os avancos/trocas/desmontagens.
5. Revisao, recuperacao e amparo herdando audio da aula.

## 15. Lista do que esta ausente

1. Prova/conexao viva de audio em revisao, recuperacao e amparo no Flutter.

## 16. Lista do que existe mas nao esta conectado

1. `DoubtAudio` existe e tem teste unitario, mas nao foi encontrado conectado ao fluxo vivo de duvida da aula Flutter.

## 17. Lista do que nao deve ser copiado

1. `LessonAvatar.tsx` como requisito de audio: componente visual legado sem uso vivo encontrado.
2. `public/avatars/sim-professor-v1.jpg`: asset visual, sem logica de audio.
3. `routeTree.gen.ts`: arquivo gerado.

## 18. Lista final para B2

| ID B2 | Acao |
|---|---|
| AUD-B2-001 | Conectar `prepareLessonAudioText`/`audioCore.prepareText` no caminho vivo de material pronto/cacheado/prefetch do Flutter. |
| AUD-B2-002 | Fazer `AudioCore.speak` tratar excecao do `GeneratedAudioClient` e tentar TTS local antes de falhar. |
| AUD-B2-003 | Alinhar `voice` enviado pelo Flutter e default da API propria com o contrato saudavel do Web, ou registrar equivalente aprovado. |
| AUD-B2-004 | Criar teste provando que selecionar, sinalizar, avancar item/layer e desmontar aula param audio. |
| AUD-B2-005 | Conectar `DoubtAudio` ao fluxo vivo de duvida ou registrar decisao de produto de nao falar duvida no app. |
| AUD-B2-006 | Conectar/provar audio em revisao, recuperacao e amparo quando exibirem aula/material. |
| AUD-B2-007 | Criar teste de erro de geracao remota com fallback local e aula nao bloqueada. |

## 19. Prova de cobertura

### Termos buscados

Todos os termos obrigatorios do enunciado foram buscados no SimWeb. Os termos com zero resultado foram: `text to speech`, `text_to_speech`, `speaker`, `unmute`, `bolha`, `pulsante`, `mouth`, `audio_text`, `narration`, `narração`, `voiceId`, `voice_id`, `elevenlabs`, `openai audio`, `gemini audio`, `generate audio`, `audio controller`, `audio service`, `audio cache`, `audio player`, `audio queue`, `audio enabled`, `audio disabled`, `disable audio`, `enable audio`.

### Contagem de resultados por termo

A tabela completa esta na secao 5.

### Arquivos analisados

SimWeb: `src/cyber/audio.ts`, `src/cyber/audio-preference.ts`, `src/cyber/aula/useLessonAudioController.ts`, `src/cyber/aula/useLessonPlaybackEngine.ts`, `src/cyber/aula/useLessonDoubtController.ts`, `src/cyber/aula/useDoubtAudio.ts`, `src/cyber/aula/LessonMainScreen.tsx`, `src/cyber/aula/FixedBubble.tsx`, `src/cyber/aula/LessonAvatar.tsx`, `src/cyber/lesson-pipeline-runtime.ts`, `src/cyber/lesson-material-cache.ts`, `src/sim/lesson/studentLessonMediaService.ts`, `src/sim/state/studentLearningState.services.ts`, `src/sim/state/studentLearningState.types.ts`, `src/routes/api/generate-lesson-audio.ts`.

Flutter/API: `lib/sim/media/audio_core.dart`, `lib/sim/media/audio_preference.dart`, `lib/sim/media/lesson_audio_controller.dart`, `lib/sim/media/student_lesson_media_service.dart`, `lib/sim/media/doubt_audio.dart`, `lib/sim/media/lesson_audio_api_contract.dart`, `lib/sim/media/platform_audio_adapter.dart`, `lib/sim/external_ai/sim_server_ai_clients.dart`, `lib/features/session/lab_session.dart`, `lib/session/lesson_ui_state.dart`, `lib/features/classroom/aula_screen.dart`, `lib/features/classroom/aula_widgets.dart`, `lib/sim/ui/widgets/lesson_audio_controls.dart`, `lib/sim/ui/widgets/fixed_bubble.dart`, `lib/sim/lesson/lesson_models.dart`, `lib/sim/lesson/lesson_material_cache.dart`, `lib/sim/classroom/lesson_answer_progress_controller.dart`, `/root/sim-work/sim-api/src/media/audio-controller.js`, `/root/sim-work/sim-api/src/app/router.js`, `test/media_phase_test.dart`, `test/external_ai_clients_test.dart`, `test/internal_organs_governor_test.dart`.

### Arquivos descartados e motivos

A tabela completa esta na secao 8.

### Fluxos rastreados

1. T02/cache/seed -> `audioText` -> `audioCore.prepareText`.
2. Aula lendo -> auto playback -> preferencia -> controller -> service -> core.
3. Botao manual -> controller -> play/stop.
4. Core -> cache -> endpoint TTS autenticado -> data URL -> player.
5. Core -> falha/sem auth -> fallback Web Speech/TTS local.
6. Toggle off -> stop/cancelamento.
7. Duvida -> `useDoubtAudio` -> core com chave `:doubt`.
8. Estado -> `AUDIO_JOB_STARTED/READY/FAILED`.
9. UI -> toggle/status/bolha.

### Imports/chamadas rastreadas

`audioCore`, `getAudioEnabled`, `subscribeAudioEnabled`, `useAudioEnabled`, `useLessonAudioController`, `playLessonAudioSequence`, `stopLessonAudio`, `useDoubtAudio`, `FixedBubble`, `generate-lesson-audio`, `StudentLessonMediaService`, `SimServerGeneratedAudioClient`, `AudioPreference`, `LessonAudioController`.

### Comportamentos encontrados

AUD-WEB-001 a AUD-WEB-019.

### Comportamentos saudaveis

AUD-WEB-001 a AUD-WEB-018.

### Comportamentos doenca/legado

AUD-WEB-019 e arquivos descartados da secao 8.

### Itens comparados com Flutter

Todos os comportamentos saudaveis AUD-WEB-001 a AUD-WEB-018 foram comparados item por item na secao 12.

### Itens sem pendencia de classificacao

Todos os arquivos candidatos e comportamentos receberam etiqueta: `COMPLETO`, `PARCIAL`, `AUSENTE`, `EXISTE MAS NAO CONECTADO`, `LEGADO`, `NAO DEVE COPIAR` ou `DESCARTADO`.

## 20. Veredito final: Estamos em B1?

**SIM.**

Todos os termos obrigatorios foram buscados, todos os arquivos candidatos foram classificados, os fluxos vivos foram rastreados, os comportamentos foram convertidos em IDs, cada comportamento saudavel foi comparado com Flutter/API, e as diferencas saudaveis foram colocadas na lista final para B2.
