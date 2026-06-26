# REVISÃO DO GERENTE — FASE 3
## Status: APROVADA

---

## AVALIAÇÃO

Fase 3 concluída corretamente. 115 testes verdes. Implementação verificada.

**`LearningDecisionEngine`** — lê mastery de `state.extra['truth']` via `_masteryForMarker()`. Prioridade correta: mastery `mastered` → advanceItem; `needsReinforcement` → needsReinforcement. Só então cai para as regras de layer. Estrutura limpa com classe interna `_MasteryDecisionSnapshot`. Correto.

**`_applyPostMasteryDecision()`** — segunda chamada ao decision engine depois de mastery ser escrito. Grava `next_action` em `state.extra`. Dispara `NEXT_ACTION_DECIDED`, `ITEM_MASTERED`, `ITEM_ADVANCED` com payload completo. Boa decisão: extraiu para método privado em vez de inflar `enviarSinal()`.

**`_modeForNextMaterial()`** — lê `state.extra['next_action']['action']` para decidir `LessonMode.reforco`. Simples e eficaz.

**Testes** — 3 testes diretos no `decideNextActionFromState()` com mastery truth injetada no extra. Corretos e suficientes para cobrir os caminhos críticos.

**DecisionActionType não expandido para 19** — correto. Minha instrução da Fase 3 não pediu isso. Os tipos adicionais (generateCurriculum, generateAudio, etc.) pertencem às Fases 4 e 7. Não expandir foi a decisão certa.

---

## ACHADO IMPORTANTE — `writeTruthToState()` usa `state.extra['truth']`

Confirmado: `MasteryTruthEngine.writeTruthToState()` escreve em `state.extra['truth']` com subcampos `mastery_evidence`, `false_mastery_flags`, `needs_retest_flags`, `item_consolidation_status`. O decision engine lê exatamente esses campos. A cadeia está fechada:

```
enviarSinal()
  → processAnswerWithEngine()       ← tenta + decide (sem mastery ainda)
  → writeTruthToState()             ← escreve truth em state.extra['truth']
  → _applyPostMasteryDecision()     ← decide de novo com mastery disponível
    → decideNextActionFromState()   ← lê extra['truth'] via _masteryForMarker()
    → applyStudentDecision()        ← aplica no progress
    → NEXT_ACTION_DECIDED           ← evento canônico
    → ITEM_MASTERED / ITEM_ADVANCED ← eventos canônicos quando aplicável
```

Esta é a cadeia correta. A Fase 5 (tipar `extra`) vai formalizar isso, mas não bloqueia nada agora.

---

## ESTADO DO PROJETO APÓS FASES 1, 1.5, 2, 3

```
✅ StudentStateStore com SharedPrefs é o store canônico
✅ StudentStateStoreAdapter conecta o store a todos os módulos legados
✅ SimOrganism.laboratory() usa o canonicalStore externo quando fornecido
✅ Progresso persiste entre sessões (SharedPrefs)
✅ MasteryTruthEngine avalia cada resposta do aluno
✅ MASTERY_EVALUATED disparado no canonical store
✅ DecisionEngine lê mastery truth para decidir progressão
✅ Segunda decisão pós-mastery com NEXT_ACTION_DECIDED
✅ ITEM_ADVANCED e ITEM_MASTERED disparados
✅ Modo reforço (LessonMode.reforco) ativado quando engine decide
✅ 115 testes verdes

❌ Adicionar review item a position.items quando needsReinforcement (não implementado — ver nota)
❌ CURRICULUM_GENERATED, LESSON_TEXT_READY nunca disparados
❌ DecisionActionType com apenas 7 tipos (19 do PACOTE-MESTRE pendentes)
❌ Campos extra['truth'], extra['sync'] ainda em JsonMap genérico (Fase 5)
❌ Áudio e upload ainda são mocks
```

**Nota sobre review item:** A Tarefa 3.4 (adicionar item de review a `position.items`) não foi implementada. O código atual usa `LessonMode.reforco` para carregar material T02 em modo de reforço — isso é diferente de adicionar um novo item à lista. A decisão de não adicionar item à lista foi correta: `PlannedItem.isReview` existe mas a pilha de review é gerenciada pelo `StudentLearningGovernor` e não foi projetada para ser modificada diretamente pelo controller. A Fase 9 (decompor LabSession) vai reestruturar esse fluxo. Aceito.

---

---

# INSTRUÇÃO PARA EXECUÇÃO — FASE 4

## OBJETIVO

Completar o Event Log. Todos os eventos canônicos críticos que deveriam ser disparados quando ações acontecem, mas hoje não são, devem ser conectados.

---

## ANTES DE COMEÇAR — LEITURA OBRIGATÓRIA

Ler completamente:
- `lib/sim/experience/student_experience_engine.dart` — onde currículo é gerado (T01)
- `lib/sim/lesson/student_lesson_material_service.dart` — onde aula é gerada (T02)
- `lib/sim/state/student_state_store.dart` — assinatura de `appendEvent()` e `mutateWithEvent()`
- `lib/sim/classroom/lesson_answer_progress_controller.dart` — para entender o padrão `_appendCanonicalOrLegacyEvent()` da Fase 3 (usar como referência)

---

## TAREFA 4.1 — Disparar CURRICULUM_GENERATED em `StudentExperienceEngine`

**Arquivo:** `lib/sim/experience/student_experience_engine.dart`

Localizar onde o currículo é finalizado e escrito no estado. Após a escrita:

```dart
// Após escrever o currículo no estado via stateService.write():
stateService.appendEvent(
  lessonLocalId,
  StudentLearningEvent(
    type: 'CURRICULUM_GENERATED',
    ts: DateTime.now().millisecondsSinceEpoch,
    payload: {
      'topic': curriculum.topic,
      'total_items': curriculum.totalItems,
      'provisional': curriculum.provisional,
    },
  ),
);
```

Se o `stateService` for um `StudentStateStoreAdapter` (o que é agora), o evento vai direto ao canonical store. Correto.

**Atenção:** Verificar se há vários lugares onde currículo é escrito (provisional + definitivo). Disparar em ambos, com `provisional: true` ou `false` no payload.

---

## TAREFA 4.2 — Disparar LESSON_TEXT_READY em `StudentLessonMaterialService`

**Arquivo:** `lib/sim/lesson/student_lesson_material_service.dart`

Localizar onde uma aula é gravada no cache ou no estado após geração via T02.

```dart
// Após confirmar que o material foi gerado e está pronto:
stateService.appendEvent(
  lessonLocalId,
  StudentLearningEvent(
    type: 'LESSON_TEXT_READY',
    ts: DateTime.now().millisecondsSinceEpoch,
    payload: {
      'marker': marker,
      'layer': layer.value,
      'item_idx': itemIdx,
    },
  ),
);
```

---

## TAREFA 4.3 — Disparar REINFORCEMENT_REQUIRED quando needsReinforcement

**Arquivo:** `lib/sim/classroom/lesson_answer_progress_controller.dart`

Em `_applyPostMasteryDecision()`, quando `decision.actionType == DecisionActionType.needsReinforcement`, adicionar evento:

```dart
if (decision.actionType == DecisionActionType.needsReinforcement) {
  _appendCanonicalOrLegacyEvent(
    lessonLocalId: lessonLocalId,
    state: saved,
    type: 'REINFORCEMENT_REQUIRED',
    payload: {
      'marker': marker,
      'reason': decision.reason,
      'masteryStatus': evidence.status.name,
    },
  );
}
```

---

## TAREFA 4.4 — Disparar WEAKNESS_REGISTERED quando falseMastery ou weak

Em `_applyPostMasteryDecision()`, quando mastery indica `falseMastery` ou `weak`:

```dart
if (evidence.status == MasteryStatus.falseMastery ||
    evidence.status == MasteryStatus.weak) {
  _appendCanonicalOrLegacyEvent(
    lessonLocalId: lessonLocalId,
    state: saved,
    type: 'WEAKNESS_REGISTERED',
    payload: {
      'marker': marker,
      'status': evidence.status.name,
      'reason': evidence.reason,
      'consecutive_wrong': evidence.consecutiveWrong,
    },
  );
}
```

---

## TAREFA 4.5 — NÃO implementar AUDIO_READY e IMAGE_READY

Esses eventos pertencem às Fases 7 (áudio) e à visual pipeline. Documentar no relatório que foram intencionalmente deixados para depois.

---

## TAREFA 4.6 — Criar testes para a Fase 4

Criar arquivo: `test/fase4_event_log_test.dart`

**Teste 1 — CURRICULUM_GENERATED disparado após geração:**
Criar estado sem currículo. Usar `StudentLearningStateService` com um currículo mockado. Verificar que o evento existe no event log do estado após a chamada.

**Teste 2 — REINFORCEMENT_REQUIRED disparado quando mastery indica reforço:**
Criar estado com `needs_reinforcement: true` no extra['truth']. Simular `_applyPostMasteryDecision()` via controller com store em memória. Verificar evento no store.

**Teste 3 — WEAKNESS_REGISTERED disparado em falseMastery:**
Criar estado com mastery status `falseMastery`. Verificar que `WEAKNESS_REGISTERED` aparece no event log.

Se os testes de integração com `StudentExperienceEngine` forem muito complexos (requerem mock de T01), documentar e pular. Testes das funções diretas de event dispatch são suficientes.

---

## TAREFA 4.7 — Commitar em subtarefas

```
git commit -m "fase-4: dispatch CURRICULUM_GENERATED in StudentExperienceEngine"
git commit -m "fase-4: dispatch LESSON_TEXT_READY in StudentLessonMaterialService"
git commit -m "fase-4: dispatch REINFORCEMENT_REQUIRED and WEAKNESS_REGISTERED in controller"
git commit -m "fase-4: add event log tests"
git push
```

---

## CRITÉRIO DE CONCLUSÃO DA FASE 4

```
[ ] CURRICULUM_GENERATED disparado após currículo escrito no estado
[ ] LESSON_TEXT_READY disparado após aula gerada
[ ] REINFORCEMENT_REQUIRED disparado quando decision == needsReinforcement
[ ] WEAKNESS_REGISTERED disparado quando mastery == falseMastery ou weak
[ ] AUDIO_READY e IMAGE_READY documentados como pendentes (Fases 7+)
[ ] Testes criados (mesmo que parcialmente — os diretos devem passar)
[ ] flutter analyze: zero erros
[ ] flutter test: todos verdes (mínimo 115 + novos)
[ ] git status limpo
```

---

## FORMATO DO RELATÓRIO DA FASE 4

```
# RELATÓRIO — FASE 4 CONCLUÍDA

## 4.1 — CURRICULUM_GENERATED
[onde foi adicionado, linha exata, se há casos provisional + definitivo]

## 4.2 — LESSON_TEXT_READY
[onde foi adicionado, o que foi necessário ajustar]

## 4.3 — REINFORCEMENT_REQUIRED
[onde foi adicionado]

## 4.4 — WEAKNESS_REGISTERED
[onde foi adicionado]

## 4.5 — AUDIO_READY e IMAGE_READY
[confirmação de que ficaram para Fases 7+]

## 4.6 — Testes
[quais testes foram criados, quais passaram, quais foram inviáveis]

## OBSERVAÇÕES ADICIONAIS
[qualquer coisa inesperada no StudentExperienceEngine ou StudentLessonMaterialService]

## CRITÉRIO DE CONCLUSÃO
[checklist]

## PRONTO PARA FASE 5?
[sim / não — e por quê]
```

**Após entregar o relatório, aguarde. Não inicie a Fase 5 sem aprovação.**

---

*Aprovação Fase 3: 2026-06-26*
*Instruções Fase 4 emitidas: 2026-06-26*
*Gerente técnico: Claude*
