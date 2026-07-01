# B Image System Loop Final Report

Data: 2026-07-01

## 1. Objetivo

Sistema de imagem do Flutter igual ou melhor que o SimWeb saudavel:

- `visual_trigger` preservado;
- SVG/template local gratuito;
- imagem paga somente com aceite;
- cache/idempotencia/diagnostico preservados;
- imagem renderizada sem bloquear aula;
- APK release buildado para prova real.

## 2. Status Final

Status final: NAO ATINGIDO.

Motivo: os portoes automatizados possiveis passaram e o APK release foi gerado/publicado, mas a missao exige prova no APK real/celular de que SVG/template e imagem paga aceita aparecem visualmente. Essa prova manual ainda nao foi feita nesta sessao. Pelo criterio absoluto, sem imagem aparecendo no APK real, B = NAO.

## 3. Portoes

| Portao | Status | Prova | Observacao |
|---:|---|---|---|
| 1. Mapa do fluxo real | PASSOU | `docs/B-image-real-flow-map.md` | Fluxo T02/API/Flutter/UI mapeado por arquivo/funcao. |
| 2. visual_trigger chega ao app | PASSOU | `test/first_lesson_ready_window_test.dart`, `test/media_phase_test.dart`, `flutter test` | Valido, ausente, invalido e math/conceitual cobertos por testes existentes. |
| 3. Decisao software vs IA | PASSOU | `test/media_phase_test.dart` | N2/N3/S12 separam SVG gratuito de IA paga. |
| 4. SVG/template local funciona | NAO PASSOU FINAL | `test/first_lesson_ready_window_test.dart`, `test/media_phase_test.dart` | Passou automatizado; falta ver SVG aparecendo no APK real. |
| 5. Imagem dataUrl/URL renderiza | NAO PASSOU FINAL | `test/finish_phase_test.dart` | Widget renderiza dataUrl/SVG/erro; falta prova visual real no APK. |
| 6. UI da imagem nao bloqueia aula | PASSOU AUTOMATIZADO | `test/finish_phase_test.dart`, `flutter test` | Testes cobrem imagem pronta/erro sem quebrar aula. |
| 7. Scroll e imagem atrasada | PASSOU AUTOMATIZADO | `LessonMediaImageView.onImageSettled`, `test/finish_phase_test.dart` | Falta prova visual manual de atraso 2-5s no APK. |
| 8. Layout mobile da imagem | NAO PASSOU FINAL | build release + testes widget | Falta validacao manual em celular pequeno/zoom alto. |
| 9. Oferta de imagem paga existe | PASSOU AUTOMATIZADO | `test/finish_phase_test.dart` | Oferta/custo/botoes aparecem no widget. |
| 10. Aceite explicito | PASSOU AUTOMATIZADO | `src/media/image-controller.js`, `test/media_phase_test.dart` | Servidor exige `acceptedOfferId`; Flutter so chama no aceite. |
| 11. Credito e cobranca | NAO PASSOU FINAL | `test/internal_organs_governor_test.dart`, servidor lido | Passou em testes internos; falta prova real com conta normal e conta infinita no APK. |
| 12. Idempotencia/duplo toque/retry | PASSOU AUTOMATIZADO | `test/media_phase_test.dart`, `image-controller.js` | Chave estavel por offerId; servidor bloqueia running/replay. |
| 13. Cache local | PASSOU AUTOMATIZADO | `test/first_lesson_ready_window_test.dart`, `lesson_material_cache.dart` | Cache local preserva leveza e LRU; imagem pesada nao persistida por saude mobile. |
| 14. Cache servidor | PASSOU PARCIAL | `image-controller.js`, `media-cache.js` | Cache inclui userId/hash e retorna `cache_hit`; e memoria apenas, nao prova persistencia pos-restart. |
| 15. Auth/resource owner | NAO PASSOU FINAL | router + image-controller lidos | Codigo exige auth/resource owner; falta teste real APK user A/B. |
| 16. HTTP/requestId/erro util | PASSOU AUTOMATIZADO | `test/external_ai_clients_test.dart` | Erro preserva status/requestId/retryable; sucesso agora preserva metadados. |
| 17. Timeout | PASSOU PARCIAL | cliente tem timeout 125s; servidor 120s | Teste explicito de timeout de imagem real ainda nao foi executado. |
| 18. StudentLearningState | PASSOU AUTOMATIZADO | novo teste em `test/media_phase_test.dart` | IMAGE_STARTED/READY/FAILED preservam cacheKey/item/layer. |
| 19. LessonOrchestrator/background | PASSOU AUTOMATIZADO | `test/first_lesson_ready_window_test.dart` | Texto libera antes; imagem background; paid image nao prefetch. |
| 20. ReadyWindow/First Item Fast Path | PASSOU AUTOMATIZADO | `test/first_lesson_ready_window_test.dart` | Primeiro item nao espera imagem; B/C background nao gera paga. |
| 21. Historico e reabertura | PASSOU PARCIAL | `test/classroom_parity_t01_t28_test.dart`, `test/finish_phase_test.dart` | Historico limita imagens; falta prova drawer/cloud com imagem paga real. |
| 22. Foto da duvida/anexos separados | PASSOU AUTOMATIZADO | `test/auxiliary_phase_test.dart`, `test/electrical_hydraulic_connections_test.dart` | Duvida/anexo separados de imagem da aula. |
| 23. Prova automatizada | PASSOU | `flutter test`: 216 testes | Inclui novos testes de metadados e eventos de imagem. |
| 24. Build APK | PASSOU | `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production` | Gerou `build/app/outputs/flutter-apk/app-release.apk`. |
| 25. Prova APK real | NAO PASSOU | Nao houve teste manual/celular nesta sessao | Bloqueio final de B. |

## 4. Correcoes Feitas

1. O cliente Flutter de imagem agora preserva metadados tecnicos em sucesso:
   - `cacheKey`;
   - `requestId`;
   - `mime_type`;
   - `provider`;
   - `model`;
   - `charged`;
   - `cache_hit`;
   - `retryable`.

2. `generateLessonImage()` continua compativel, retornando `String?`, mas agora existe `generateLessonImageResponse()` para o fluxo que precisa diagnostico rico.

3. `LabSession.acceptLessonPaidImage()` usa resposta rica e grava metadados tecnicos no `LessonUiState`.

4. O fluxo pago registra eventos de midia:
   - `IMAGE_STARTED`;
   - `IMAGE_READY`;
   - `IMAGE_FAILED`.

5. Falha HTTP estruturada agora preserva `requestId`/`retryable` no estado tecnico e registra `IMAGE_FAILED`.

## 5. Arquivos Alterados

- `docs/B-image-instruction-matrix-X.md`
- `docs/B-image-real-flow-map.md`
- `docs/B-image-system-loop-final-report.md`
- `lib/features/session/lab_session.dart`
- `lib/session/lesson_ui_state.dart`
- `lib/sim/external_ai/sim_server_ai_clients.dart`
- `lib/sim/media/lesson_image_api_contract.dart`
- `test/external_ai_clients_test.dart`
- `test/media_phase_test.dart`

## 6. Testes Criados/Atualizados

- `imagem preserva metadados tecnicos de sucesso`
- `lesson image media events preserve cache key item and layer`

Tambem passaram testes existentes de:

- visual trigger;
- SVG/template local;
- renderizacao de imagem;
- oferta paga;
- aceite/recusa;
- idempotencia;
- prefetch sem imagem paga;
- historico com imagem;
- duvida/anexo separados.

## 7. Comandos

- `flutter analyze`: PASSOU.
- `flutter test`: PASSOU, 216 testes.
- `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production`: PASSOU.
- `npm test`: NAO RODADO, pois a API nao foi alterada.

## 8. APK

- APK local: `build/app/outputs/flutter-apk/app-release.apk`
- Link publico: `http://167.179.109.137:3000/downloads/sim-production-latest.apk`
- Tamanho: `60586132 bytes`
- SHA256: `7eae14a9fd02a396d32e158db7b05a7d29c2eb2b9cb3cf62e998e683f3a9e7b3`
- Link validado: `HTTP/1.1 200 OK`, `content-length: 60586132`, `cache-control: no-store`.

## 9. Criterios Finais

| Criterio | Status |
|---|---|
| visual_trigger recebido | SIM |
| SVG/template aparece no APK | NAO PROVADO |
| oferta paga aparece | SIM em teste automatizado |
| aceitar gera imagem | SIM em teste automatizado/API; NAO PROVADO no APK |
| recusar nao cobra | SIM em teste automatizado |
| duplo toque nao duplica | SIM em teste automatizado |
| cache funciona | SIM parcial |
| erro nao bloqueia aula | SIM em teste automatizado |
| imagem atrasada entra no item correto | SIM parcial |
| prefetch nao gera imagem paga | SIM |
| First Item Fast Path preservado | SIM |
| APK real testado | NAO |
| imagem apareceu no APK | NAO PROVADO |

## 10. Git

Commit/push feito: NAO.

Motivo: a propria missao proibiu commit/push se o APK real nao foi provado com imagem aparecendo. As alteracoes estao locais aguardando prova manual ou nova autorizacao.

## 11. Proxima Prova Obrigatoria

Instalar o APK do link publico e testar no celular:

1. aula sem imagem;
2. aula com SVG/template;
3. aula com imagem paga recusada;
4. aula com imagem paga aceita;
5. duplo toque no aceite;
6. erro de imagem;
7. troca de item;
8. feedback e botao avancar visiveis.

Somente depois disso B pode virar SIM e o commit/push pode ser feito conforme a regra da missao.
