# B Image Funnel Final Report

## 1. Estamos em B?

NAO.

Motivo: o funil visual foi centralizado no codigo, testes automatizados passaram e o APK release foi gerado, mas ainda falta prova manual no APK real/celular mostrando imagem real em aula. Pelo criterio da missao, sem essa prova B final continua NAO.

## 2. Portoes

| Portao | Status | Prova |
|---:|---|---|
| 1. Funil real mapeado | PASSOU | `docs/B-image-funnel-current-map.md` |
| 2. Remover duplicacao visual | PASSOU | `LessonOrchestrator._fetchImage` agora usa `LessonVisualPipeline.resolveVisual`. |
| 3. Software antes de IA | PASSOU | Pipeline central tenta SVG inline, math template, N2/N3 antes de oferta paga. |
| 4. N3 local melhorado | PASSOU | `visual_router_n3.dart` gera SVG especifico para fisica, graficos, gramatica e comparacao. |
| 5. Normalizar visual_trigger | PARCIAL | `LessonVisualTrigger.fromJson` preserva campos; API ainda faz validacao basica. |
| 6. PaidImageService/orgao de oferta | PARCIAL | Oferta agora nasce por funil/key no `LessonEventBus`; `PaidImageService` ainda permanece principalmente coberto por testes. |
| 7. Push/notificacao por key | PASSOU | `LessonEventBus.subscribePaidImageOffer`; `LabSession` assina key ativa. |
| 8. allowPaidImages sem cobrar background | PASSOU | Orquestrador publica oferta, nao chama IA paga nem cobra em background. |
| 9. Cache deterministico | PASSOU | Usa `lessonKeyFor(params)` e cache/bus por key. |
| 10. Credito/aceite/idempotencia | PASSOU AUTOMATIZADO | Aceite usa `acceptedOfferId`/`idempotencyKey`; servidor ja tem testes de contrato. |
| 11. Renderizacao UI | PASSOU AUTOMATIZADO | Testes existentes de SVG/dataUrl/renderizador continuam passando. |
| 12. Scroll/feedback/avancar | PASSOU REGRESSAO | Testes de aula/zoom/feedback existentes continuam passando. |
| 13. Prefetch e slots A/B/C | PASSOU REGRESSAO | Testes de ready window/vital flow continuam passando. |
| 14. Observabilidade | PARCIAL | Metadados `requestId/cacheKey/charged/cacheHit/retryable` preservados; logs S12/N2/N3 ainda podem melhorar. |
| 15. Prova APK real | NAO PASSOU | APK buildado, mas imagem real ainda nao foi testada no celular. |

## 3. Respostas Obrigatorias

| Pergunta | Resposta |
|---|---|
| O funil real foi mapeado? | SIM |
| LessonOrchestrator usa o funil completo? | SIM |
| LessonVisualPipeline esta no caminho real? | SIM |
| Software/template desenha antes de IA? | SIM |
| N3 local foi melhorado ou documentado? | SIM |
| PaidImageService virou orgao real? | PARCIAL; oferta por key virou real via `LessonEventBus`, mas `PaidImageService.consume` ainda nao governa o aceite do `LabSession`. |
| Oferta e push/evento por key? | SIM |
| Imagem pronta notifica UI por key? | SIM |
| visual_trigger e normalizado? | PARCIAL |
| SVG aparece no APK? | NAO PROVADO EM CELULAR |
| imagem paga aparece no APK? | NAO PROVADO EM CELULAR |
| aceite cobra uma vez? | SIM EM TESTE/CONTRATO; APK real nao provado |
| recusa nao cobra? | SIM EM TESTE/CONTRATO |
| duplo toque nao duplica? | SIM EM TESTE/CONTRATO |
| retry nao duplica? | SIM EM TESTE/CONTRATO |
| cache funciona? | SIM EM TESTE |
| prefetch nao cobra? | SIM |
| First Item Fast Path foi preservado? | SIM |
| imagem atrasada entra no item certo? | SIM POR KEY NO CODIGO; falta prova APK |
| pergunta/sinais/feedback/botao avancar continuam visiveis? | SIM EM REGRESSAO AUTOMATIZADA |
| testes passaram? | SIM |
| build passou? | SIM |
| APK real mostrou imagem? | NAO PROVADO |

## 4. Arquivos Alterados

- `docs/B-image-funnel-current-map.md`
- `docs/B-image-funnel-final-report.md`
- `lib/features/session/lab_session.dart`
- `lib/session/lesson_ui_state.dart`
- `lib/sim/classroom/lesson_runtime_engine.dart`
- `lib/sim/external_ai/sim_server_ai_clients.dart`
- `lib/sim/lesson/lesson_event_bus.dart`
- `lib/sim/lesson/lesson_orchestrator.dart`
- `lib/sim/media/lesson_image_api_contract.dart`
- `lib/sim/media/visual_router_n3.dart`
- `lib/sim/organism/sim_organism.dart`
- `test/external_ai_clients_test.dart`
- `test/first_lesson_ready_window_test.dart`
- `test/media_phase_test.dart`

## 5. Testes Criados/Atualizados

- `LessonOrchestrator publishes paid image offer by key after software funnel`
- `LessonEventBus replays pending paid image offer to late subscriber`
- `N3 local generates domain-specific SVG instead of generic sequence`
- Testes anteriores de metadados de imagem preservados continuam passando.

## 6. Comandos Rodados

| Comando | Resultado |
|---|---|
| `flutter analyze` | PASSOU |
| `flutter test` | PASSOU, 219 testes |
| `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production` | PASSOU |

## 7. APK

- Caminho: `build/app/outputs/flutter-apk/app-release.apk`
- Tamanho: `60602516 bytes`
- SHA256: `e2fe57cfb031dc2b9896cf9e608e5b3ada4aec6e83e77d998ab40adeadab0520`

## 8. Status Final

NAO ATINGIDO.

O codigo agora tem funil visual vivo por key em vez de depender apenas de snapshot ativo, mas a missao exige prova no APK real mostrando imagem. Essa prova ainda nao foi executada nesta etapa.
