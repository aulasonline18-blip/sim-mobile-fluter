# CODEX SMOKE BASELINE ? FASE 1

Data: 2026-06-26
Branch: claude/app-audit-report-5a22ba
Ambiente: VM /root/sim-mobile-fluter

## Disponibilidade de dispositivo

`/root/flutter/bin/flutter devices` detectou apenas:

- Linux (desktop) ? Ubuntu 24.04.4 LTS

N?o havia emulador Android/tablet conectado na VM no momento da Fase 1. Portanto, o smoke manual Android completo n?o p?de ser executado antes da altera??o. Este baseline registra o comportamento atual inferido e os bloqueios observ?veis no c?digo desta branch, para compara??o de regress?o m?nima.

## Checklist baseline pr?-Fase 1

1. Criar aula nova ? T4 interpreta ? curr?culo gerado ? primeira aula abre
   - N?o executado em dispositivo Android nesta VM. Pelo c?digo, `saveObjectiveEntry()` navega para `/cyber/curriculo`; `StudentExperienceEngine` usa `StudentLearningStateService` em mem?ria.

2. Responder certo com sinal 1 na L1 ? avan?o para qual layer?
   - N?o executado em dispositivo Android. Pelo c?digo, `processAnswerWithEngine()` chama `decideNextActionFromState()` e testes existentes indicam avan?o L1 ? L3 em caso f?cil.

3. Responder errado na L1 ? o que aparece?
   - N?o executado em dispositivo Android. Pelo c?digo, erro incrementa `progress.erros` e a decis?o passa por `LearningDecisionEngine`, mas sem `MasteryTruthEngine`.

4. Errar 2x no mesmo item ? o que acontece?
   - N?o executado em dispositivo Android. Pelo c?digo, attempts acumulam no estado fraco; n?o h? avalia??o de dom?nio pelo `MasteryTruthEngine`.

5. Fechar app completamente ? reabrir ? progresso est? l??
   - Baseline esperado nesta branch: n?o confi?vel/n?o persistente no fluxo governante, pois `StudentLearningStateService` ? em mem?ria.

6. Clicar no bot?o de ?udio ? o que aparece?
   - Pelo c?digo legado em `main.dart`, `toggleAudio()` usa `Future.delayed(180ms)`, desliga ?udio e mostra `?udio pausado.`.

7. Chegar no ?ltimo item e responder corretamente ? tela de conclus?o aparece?
   - N?o executado em dispositivo Android. Pelo c?digo, `LessonAnswerProgressController` pode setar `ClassroomPhase.doneEnd()` e `FINAL_COMPLETION_ALLOWED`.

## Observa??o

Este baseline deve ser substitu?do por smoke manual real assim que houver emulador/dispositivo Android dispon?vel na VM. A Fase 1 continua para atender a persist?ncia local, mas qualquer diverg?ncia funcional fora do item 5 deve ser tratada como risco.
