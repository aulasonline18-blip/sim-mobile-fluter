# B Image Funnel Current Map

## Estado Atual Encontrado

| Etapa | Arquivo/função | Estado atual |
|---|---|---|
| T02 cria `visual_trigger` | `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js` `normalizeLessonJson` | Preserva `visual_trigger` vindo do T02 dentro de `conteudo.visual_trigger`. |
| API valida `visual_trigger` | `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js` `assertVisualTrigger` | Valida campos básicos, mas não normaliza profundamente `math_template`, `aspect_ratio`, `color_legend` ou aliases. |
| Flutter recebe `visual_trigger` | `lib/sim/external_ai/sim_server_ai_clients.dart` e `lib/sim/lesson/lesson_orchestrator.dart` `_fetchText` | O material T02 vira `LessonContent.visualTrigger`. |
| `LessonVisualPipeline.resolveVisual` existe | `lib/sim/media/lesson_visual_pipeline.dart` `resolveVisual` | Implementa funil central: SVG inline, math template, N2/N3 e IA paga com aceite. |
| Caminho real usa pipeline completo? | `lib/sim/lesson/lesson_orchestrator.dart` `_fetchImage` | Antes desta missão, não. `_fetchImage` reimplementava math/S12/N2/N3 manualmente. |
| S12 roda | `lib/sim/media/s12_visual_pipeline.dart` `decideVisualGeneration` | Roda no orquestrador e no getter de oferta do `LabSession`, com decisões duplicadas. |
| N2 roda | `lib/sim/media/visual_router_n2.dart` `classifyVisualByKeywords` | Roda no orquestrador e no pipeline. |
| N3 roda | `lib/sim/media/visual_router_n3.dart` `routeVisualCheapN3` | Roda localmente; é mais simples que o N3 remoto do SimWeb. |
| Template local roda | `lib/sim/media/math_templates/math_templates.dart` `tryRenderMathTemplate` | Roda se `math_template.name` e `params` estiverem perfeitos. |
| `PaidImageService.offer` é chamado? | `lib/sim/media/paid_image_service.dart` | Antes desta missão, aparece principalmente em testes; o fluxo visível usa `LabSession.lessonPaidImagePrompt`. |
| `LabSession` calcula oferta | `lib/features/session/lab_session.dart` `lessonPaidImagePrompt` | Calcula por snapshot ativo, não por evento de funil por chave. |
| UI mostra oferta | `lib/features/classroom/aula_widgets.dart` `LessonImagePanel` | Mostra oferta quando `session.hasLessonPaidImageOffer` é verdadeiro. |
| Aceite | `lib/features/session/lab_session.dart` `acceptLessonPaidImage` | Chama API de imagem com `acceptedOfferId` e `idempotencyKey`. |
| Recusa | `lib/features/session/lab_session.dart` `declineLessonPaidImage` | Marca `imageStatus = declined`; antes desta missão, não era oferta viva por key. |
| API paga | `/root/sim-work/sim-api/src/media/image-controller.js` | Exige auth, `acceptedOfferId`, idempotência, crédito, cache e resource owner. |
| Cache local | `lib/sim/lesson/lesson_material_cache.dart` | Guarda `CompleteLesson` por `lessonKeyFor(params)`. |
| Notificação de imagem | `lib/sim/lesson/lesson_event_bus.dart` | Antes desta missão, só tinha evento de `CompleteLesson`; a tela não assinava diretamente no `LabSession`. |
| Imagem aparece | `lib/features/classroom/aula_widgets.dart` `LessonImagePanel` | Renderiza se `aulaSnapshot.imagem` estiver preenchido. |
| Falha | `lib/features/session/lab_session.dart` e `LessonImageErrorView` | Falha paga vira erro pequeno; falha software podia sumir sem oferta/evento claro. |

## Diagnóstico

O organismo de imagem estava fragmentado:

- `LessonVisualPipeline` existia, mas o caminho real usava lógica duplicada.
- `PaidImageService` existia, mas não governava a oferta visível da aula.
- `LessonEventBus` publicava imagem por chave, mas o `LabSession` não assinava a chave ativa.
- A oferta paga dependia demais do snapshot ativo.
- O Web tem `scheduleImage(key)` como funil vivo; o Flutter precisava de equivalente por chave.
