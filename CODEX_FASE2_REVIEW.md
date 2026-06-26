# REVISÃO DO GERENTE — FASE 2
## Status: APROVADA

---

## AVALIAÇÃO

Fase 2 concluída corretamente. Implementação verificada no código real.

**`LessonAnswerProgressController`** — correto. Parâmetros `store` (nullable) e `truthEngine` adicionados ao construtor. `enviarSinal()` chama `evaluateMarker()` + `writeTruthToState()` de forma **incondicional** após gravar a tentativa — melhor que a spec original que propunha `if (store != null)`. Mastery truth é sempre avaliada e persistida no estado. O evento `MASTERY_EVALUATED` vai ao canonical store quando disponível, ou ao stateService como fallback (via `_appendMasteryEvaluatedEvent()`). Boa decisão de design.

**`SimOrganism.laboratory()`** — correto. Usa `activeStore` como variável unificada e passa para o `LessonAnswerProgressController`. 113 testes verdes.

**Achado importante para a Fase 3:** Lendo `student_learning_governor.dart` (o caminho ideal de referência), vejo que após avaliar mastery, ele chama `decideNextActionFromState()` **novamente** sobre o estado com mastery escrita, e dispara `NEXT_ACTION_DECIDED`. O `processAnswerWithEngine()` já chama o decision engine internamente — mas isso acontece *antes* do mastery truth ser escrito. Hoje a decisão de progressão não vê os resultados do MasteryTruthEngine. A Fase 3 fecha esse loop.

---

## ESTADO DO PROJETO APÓS FASES 1, 1.5, 2

```
✅ StudentStateStore com SharedPrefs é o store canônico
✅ StudentStateStoreAdapter conecta o store a todos os módulos legados
✅ SimOrganism.laboratory() usa o canonicalStore externo quando fornecido
✅ Mudanças via organism.stateService chegam ao canonicalStore
✅ Progresso persiste entre sessões (SharedPrefs)
✅ MasteryTruthEngine avalia cada resposta do aluno
✅ MASTERY_EVALUATED é disparado no canonical store
✅ 113 testes verdes

❌ decideNextActionFromState() não lê resultados do MasteryTruthEngine
❌ Caminho de reforço (needsReinforcement) não adiciona review item à position
❌ NEXT_ACTION_DECIDED nunca é disparado
❌ ITEM_ADVANCED, ITEM_MASTERED, CURRICULUM_GENERATED nunca são disparados
❌ Áudio e upload ainda são mocks em produção
```

---

---

# INSTRUÇÃO PARA EXECUÇÃO — FASE 3

## OBJETIVO

Completar o `LearningDecisionEngine` para que a decisão de progressão use os resultados do `MasteryTruthEngine`, e ativar o caminho de reforço quando o mastery indica que o aluno precisa.

---

## ANTES DE COMEÇAR — LEITURA OBRIGATÓRIA

Ler completamente:
- `lib/sim/state/learning_decision_engine.dart` — estado atual (7 action types)
- `lib/sim/state/student_lesson_executor.dart` — `processAnswerWithEngine()` e `applyStudentDecision()`
- `lib/sim/state/student_learning_governor.dart` — o caminho ideal com NEXT_ACTION_DECIDED (referência)
- `lib/sim/classroom/lesson_answer_progress_controller.dart` — onde está a Phase 2 recém-feita
- `lib/sim/state/mastery_truth_engine.dart` — o que `writeTruthToState()` realmente escreve no estado

**Pergunta crítica antes de qualquer código:** O que `writeTruthToState()` escreve em `StudentLearningState`? Em que campo? Se escreve em `state.extra`, precisa checar como lê. Se escreve em campo tipado, melhor. Documente o que encontrar antes de codar.

---

## TAREFA 3.1 — Entender onde mastery truth é armazenada no estado

Ler `mastery_truth_engine.dart` — método `writeTruthToState()`.

Verificar em que campo de `StudentLearningState` o resultado é guardado. Opções prováveis:
- `state.extra['mastery_truth']` (campo genérico)
- Um campo tipado dedicado (ex: `state.masteryTruth`)

Documentar no relatório exatamente o campo e formato.

**Isso define como o `decideNextActionFromState()` poderá ler o mastery status na Tarefa 3.2.**

---

## TAREFA 3.2 — Adicionar leitura de MasteryEvidence no `decideNextActionFromState()`

**Arquivo:** `lib/sim/state/learning_decision_engine.dart`

Hoje o engine decide com base em: `lastAttempt.correct`, `lastAttempt.sinal`, `layer`, `progress.concluidos`.

Após a Fase 2, o estado também contém `MasteryEvidence` para cada marker (escrita por `writeTruthToState()`). O engine deve ler esse dado para tomar decisões mais precisas.

**Adicionar ao início da lógica principal de `decideNextActionFromState()`:**

```dart
// Ler mastery evidence do estado (se disponível)
// Uso: quando mastery diz needsReinforcement=true para o item atual,
//       o engine deve retornar needsReinforcement independente da layer
```

Regras a adicionar (em ordem de prioridade, **antes** das regras de layer):

1. **Se `evidence.needsReinforcement == true`:**
   ```dart
   return DecisionResult(
     actionType: DecisionActionType.needsReinforcement,
     reason: 'mastery engine: ${evidence.reason}',
     confidence: DecisionConfidence.high,
     proposedItemIdx: itemIdx,
     proposedLayer: layer,
     proposedMarker: currentMarker,
   );
   ```

2. **Se `evidence.status == MasteryStatus.mastered`:**
   ```dart
   // Avançar item (mastery confirmada)
   final nextIdx = itemIdx + 1;
   if (nextIdx >= total) {
     return DecisionResult(actionType: DecisionActionType.showCompletion, ...);
   }
   return DecisionResult(
     actionType: DecisionActionType.advanceItem,
     reason: 'mastery engine: item dominado',
     confidence: DecisionConfidence.high,
     proposedItemIdx: nextIdx,
     proposedLayer: LessonLayer.l1,
     proposedMarker: curriculum.items[nextIdx].marker,
   );
   ```

**Atenção:** Se `writeTruthToState()` usa `state.extra`, a leitura será via `state.extra['mastery_truth']?[marker]`. Se for campo tipado, usar diretamente. Adaptar conforme o que foi descoberto na Tarefa 3.1.

**Atenção 2:** Só adicionar essas regras — não remover ou reordenar as regras existentes. As regras de mastery ficam **antes** das regras de layer.

---

## TAREFA 3.3 — Disparar NEXT_ACTION_DECIDED no `enviarSinal()`

**Arquivo:** `lib/sim/classroom/lesson_answer_progress_controller.dart`

Após a Fase 2, `enviarSinal()` salva mastery truth no estado. Agora adicionar uma segunda chamada ao `decideNextActionFromState()` sobre o estado atualizado com mastery, e registrar o evento.

Localizar em `enviarSinal()`, logo após `_appendMasteryEvaluatedEvent(...)`:

```dart
// Após: _appendMasteryEvaluatedEvent(...)

final finalState = stateService.read(lessonLocalId) ?? savedTruthState;
final nextAction = decideNextActionFromState(finalState);
final canonicalStore2 = store;
if (canonicalStore2 != null) {
  canonicalStore2.appendEvent(
    lessonLocalId: lessonLocalId,
    type: 'NEXT_ACTION_DECIDED',
    source: 'lesson-answer-progress-controller',
    payload: {
      'action_type': nextAction.actionType.name,
      'reason': nextAction.reason,
      'confidence': nextAction.confidence.name,
      'proposed_item_idx': nextAction.proposedItemIdx,
      'proposed_layer': nextAction.proposedLayer?.value,
      'proposed_marker': nextAction.proposedMarker,
    },
  );
}
```

Adicionar import de `learning_decision_engine.dart` se não existir.

---

## TAREFA 3.4 — Ativar o caminho de reforço em `avancar()`

**Arquivo:** `lib/sim/classroom/lesson_answer_progress_controller.dart`

Hoje quando `decideNextActionFromState()` retorna `needsReinforcement`, o `applyStudentDecision()` trata como no-op (não avança, não faz nada concreto). O aluno simplesmente fica na mesma posição.

O caminho correto é: quando `view.layer == position.layer && view.itemIdx == position.itemIdx` **e** o estado tem `needsReinforcement=true` para o item ativo, adicionar um item de review à `position.items`.

**Localizar em `avancar()`** a seção onde position é atualizada. Adicionar após atualizar `position.layer`, `position.itemIdx`, etc.:

```dart
// Verificar se o engine pediu reforço para este item
final state = stateService.read(lessonLocalId);
if (state != null && view != null && !view.ended) {
  final activeMarker = position.itemAtivo?.marker;
  if (activeMarker != null) {
    // Verificar se o estado indica needsReinforcement para o marker
    // (ler de state.extra ou campo tipado conforme Tarefa 3.1)
    final needsReinforcement = _checkNeedsReinforcement(state, activeMarker);
    if (needsReinforcement && !position.items.any(
      (item) => item.isReview && item.marker == activeMarker)) {
      position.items = [
        ...position.items,
        PlannedItem(
          marker: activeMarker,
          text: position.itemAtivo?.text ?? '',
          isReview: true,
        ),
      ];
    }
  }
}
```

Implementar `_checkNeedsReinforcement()` como método privado que lê o estado de mastery do item. A implementação depende do que Tarefa 3.1 descobriu.

**IMPORTANTE:** Se `PlannedItem` não tem parâmetro `isReview` no construtor, verificar a assinatura real antes de usar. Adaptar conforme necessário. Não inventar construtores que não existem.

---

## TAREFA 3.5 — Disparar ITEM_ADVANCED e ITEM_MASTERED

**Arquivo:** `lib/sim/classroom/lesson_answer_progress_controller.dart`

Em `enviarSinal()`, após a decisão, verificar se houve avanço de item e disparar os eventos canônicos.

```dart
// Após nextAction ser calculado (Tarefa 3.3):
final activeStore3 = store;
if (activeStore3 != null) {
  if (nextAction.actionType == DecisionActionType.advanceItem) {
    activeStore3.appendEvent(
      lessonLocalId: lessonLocalId,
      type: 'ITEM_ADVANCED',
      source: 'lesson-answer-progress-controller',
      payload: {
        'from_item_idx': finalState.progress?.itemIdx,
        'to_item_idx': nextAction.proposedItemIdx,
        'marker': item.marker,
      },
    );
  }
  // Se mastery = mastered, disparar ITEM_MASTERED
  final currentEvidence = truthEngine.evaluateMarker(finalState, item.marker);
  if (currentEvidence.status == MasteryStatus.mastered) {
    activeStore3.appendEvent(
      lessonLocalId: lessonLocalId,
      type: 'ITEM_MASTERED',
      source: 'lesson-answer-progress-controller',
      payload: {
        'marker': item.marker,
        'score': currentEvidence.score,
        'attempt_count': currentEvidence.attemptCount,
      },
    );
  }
}
```

---

## TAREFA 3.6 — NÃO alterar `processAnswerWithEngine()`

Assim como na Fase 2, `processAnswerWithEngine()` é função pura. Não alterar. Ela já chama `decideNextActionFromState()` internamente. A Fase 3 adiciona uma segunda chamada DEPOIS que o mastery foi escrito — essa segunda chamada é no controller, não na função pura.

Documentar essa decisão no relatório.

---

## TAREFA 3.7 — Criar testes para a Fase 3

Criar arquivo: `test/fase3_decision_test.dart`

**Teste 1 — decideNextActionFromState usa mastery para triggerar reforço:**
```dart
test('mastery needsReinforcement force-retorna needsReinforcement', () {
  // Criar estado com 2 erros consecutivos no mesmo marker
  // Chamar writeTruthToState() para escrever evidence
  // Chamar decideNextActionFromState()
  // Esperar actionType == DecisionActionType.needsReinforcement
});
```

**Teste 2 — mastery mastered avança item:**
```dart
test('mastery mastered retorna advanceItem', () {
  // Criar estado com 3 acertos consecutivos
  // Escrever mastery via writeTruthToState()
  // Chamar decideNextActionFromState()
  // Esperar actionType == DecisionActionType.advanceItem
});
```

**Teste 3 — NEXT_ACTION_DECIDED é disparado no controller:**
```dart
test('enviarSinal dispara NEXT_ACTION_DECIDED no store', () {
  // Usar store canônico em memória
  // Criar controller com store
  // Simular resposta
  // Verificar store.getEventLog() contém NEXT_ACTION_DECIDED
});
```

---

## TAREFA 3.8 — Commitar em subtarefas

```
git commit -m "fase-3: decision engine reads mastery evidence from state"
git commit -m "fase-3: dispatch NEXT_ACTION_DECIDED after mastery in enviarSinal"
git commit -m "fase-3: activate reinforcement path in avancar"
git commit -m "fase-3: dispatch ITEM_ADVANCED and ITEM_MASTERED events"
git commit -m "fase-3: add decision engine tests"
git push
```

---

## CRITÉRIO DE CONCLUSÃO DA FASE 3

```
[ ] decideNextActionFromState() lê mastery evidence do estado
[ ] needsReinforcement de mastery → engine retorna needsReinforcement
[ ] mastered de mastery → engine retorna advanceItem (quando há próximo item)
[ ] NEXT_ACTION_DECIDED disparado após mastery em enviarSinal()
[ ] Caminho de reforço adiciona review item a position.items em avancar()
[ ] ITEM_ADVANCED disparado quando advanceItem
[ ] ITEM_MASTERED disparado quando mastered
[ ] processAnswerWithEngine() NÃO foi alterada
[ ] Testes criados e passando
[ ] flutter analyze: zero erros
[ ] flutter test: todos verdes (mínimo 113 + novos)
[ ] git status limpo
```

---

## FORMATO DO RELATÓRIO DA FASE 3

```
# RELATÓRIO — FASE 3 CONCLUÍDA

## 3.1 — writeTruthToState() — onde escreve
[campo exato no estado, formato]

## 3.2 — decideNextActionFromState() com mastery
[o que foi adicionado, em que ordem, linha exata]

## 3.3 — NEXT_ACTION_DECIDED
[onde foi adicionado, código]

## 3.4 — Caminho de reforço em avancar()
[o que foi implementado, limitações encontradas]

## 3.5 — ITEM_ADVANCED e ITEM_MASTERED
[disparados? em que condição?]

## 3.6 — processAnswerWithEngine() não alterada
[confirmação]

## 3.7 — Testes
[lista de testes, resultados]

## OBSERVAÇÕES ADICIONAIS
[qualquer coisa inesperada]

## CRITÉRIO DE CONCLUSÃO
[checklist]

## PRONTO PARA FASE 4?
[sim / não — e por quê]
```

**Após entregar o relatório, aguarde. Não inicie a Fase 4 sem aprovação.**

---

*Aprovação Fase 2: 2026-06-26*
*Instruções Fase 3 emitidas: 2026-06-26*
*Gerente técnico: Claude*
