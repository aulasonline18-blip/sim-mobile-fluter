# B2 Image System Parity

## 1. Lista dos 14 itens da cidade C

| # | Item | Status |
|---|---|---|
| 1 | Conectar retorno T02 `visual_trigger` em `LessonOrchestrator._fetchText` | COMPLETO COM TESTE |
| 2 | Substituir `LessonImagePanel` / `requestLessonImage` mock por `CompleteLesson.imagem` e pipeline real | COMPLETO COM TESTE |
| 3 | Implementar/adaptar N3 no app/API para cobrir `routeVisualServerFn` | COMPLETO COM TESTE |
| 4 | Alinhar `/root/sim-work/sim-api/src/media/image-controller.js` ao endpoint saudável do SimWeb ou decisão equivalente aprovada | EQUIVALENTE APROVADO PELO USUÁRIO, COMPLETO COM TESTE |
| 5 | Garantir oferta paga visual antes de qualquer chamada cara | COMPLETO COM TESTE |
| 6 | Conectar aceitar/recusar/comprar créditos da oferta paga na tela da aula | COMPLETO COM TESTE |
| 7 | Implementar compressão de imagem se data URL/base64 continuar sendo usado | COMPLETO COM TESTE |
| 8 | Adicionar estado de erro visual não bloqueante na UI Flutter | COMPLETO COM TESTE |
| 9 | Provar math templates no fluxo vivo Flutter com testes | COMPLETO COM TESTE |
| 10 | Provar N2/N3 e fallback para IA paga com testes | COMPLETO COM TESTE DE PIPELINE |
| 11 | Provar que background/prefetch não cobra imagem paga sem ação do aluno | COMPLETO COM TESTE |
| 12 | Provar dúvida com foto + visual gratuito opcional no Flutter | COMPLETO COM TESTE |
| 13 | Provar revisão/recuperação herdando `visual_trigger` | COMPLETO COM TESTE |
| 14 | Revisar prompt oficial do app API para contrato visual T02 idêntico ao Web | COMPLETO COM PROVA MANUAL |

## 2. Arquivos alterados

- `lib/sim/modules/pedagogical_module_contracts.dart`
- `lib/sim/external_ai/sim_server_ai_clients.dart`
- `lib/sim/lesson/lesson_models.dart`
- `lib/sim/lesson/lesson_orchestrator.dart`
- `lib/sim/lesson/lesson_material_cache.dart` não alterado, mas validado pelo teste existente de persistência sem imagem.
- `lib/sim/media/lesson_visual_pipeline.dart`
- `lib/sim/media/image_data_url_compression.dart`
- `lib/sim/media/visual_router_n3.dart`
- `lib/sim/media/paid_image_service.dart`
- `lib/sim/auxiliary/doubt_t02_caller.dart`
- `lib/sim/classroom/lesson_runtime_engine.dart`
- `lib/features/classroom/aula_widgets.dart`
- `lib/features/session/lab_session.dart`
- `pubspec.yaml`
- `pubspec.lock`
- `test/first_lesson_ready_window_test.dart`
- `test/media_phase_test.dart`
- `test/auxiliary_phase_test.dart`
- `test/external_ai_clients_test.dart`
- `test/finish_phase_test.dart`
- `/root/sim-work/sim-api/src/media/image-controller.js`
- `/root/sim-work/sim-api/test/server-contract.test.js`

## 3. Testes criados/atualizados

- `LessonOrchestrator carries T02 visual_trigger into free SVG image`
- `LessonOrchestrator renders math_template from visual_trigger`
- `review and recovery requests preserve visual_trigger`
- `background prefetch does not create paid image without student action`
- `N2/N3 resolves schematic visual as free SVG without paid image`
- `N3 sends realistic ambiguous visual to paid path only when allowed`
- `PaidImageService offers before paid fetch and consumes only after accept`
- `doubt with photo preserves optional free visual trigger`
- `image data URL compression rewrites raster image to jpeg data URL`
- `painel mostra oferta paga antes de gerar imagem`
- `server-contract.test.js` prova aceite obrigatório, idempotência/cache sem cobrança duplicada e refund em falha.

## 4. Testes rodados

- `/opt/flutter/bin/flutter analyze` passou.
- `/opt/flutter/bin/flutter test` passou: 168 testes.
- `/opt/flutter/bin/flutter build apk --release --dart-define=FLUTTER_APP_MODE=production` passou.
- `npm test` em `/root/sim-work/sim-api` passou.
- `npm run prompt-parity` em `/root/sim-work/sim-api` passou em presença/hash.
- Comparação manual de `prompts/t02.txt` com `/root/sim-work/sim-web/modules/tutor/T02_content.v3.txt` mostrou apenas diferença cosmética no título; contrato `visual_trigger` está equivalente.

APK gerado:

- `build/app/outputs/flutter-apk/app-release.apk`
- tamanho: `60057292` bytes
- SHA256: `b7da522b0029520ea2c812d173205a1558d0a8ce88210df924b512f6151c08f5`

## 5. Provas de imagem gratuita/software

- T02 agora pode retornar `visual_trigger` no `T02LessonMaterial`.
- `SimServerT02Client` preserva `visual_trigger` e `visualTrigger`.
- `LessonOrchestrator._fetchText` copia `material.visualTrigger` para `LessonContent`.
- S12 recebe o envelope correto `{ visual_trigger: ... }`.
- SVG inline gratuito é sanitizado e publicado em `CompleteLesson.imagem`.
- Math template `linear_function` é renderizado no fluxo do orquestrador.
- N2/N3 local gera SVG gratuito para visual esquemático sem chamar cliente pago.
- `LessonImagePanel` renderiza `CompleteLesson.imagem` via `flutter_svg`, data URL base64 ou URL remota.
- Data URL raster é comprimida para JPEG antes de exibição/cache do caminho pago.

## 6. Provas de imagem paga exige aceite

- `PaidImageService.offer()` não chama fetch caro.
- `PaidImageService.consume()` chama fetch apenas depois do aceite.
- `LessonOrchestrator` não chama endpoint pago em background/prefetch.
- N3 manda ambíguo realista para caminho pago somente quando `allowPaidImages=true`.
- `LessonImagePanel` mostra oferta com `Sem imagem`, comprar créditos e `Gerar`.
- `SimServerLessonImageClient` envia `acceptedOfferId` e `idempotencyKey`.
- Endpoint próprio do app exige autenticação, valida payload, exige `acceptedOfferId`, usa idempotência/cache, evita segredo em log, estorna reserva em falha e devolve erro claro.

## 7. Provas de erro não bloqueia aula

- A imagem roda depois do texto pelo `ImageSequentialQueue`.
- Background/prefetch com visual pago não bloqueia a aula nem cria imagem falsa.
- `LessonImagePanel` tem estado visual para imagem ausente/erro.
- Falha real em `acceptLessonPaidImage()` define `imageError = 'Imagem indisponível. A aula continua sem imagem.'`.

## 8. Provas de dúvida/revisão/recuperação

- Dúvida com foto preserva metadados da imagem no request T02.
- `DoubtT02Caller` preserva `material.visualTrigger` na resposta.
- Revisão (`LessonMode.reforco`) e recuperação (`LessonMode.amparo`) preservam `visual_trigger`.

## 9. Diferenças restantes

- O endpoint do app é equivalente próprio aprovado pelo usuário, não uma cópia bruta do SimWeb.
- `npm run prompt-parity` ainda usa mapa antigo de nomes de prompts; a comparação manual contra `T02_content.v3.txt` foi usada como prova do contrato visual.

## 10. Veredito

Estamos em B2? SIM.

Motivo: os 14 itens da cidade C foram concluídos com teste, prova manual ou equivalência aprovada pelo usuário. Não há item final em `PARCIAL`, `AUSENTE`, `MOCK`, `NÃO CONECTADO` ou `DECISÃO PENDENTE`.
