# B2 - Paridade da logica pedagogica T00/T02/aula/duvida/revisao/recuperacao

## 1. Estamos em B2?

SIM.

Os 6 itens levantados no B1 foram fechados com implementacao nos orgaos corretos, testes automatizados e validacoes finais. O SimWeb nao foi alterado.

## 2. Checklist B2

| ID | Status final | Prova |
|---|---|---|
| LESSON-B2-001 - validacao T02 API/Flutter | COMPLETO COM TESTE | API rejeita contrato T02 invalido em `src/t02/complete-lesson-controller.js`; Flutter valida em `lib/sim/lesson/lesson_content_validator.dart` e `lib/sim/external_ai/sim_server_ai_clients.dart`. Testes em `test/server-contract.test.js` e `test/external_ai_clients_test.dart`. |
| LESSON-B2-002 - retry T02 por contrato invalido | COMPLETO COM TESTE | API faz ate 3 tentativas somente para `T02_CONTRACT_INVALID`, sem retry infinito. Teste prova primeira resposta invalida e segunda valida em `test/server-contract.test.js`. |
| LESSON-B2-003 - eventos T00 informativos | COMPLETO COM TESTE | `StudentExperienceT00Adapter` preserva `t00_partial_ready`, fallback gateway e `t00_quality_check` sem bloquear fast path. Teste em `test/student_experience_t00_test.dart`. |
| LESSON-B2-004 - duvida com foto/dataUrl | COMPLETO COM TESTE | Flutter envia `doubt_image.dataUrl`; API transforma data URL em inline image segura para T02. Testes em `test/auxiliary_phase_test.dart` e `test/server-contract.test.js`. |
| LESSON-B2-005 - revisao/recuperacao integradas | COMPLETO COM TESTE | Testes provam fila, chamada T02 auxiliar, tentativa, limpeza de pendencia, bloqueio/liberacao de conclusao e preservacao da aula principal em `test/auxiliary_phase_test.dart`. |
| LESSON-B2-006 - cache/material invalido descartado | COMPLETO COM TESTE | Ready state e cache persistido passam pelo validador T02; material invalido e descartado e T02 e chamado novamente. Testes em `test/first_lesson_ready_window_test.dart`. |

## 3. Arquivos alterados

Flutter:

- `lib/sim/lesson/lesson_content_validator.dart`
- `lib/sim/external_ai/sim_server_ai_clients.dart`
- `lib/sim/lesson/student_lesson_material_service.dart`
- `lib/sim/lesson/lesson_material_cache.dart`
- `lib/sim/experience/student_experience_types.dart`
- `lib/sim/experience/student_experience_t00_adapter.dart`
- `lib/sim/auxiliary/doubt_t02_caller.dart`
- `test/external_ai_clients_test.dart`
- `test/student_experience_t00_test.dart`
- `test/auxiliary_phase_test.dart`
- `test/first_lesson_ready_window_test.dart`

API:

- `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js`
- `/root/sim-work/sim-api/test/server-contract.test.js`

SimWeb:

- Nenhum arquivo alterado.

## 4. Testes criados/alterados

- `test/external_ai_clients_test.dart`: T02 invalido nao vira aula falsa nem default A.
- `test/student_experience_t00_test.dart`: eventos informativos T00 ficam auditaveis e `done` nao apaga curriculo.
- `test/auxiliary_phase_test.dart`: duvida com `dataUrl`, revisao integrada e recuperacao integrada.
- `test/first_lesson_ready_window_test.dart`: ready material invalido e cache persistido invalido sao descartados.
- `/root/sim-work/sim-api/test/server-contract.test.js`: validacao T02, retry controlado e inline image da duvida.

## 5. Provas funcionais

T02 invalido nao vira aula falsa:

- API rejeita `explanation` vazia, `question` vazia, `options.A/B/C` vazias e `correct_answer` fora de A/B/C/null.
- Flutter usa `validatedLessonContentFromJson` e converte contrato invalido em `SimExternalAiException`, sem defaultar `correct_answer` para A.

Retry T02:

- O gateway T02 da API tenta ate 3 vezes somente quando o erro e `T02_CONTRACT_INVALID`.
- Teste prova tentativa 1 invalida, tentativa 2 valida e resposta final correta.

Eventos T00:

- `t00_partial_ready`, fallback gateway e `t00_quality_check` sao refletidos como eventos da experiencia.
- O primeiro item continua liberado pelo fast path e `done` nao apaga curriculo.

Duvida com foto:

- `DoubtT02Caller` inclui `doubt_image.dataUrl`.
- A API aceita `data:image/jpeg|png|webp;base64,...`, limita tamanho e encaminha inline image ao T02.
- Duvida sem foto continua funcionando.

Revisao/recuperacao:

- Sinal 2 cria revisao, chama T02 auxiliar, registra tentativa, limpa pendencia e preserva item/layer da aula principal.
- Sinal 3/erro cria recuperacao, bloqueia conclusao enquanto pendente, chama T02 auxiliar, limpa pendencia e libera conclusao.

Cache invalido:

- Material pronto invalido em `StudentLearningState` e descartado antes de exibicao.
- Cache persistido invalido e ignorado na hidratacao.
- O fluxo chama T02 novamente e exibe material valido.

## 6. Conformidade com a Planta-Mae

Arquivos/orgaos usados:

- API T02 gateway: `/root/sim-work/sim-api/src/t02/complete-lesson-controller.js`.
- Parser Flutter T02: `lib/sim/external_ai/sim_server_ai_clients.dart` e `lib/sim/lesson/lesson_content_validator.dart`.
- T00 adapter: `lib/sim/experience/student_experience_t00_adapter.dart`.
- Doubt caller: `lib/sim/auxiliary/doubt_t02_caller.dart`.
- Aux rooms: `lib/sim/auxiliary/*` por testes de revisao/recuperacao.
- Lesson material service/cache: `lib/sim/lesson/student_lesson_material_service.dart`, `lib/sim/lesson/lesson_material_cache.dart`.

Respostas arquiteturais:

- Responsabilidade misturada? NAO.
- Estado paralelo criado? NAO.
- Mock/fallback falso de producao criado? NAO.
- Logica pedagogica colocada na UI? NAO.
- Funcao duplicada? NAO.
- Arquitetura modular preservada? SIM.

## 7. SimWeb

O SimWeb foi usado apenas como referencia do contrato saudavel. Nenhum arquivo do SimWeb foi alterado.

## 8. Validacoes finais

Flutter:

- `flutter analyze`: PASSOU, `No issues found!`.
- `flutter test`: PASSOU, `+188: All tests passed!`.
- `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production`: PASSOU com `GRADLE_OPTS=-Dorg.gradle.vfs.watch=false`; APK gerado em `build/app/outputs/flutter-apk/app-release.apk` com 60.2MB.

API:

- `npm test`: PASSOU, `server contract tests passed`.

## 9. Diferencas restantes

Nenhuma diferenca B2 permanece parcial, ausente, nao conectada, mockada ou pendente de decisao humana.

## 10. Veredito final

Estamos em B2? SIM.
