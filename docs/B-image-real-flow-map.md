# B Image Real Flow Map

Data: 2026-07-01

## Escopo

Mapa do fluxo real de imagem do SimApp Flutter/API, usando o SimWeb apenas como referencia funcional.

## Cadeia real

| Etapa | Arquivo | Funcao/classe | Responsabilidade | Quem chama | Quem e chamado | Prova por trecho | Conectado? | Risco |
|---:|---|---|---|---|---|---|---|---|
| 1 | `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js` | `normalizeLessonJson` | Extrai `visual_trigger` de `conteudo` e valida contrato basico | rota `/api/complete-lesson` | `assertVisualTrigger` | linhas 3-4: aceita `visual_trigger`/`visualTrigger` e devolve em `conteudo.visual_trigger` | SIM | Validacao nao cobre todos os campos ricos como `math_template`, `aspect_ratio`, `color_legend`. |
| 2 | `lib/sim/lesson/lesson_content_validator.dart` | `validateLessonContentFromJson` | Parseia material T02 e preserva `visualTrigger` no Flutter | `SimServerT02Client` | `validateVisualTrigger` | linhas 115-133 no `rg`: pega `visual_trigger`/`visualTrigger` e guarda `JsonMap` | SIM | Se servidor aceitar campos extras, Flutter preserva como Map, mas validacao ainda e parcial. |
| 3 | `lib/sim/external_ai/sim_server_ai_clients.dart` | `SimServerT02Client` | Chama `/api/complete-lesson` e monta `T02LessonMaterial` | orquestrador/servicos T02 | validador de conteudo | `rg` mostrou `visualTrigger: content.visualTrigger` | SIM | Precisa prova por teste vivo/APK para payload real do Gemini. |
| 4 | `lib/sim/lesson/lesson_orchestrator.dart` | `_fetchText` | Converte retorno T02 em `CompleteLesson` com `visualTrigger` e `imagem:null` | `prefetchCompleteLesson` | `t02Client.completeLesson` | linhas 146-175: material.visualTrigger vira `LessonContent.visualTrigger` e texto retorna sem imagem | SIM | Correto para texto primeiro; imagem vem depois. |
| 5 | `lib/sim/lesson/lesson_orchestrator.dart` | `prefetchCompleteLesson` | Cacheia texto, notifica UI, dispara imagem em background | ReadyWindow/lesson services | `_imageQueue.run(() => _fetchImage(...))` | linhas 58-66: `cache.put`, `bus.notify`, `onAudioTextReady`, depois `_fetchImage` | SIM | Nao registra evento IMAGE_STARTED/READY aqui. |
| 6 | `lib/sim/lesson/lesson_orchestrator.dart` | `_fetchImage` | Decide caminho gratuito local: math template, S12, N2/N3 | fila de imagem | `tryRenderMathTemplate`, `decideVisualGeneration`, `classifyVisualByKeywords`, `routeVisualCheapN3` | linhas 78-144 | PARCIAL | Nao emite oferta paga; apenas comenta que PaidImageService faz separado. |
| 7 | `lib/sim/media/math_templates/math_templates.dart` | `tryRenderMathTemplate` | Renderiza SVG local por `visual_trigger.math_template` | `_fetchImage` / `LessonVisualPipeline` | templates locais | linhas 39-43 no `rg`: le `visual_trigger.math_template` | SIM | Precisa ampliar testes se algum template obrigatorio nao coberto. |
| 8 | `lib/sim/media/s12_visual_pipeline.dart` | `decideVisualGeneration` | Decide skip/SVG/software/pago conforme `visual_trigger` e contexto | orquestrador, UI, PaidImageService | `sanitizeAndEncodeSvg` | linhas 77-183 | SIM | Em `render_strategy=software` sem SVG mas com prompt, retorna `generate:true`; no orquestrador com `allowPaidImages:false` isso nao vira oferta automaticamente. |
| 9 | `lib/sim/media/visual_router_n2.dart` | `classifyVisualByKeywords` | Classifica visual por palavras-chave | `_fetchImage` / pipeline | N3 barato | `rg` mostrou uso em `lesson_orchestrator.dart:119-123` | SIM | N3 e local/generic, nao juiz remoto Web. |
| 10 | `lib/sim/media/visual_router_n3.dart` | `routeVisualCheapN3` | Tenta transformar ambiguidade em SVG gratuito | `_fetchImage` | S12/SVG helpers | `lesson_orchestrator.dart:126-140` | SIM | Qualidade pode ser inferior ao juiz remoto do Web; precisa prova visual. |
| 11 | `lib/sim/lesson/lesson_material_cache.dart` | `put/peek/persist` | Guarda material, mas stripa imagem em persistencia leve | orquestrador/session | SharedPreferences | `rg` mostrou comentario: persiste `_memory`, strip de imagem | SIM | Reabrir app pode perder imagem pesada; pode ser saudavel, mas precisa politica/teste. |
| 12 | `lib/sim/lesson/lesson_event_bus.dart` | `notify/subscribe` | Notifica UI quando imagem gratuita chega ao cache | orquestrador | UI/servicos inscritos | `lesson_orchestrator.dart:93-110,138-140` | SIM | Oferta paga direta no LabSession pode nao passar pelo bus. |
| 13 | `lib/features/session/lab_session.dart` | `lessonPaidImagePrompt` | Calcula se ha prompt pago para oferta na aula ativa | UI `LessonImagePanel` | `decideVisualGeneration(...allowPaidImages:true)` | linhas 978-990 | SIM | Duplicado em relacao ao `PaidImageService`; nao registra eventos de offer central. |
| 14 | `lib/features/session/lab_session.dart` | `acceptLessonPaidImage` | Gera imagem paga apos clique, com offerId/idempotencyKey estaveis | UI botao `Ver imagem` | `SimServerLessonImageClient.generateLessonImage` | linhas 1023-1055 | SIM | Atualiza `aulaSnapshot`, mas nao atualiza cache/event bus/StudentLearningState com cacheKey/requestId. |
| 15 | `lib/features/session/lab_session.dart` | `declineLessonPaidImage` | Recusa oferta localmente | UI botao recusar | `notifyListeners` | linhas 1011-1016 | SIM | Recusa parece estado local, pode reaparecer apos reabrir se nao persistir por lessonKey. |
| 16 | `lib/features/classroom/aula_widgets.dart` | `LessonImagePanel` | Renderiza loading, oferta, erro ou imagem | `AulaLabScreen` | `LessonMediaImageView` | linhas 348-519 | SIM | Loading usa `aulaRuntimeLoading`; pode confundir loading de aula com imagem se nao controlado por imageStatus. |
| 17 | `lib/features/classroom/aula_widgets.dart` | `LessonMediaImageView` | Renderiza SVG data URL, bitmap data URL e URL remota | `LessonImagePanel` / historico | `SvgPicture.string`, `Image.memory`, `Image.network` | linhas 522-608 | SIM | Nao expoe requestId/diagnostico; erro e compacto. |
| 18 | `lib/features/classroom/aula_screen.dart` | `_onSessionChange/_scrollForSnapshot` | Recalcula scroll em mudancas de fase/historico/conteudo | `LabSession.notifyListeners` | `_scrollToTarget` | linhas 114-143, 242-259 | SIM | Scroll signature nao inclui `imagem`; depende de `onImageSettled` para ajuste visual. |
| 19 | `lib/features/classroom/aula_widgets.dart` | `LessonMediaImageView.onImageSettled` | Notifica apos imagem/SVG assentar para scroll reajustar | imagem renderizada | callback da tela | linhas 549-554, 560-604 | SIM | Para SVG chama antes de layout final, embora em post-frame; precisa teste visual. |
| 20 | `lib/sim/external_ai/sim_server_ai_clients.dart` | `SimServerLessonImageClient.generateLessonImage` | Chama `/api/generate-lesson-image` com auth headers e `x-request-id` | LabSession/Pipeline | API servidor | linhas 61-112 | SIM | Retorna apenas `dataUrl`; descarta `cacheKey`, `charged`, `cache_hit`, `requestId`. |
| 21 | `/root/sim-work/sim-api/src/app/router.js` | `protectedRoutes` | Protege `/api/generate-lesson-image` como rota `media` | HTTP server | `requireAuth`/image controller | linhas 49,82 no `rg` | SIM | Depende de auth corrigido e token real do APK. |
| 22 | `/root/sim-work/sim-api/src/media/image-controller.js` | `validatePayload` | Exige prompt, lessonKey, aspectRatio, `acceptedOfferId`, `idempotencyKey` | rota protegida | controlador de imagem | linhas 25-67 | SIM | Garante que endpoint nao gera sem aceite. |
| 23 | `/root/sim-work/sim-api/src/media/image-controller.js` | `handle` | Auth, cache, idempotencia, reserva/captura/reembolso, Gemini e resposta | router | credits, cache, gemini | linhas 85-204 | SIM | Cache em memoria; sem persistencia apos restart. |
| 24 | `/root/sim-work/sim-api/src/app/media-cache.js` | `createMediaCache` | Cache LRU em memoria | image/audio controller | Map local | linha 1 | SIM | Nao sobrevive restart; limite 12 global. |
| 25 | `/root/sim-work/sim-web/src/cyber/lesson-pipeline-runtime.ts` | `scheduleImage`/`acceptPaidImageOffer` | Referencia Web: texto nao espera imagem, oferta paga por aula, imageInflight/dedupe | Web aula | route visual + paid endpoint | `rg`: linhas 126,139,203,384-576 | Referencia | Web tem pub/sub/offers por key; Flutter tem parte disso, mas oferta paga esta acoplada no LabSession. |

## Conclusao do Portao 1

Portao 1: PASSOU PARCIALMENTE.

O fluxo real esta mapeado por arquivo e funcao. A cadeia basica existe e esta conectada:

T02 -> `visual_trigger` -> Flutter `LessonContent` -> `LessonOrchestrator` -> imagem gratuita em background -> cache/bus -> UI.

Imagem paga tambem existe:

UI `LessonImagePanel` -> `LabSession.acceptLessonPaidImage` -> `SimServerLessonImageClient` -> `/api/generate-lesson-image` -> Gemini -> `dataUrl` -> `aulaSnapshot.imagem`.

Riscos que precisam entrar nos proximos portoes:

1. Oferta paga esta duplicada no `LabSession`, nao no `PaidImageService` central.
2. Cliente Flutter descarta metadados do servidor (`cacheKey`, `charged`, `cache_hit`, `requestId`).
3. Recusa de oferta parece local e pode nao persistir por `lessonKey`.
4. Imagem paga pronta atualiza `aulaSnapshot`, mas nao prova atualizacao de cache/event bus/StudentLearningState.
5. Cache servidor e em memoria.
6. B final ainda depende de prova no APK real.
