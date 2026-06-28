# REVISÃO DO GERENTE — FASE 1.5
## Status: APROVADA

---

## AVALIAÇÃO

Fase 1.5 concluída corretamente. Tudo confirmado.

**Achado importante:** O ponto de entrada real não é `SimOrganism.boot()` mas sim `SimOrganism.laboratory()`. O parâmetro `canonicalStore` já existia nesse método e já criava o `StudentStateStoreAdapter` corretamente. A cadeia estava quase completa — faltava apenas o teste que prova isso.

**O teste `organism_integration_test.dart` é preciso:**
- Cria `canonicalStore` externo
- Passa para `SimOrganism.laboratory()`
- Escreve via `organism.stateService.mutate()`
- Lê diretamente do `canonicalStore`
- Confirma que são o mesmo store

Isso é exatamente o que precisava ser provado. 111 testes verdes, zero issues.

---

## ESTADO DO PROJETO APÓS FASES 1, 1.5

```
✅ StudentStateStore com SharedPrefs é o store canônico
✅ StudentStateStoreAdapter conecta o store a todos os módulos legados
✅ SimOrganism.laboratory() usa o canonicalStore externo quando fornecido
✅ Mudanças via organism.stateService chegam ao canonicalStore
✅ Progresso persiste entre sessões (SharedPrefs)
✅ 111 testes verdes

❌ MasteryTruthEngine não avalia cada resposta do aluno
❌ Eventos ITEM_ADVANCED, ITEM_MASTERED, CURRICULUM_GENERATED nunca são disparados
❌ Áudio e upload ainda são mocks em produção
```

A fundação está sólida. Próximo: conectar o `MasteryTruthEngine` ao fluxo de resposta.

---

---

# INSTRUÇÃO PARA EXECUÇÃO — FASE 2

## OBJETIVO

Conectar o `MasteryTruthEngine` ao fluxo de resposta do aluno.

Hoje, quando o aluno responde, o caminho é:
```
LessonAnswerProgressController.enviarSinal()
  → processAnswerWithEngine()        ← grava tentativa + chama DecisionEngine
    → stateService.write()           ← salva no store canônico
                                     ← MasteryTruthEngine NÃO é chamado aqui
```

Após a Fase 2, o caminho será:
```
LessonAnswerProgressController.enviarSinal()
  → processAnswerWithEngine()        ← grava tentativa + chama DecisionEngine
    → stateService.write()           ← salva no store canônico
    → MasteryTruthEngine.evaluateMarker()   ← avalia domínio pedagógico
    → store.mutateWithEvent(MASTERY_EVALUATED) ← registra evento canônico
```

---

## ANTES DE COMEÇAR — LEITURA OBRIGATÓRIA

Ler completamente os seguintes arquivos:
- `lib/sim/state/mastery_truth_engine.dart` — entender `evaluateMarker()` e `writeTruthToState()`
- `lib/sim/classroom/lesson_answer_progress_controller.dart` — entender `enviarSinal()`
- `lib/sim/state/student_lesson_executor.dart` — entender `processAnswerWithEngine()`
- `lib/sim/state/student_learning_governor.dart` — ver como o caminho ideal já faz isso (referência)

O `StudentLearningGovernor.submitAnswer()` já tem a implementação correta com `MasteryTruthEngine`. Use como referência — não copie cegamente, adapte ao contexto do controller.

---

## TAREFA 2.1 — Injetar `MasteryTruthEngine` e `StudentStateStore` no `LessonAnswerProgressController`

**Arquivo:** `lib/sim/classroom/lesson_answer_progress_controller.dart`

O controller hoje recebe `stateService: StudentLearningStateService`. Precisamos também do `store` para disparar eventos canônicos, e do `truthEngine` para avaliar domínio.

Adicionar ao construtor:
```dart
class LessonAnswerProgressController {
  LessonAnswerProgressController({
    required this.stateService,
    required this.materialService,
    required this.materialController,
    StudentStateStore? store,
    MasteryTruthEngine? truthEngine,
  }) : store = store,
       truthEngine = truthEngine ?? const MasteryTruthEngine();

  final StudentLearningStateService stateService;
  final StudentLessonMaterialService materialService;
  final LessonMaterialController materialController;
  final StudentStateStore? store;       // nullable: compatibilidade com testes existentes
  final MasteryTruthEngine truthEngine;
```

**IMPORTANTE:** `store` é nullable intencionalmente. Se `store` for null (testes legados que não passam store), o controller funciona igual a antes. Só avalia mastery quando store está disponível. Isso preserva os 111 testes existentes.

---

## TAREFA 2.2 — Chamar MasteryTruthEngine após gravar a tentativa em `enviarSinal()`

**Arquivo:** `lib/sim/classroom/lesson_answer_progress_controller.dart`

Localizar o trecho em `enviarSinal()` onde `stateService.write(nextState)` é chamado (aproximadamente linha 98). Logo após esse write, adicionar:

```dart
// Após: stateService.write(nextState)

final activeStore = store;
if (activeStore != null) {
  final stateAfterWrite = stateService.read(lessonLocalId) ?? nextState;
  final itemMarker = item.marker;

  // Avaliar domínio pedagógico
  final evidence = truthEngine.evaluateMarker(stateAfterWrite, itemMarker);

  // Escrever resultado no estado
  final stateWithTruth = truthEngine.writeTruthToState(stateAfterWrite, evidence);
  stateService.write(stateWithTruth);

  // Registrar evento canônico
  activeStore.appendEvent(
    lessonLocalId: lessonLocalId,
    type: 'MASTERY_EVALUATED',
    source: 'lesson-answer-progress-controller',
    payload: evidence.toJson(),
  );
}
```

**Atenção aos tipos:** Verificar que `item` é acessível neste escopo. Se `item` for de tipo `PlannedItem`, usar `item.marker`. Se for `CurriculumItem`, usar `item.marker` também — ambos têm `marker`.

---

## TAREFA 2.3 — Passar o `store` para `LessonAnswerProgressController` no `SimOrganism.laboratory()`

**Arquivo:** `lib/sim/organism/sim_organism.dart`

Localizar onde `LessonAnswerProgressController` é instanciado dentro de `SimOrganism.laboratory()`. Adicionar `store`:

```dart
// Localizar a instanciação (algo como):
final answerController = LessonAnswerProgressController(
  stateService: stateService,
  materialService: materialService,
  materialController: materialController,
  // ADICIONAR:
  store: canonicalStore ?? StudentStateStore(local: MemoryStudentStateLocalStorage()),
);
```

Se `LessonAnswerProgressController` é criado em outro lugar (verificar se é passado como parâmetro ou criado internamente), ajustar o ponto correto.

---

## TAREFA 2.4 — Disparar evento MASTERY_EVALUATED também no `processAnswerWithEngine()`

**Arquivo:** `lib/sim/state/student_lesson_executor.dart`

`processAnswerWithEngine()` é uma função pura que não tem acesso ao `store`. Não é possível disparar o evento canônico diretamente dali sem mudar a assinatura.

**Decisão de design:** NÃO alterar `processAnswerWithEngine()`. Ela é uma função pura — manter assim. A avaliação de mastery e o evento canônico acontecem no `LessonAnswerProgressController` (Tarefa 2.2), que tem acesso ao store.

Documentar esta decisão no relatório.

---

## TAREFA 2.5 — Criar testes para a Fase 2

Criar arquivo: `test/fase2_mastery_test.dart`

**Teste 1 — MasteryTruthEngine avalia depois de 2 erros seguidos:**
```dart
test('dois erros com sinal fácil resultam em falseMastery', () {
  // Criar estado com 2 tentativas erradas com sinal 1 no mesmo marker
  // Chamar evaluateMarker()
  // Esperar MasteryStatus.falseMastery ou MasteryStatus.weak
});
```

**Teste 2 — 3 acertos consecutivos resultam em mastered:**
```dart
test('tres acertos consecutivos resultam em mastered', () {
  // Criar estado com 3 tentativas corretas no mesmo marker
  // Chamar evaluateMarker()
  // Esperar MasteryStatus.mastered
});
```

**Teste 3 — evento MASTERY_EVALUATED é disparado no controller:**
```dart
test('enviarSinal dispara evento MASTERY_EVALUATED no store canônico', () {
  // Criar store canônico com MemoryStudentStateLocalStorage
  // Criar controller com store
  // Simular uma resposta completa (selecionar + enviarSinal)
  // Verificar que store.getEventLog() contém evento MASTERY_EVALUATED
});
```

Os testes 1 e 2 testam `MasteryTruthEngine` diretamente (fácil, é classe pura).
O teste 3 é integração — pode ser mais complexo. Se não for viável isolar, documentar e pular.

---

## TAREFA 2.6 — Commitar em subtarefas

```
git commit -m "fase-2: inject MasteryTruthEngine and store into LessonAnswerProgressController"
git commit -m "fase-2: call MasteryTruthEngine after answer in enviarSinal"
git commit -m "fase-2: pass canonical store to LessonAnswerProgressController in SimOrganism"
git commit -m "fase-2: add mastery truth engine tests"
git push
```

---

## CRITÉRIO DE CONCLUSÃO DA FASE 2

```
[ ] LessonAnswerProgressController tem parâmetros store e truthEngine
[ ] enviarSinal() chama MasteryTruthEngine.evaluateMarker() quando store está disponível
[ ] enviarSinal() dispara evento MASTERY_EVALUATED via store.appendEvent()
[ ] SimOrganism.laboratory() passa o store ao LessonAnswerProgressController
[ ] processAnswerWithEngine() NÃO foi alterada (função pura preservada)
[ ] Testes de mastery criados e passando
[ ] flutter analyze: zero erros
[ ] flutter test: todos verdes (mínimo 111 + novos)
[ ] git status limpo
```

---

## FORMATO DO RELATÓRIO DA FASE 2

```
# RELATÓRIO — FASE 2 CONCLUÍDA

## 2.1 — Injeção no controller
[o que foi adicionado ao construtor]

## 2.2 — Chamada do MasteryTruthEngine em enviarSinal()
[código adicionado, linha exata]

## 2.3 — Store passado no SimOrganism
[onde e como foi conectado]

## 2.4 — Decisão sobre processAnswerWithEngine()
[confirmação de que não foi alterada + justificativa]

## 2.5 — Testes
[quais testes foram criados, quais passaram, quais foram inviáveis]

## OBSERVAÇÕES ADICIONAIS
[qualquer coisa inesperada]

## CRITÉRIO DE CONCLUSÃO
[checklist]

## PRONTO PARA FASE 3?
[sim / não — e por quê]
```

**Após entregar o relatório, aguarde. Não inicie a Fase 3 sem aprovação.**

---

*Aprovação Fase 1.5: 2026-06-26*
*Instruções Fase 2 emitidas: 2026-06-26*
*Gerente técnico: Claude*
