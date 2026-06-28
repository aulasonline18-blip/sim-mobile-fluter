# REVISÃO DO GERENTE — FASE 1
## Status: APROVADA COM RESSALVA DOCUMENTADA

---

## AVALIAÇÃO DO RELATÓRIO

A Fase 1 está tecnicamente bem executada nos componentes que foram criados.
`flutter analyze` zero issues, `flutter test` 110 testes verdes — isso é o mínimo exigido.
Os três arquivos novos (`SharedPrefsStudentStateLocalStorage`, `StudentStateStoreAdapter`, `fase1_persistence_test.dart`) estão corretos e bem escritos.

**Fase 1 aprovada para avançar.**

---

## OBSERVAÇÕES DO GERENTE

### Sobre o que foi bem feito

**`SharedPrefsStudentStateLocalStorage`:** Correto. Interface implementada completamente, prefixos de chave versionados (`sim-state-v1-`, `sim-events-v1-`) — isso vai facilitar migrações futuras.

**`StudentStateStoreAdapter`:** Correto. O detalhe de `_isCompatiblyEmpty()` para manter compatibilidade com código que checa `if (state != null)` foi a decisão certa. O `listLessonIds()` retornando lista vazia é aceitável para esta fase — será completado na Fase 6.

**Teste de persistência:** O teste `fase1_persistence_test.dart` prova exatamente o que importa: criar store, salvar estado, criar novo store com as mesmas SharedPrefs, verificar que dados persistiram. É o teste correto para esta fase.

**Compatibilidade de testes antigos (`06cae5f`):** Manter `SimMobileApp` aceitando store em memória para os testes foi a decisão certa. Não quebrar testes antigos é regra.

---

### Ressalva — O `canonicalStore` não chega ao fluxo de aula real

Após ler o código completo, identifiquei uma lacuna importante que precisa ser documentada:

**O que acontece hoje:**

```
main() → canonicalStore → SimMobileApp → LabSession.canonicalStore
                                               ↓
                                         (armazenado mas...)
                                         AulaLabScreen usa session.aulaStep
                                         (interface de laboratório, não usa organism)
```

**O que deveria acontecer:**

```
main() → canonicalStore → SimMobileApp → LabSession → SimOrganism.boot(canonicalStore)
                                                             ↓
                                                       StudentStateStoreAdapter
                                                             ↓
                                                       fluxo real de aula
```

`AulaLabScreen` (`main.dart:2290`) ainda renderiza `session.aulaStep` — é a tela de laboratório, não o fluxo de aula real com `SimLiveParity`/`SimOrganism`. O `SimOrganism.boot()` aceita `canonicalStore` (confirmado em `sim_organism.dart:102-108`) mas a tela que o usuário vê na rota `/cyber/aula` não chama `SimOrganism.boot()` com o `canonicalStore` da `LabSession`.

**Impacto prático:** O `canonicalStore` com SharedPreferences está no caminho certo (main → LabSession), mas o fluxo de aula real (`SimLiveParity` → `SimOrganism`) ainda não recebe o `canonicalStore`. O teste de persistência automatizado passa porque testa o store diretamente — mas na prática de uso real, não está conectado end-to-end.

**Isso é esperado para a Fase 1?** Sim — a Fase 1 foi definida como "unificar os stores", não "conectar o fluxo de aula ao store". A conexão completa ao fluxo de aula acontece quando `SimLiveParity` for o roteador real (atualmente é `AulaLabScreen` com `session.aulaStep` que governa).

Portanto: a Fase 1 entregou o que foi pedido. A ressalva fica documentada para a Fase 2 e além.

---

### Sobre o smoke test sem emulador

O baseline inferido do código é aceitável para continuar. O smoke manual no Android ficará pendente até haver emulador disponível. Não bloqueia as próximas fases, mas precisa acontecer antes da Fase 6 (sincronização).

---

## CORREÇÃO DE ROTA — ORDEM DAS FASES

Após a análise da Fase 1, a ordem de execução foi ajustada:

**A Fase 2 (MasteryTruthEngine) e a Fase 3 (DecisionEngine) dependem do fluxo de aula real estar conectado ao store canônico.** Como o fluxo de aula real usa `SimLiveParity` → `SimOrganism` (não o `AulaLabScreen` de laboratório), as próximas fases precisam trabalhar nesse caminho correto.

**Nova ordem:**

```
Fase 1 ✅ CONCLUÍDA — Store canônico com SharedPrefs criado
Fase 1.5 (NOVA) — Conectar LabSession.canonicalStore ao SimOrganism no fluxo real
Fase 2 — Conectar MasteryTruthEngine ao fluxo de resposta
Fase 3 — Completar DecisionEngine
(... restante igual ao briefing original)
```

---

---

# INSTRUÇÃO PARA EXECUÇÃO — FASE 1.5

## OBJETIVO

Garantir que quando o app abre uma aula real, o `canonicalStore` com SharedPreferences chegue ao `SimOrganism.boot()` — completando a cadeia que a Fase 1 iniciou.

---

## CONTEXTO

`LabSession` armazena `canonicalStore`. Quando o aluno chega à rota `/cyber/aula`, o app renderiza `AulaLabScreen` — que é a tela de laboratório com `session.aulaStep`.

O fluxo real de aula é governado pelo `SimLiveParity` widget (em `lib/sim/organism/sim_live_parity.dart`), que instancia o `SimOrganism` via `SimOrganism.boot()`. Esse `boot()` já aceita `canonicalStore` como parâmetro opcional desde a Fase 1.

O que falta: verificar se existe algum ponto no código atual onde `SimLiveParity` é criado e, se sim, garantir que `LabSession.canonicalStore` seja passado para ele.

---

## TAREFA 1.5.1 — Mapear onde SimLiveParity é instanciado

Executar:
```bash
grep -rn "SimLiveParity(" lib/ --include="*.dart"
```

**Cenário A — SimLiveParity é instanciado em algum lugar:**
Verificar se o `canonicalStore` da `LabSession` está sendo passado para o `SimOrganism.boot()` nesse ponto.
Se não estiver: adicionar o parâmetro.

**Cenário B — SimLiveParity não é instanciado em lugar nenhum fora de laboratório:**
Documentar isso. Significa que o fluxo real de aula ainda não está conectado à interface principal. Não é um problema da Fase 1.5 — é contexto para as fases futuras. Reportar ao gerente.

---

## TAREFA 1.5.2 — Verificar a assinatura de SimOrganism.boot()

Ler `lib/sim/organism/sim_organism.dart` e confirmar:

```dart
static Future<SimOrganism> boot({
  required String lessonLocalId,
  // ...
  StudentStateStore? canonicalStore,  // ← este parâmetro existe?
}) async {
  final StudentLearningStateService stateService = StudentStateStoreAdapter(
    canonicalStore ?? StudentStateStore(local: MemoryStudentStateLocalStorage()),
  );
  // ...
}
```

Se o parâmetro existir e o adapter já for criado corretamente — confirmar no relatório.

---

## TAREFA 1.5.3 — Se SimLiveParity for instanciado, passar o canonicalStore

Localizar onde `SimLiveParity` é criado. Verificar se recebe o organismo diretamente ou se chama `SimOrganism.boot()` internamente.

Buscar também por qualquer outro lugar onde `SimOrganism.boot()` é chamado:
```bash
grep -rn "SimOrganism.boot\|SimOrganism\.boot" lib/ --include="*.dart"
```

Para cada chamada encontrada: verificar se `canonicalStore` está sendo passado.

Se não estiver: adicionar.

Exemplo da mudança esperada:
```dart
// ANTES:
final organism = await SimOrganism.boot(lessonLocalId: id, ...);

// DEPOIS:
final organism = await SimOrganism.boot(
  lessonLocalId: id,
  canonicalStore: session.canonicalStore,  // ← ADICIONAR
  ...
);
```

---

## TAREFA 1.5.4 — Adicionar teste verificando que o store chega ao organism

Criar (ou expandir) um teste que prove a cadeia completa:

```dart
test('SimOrganism.boot usa canonicalStore quando fornecido', () async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final canonicalStore = StudentStateStore(
    local: SharedPrefsStudentStateLocalStorage(prefs),
  );

  // Salvar algum estado no canonicalStore
  canonicalStore.writeState(
    StudentLearningState.empty(lessonLocalId: 'test-lesson', userId: 'u1'),
  );

  // Boot do organism com esse store
  final organism = await SimOrganism.boot(
    lessonLocalId: 'test-lesson',
    canonicalStore: canonicalStore,
    // ... outros parâmetros mínimos necessários
  );

  // Verificar que o estado salvo é visível para o organism
  final state = organism.stateService.read('test-lesson');
  expect(state?.userId, 'u1');
});
```

Se `SimOrganism.boot()` requer muitos parâmetros obrigatórios que tornam o teste impraticável, documentar isso e pular o teste — não é bloqueador para esta fase.

---

## TAREFA 1.5.5 — Commitar

```
git add lib/sim/organism/sim_organism.dart [e qualquer outro arquivo modificado]
git commit -m "fase-1.5: pass canonicalStore to SimOrganism.boot in all call sites"
git push
```

---

## CRITÉRIO DE CONCLUSÃO DA FASE 1.5

```
[ ] Resultado de grep SimLiveParity documentado
[ ] Resultado de grep SimOrganism.boot documentado
[ ] Para cada call site encontrado: canonicalStore está sendo passado
[ ] flutter analyze: zero erros
[ ] flutter test: todos verdes
[ ] Se nenhum call site foi encontrado: isso foi documentado e entendido
```

---

## FORMATO DO RELATÓRIO DA FASE 1.5

```
# RELATÓRIO — FASE 1.5 CONCLUÍDA

## 1.5.1 — SimLiveParity call sites
[resultado do grep]

## 1.5.2 — Assinatura de SimOrganism.boot()
[confirmação do parâmetro canonicalStore]

## 1.5.3 — SimOrganism.boot() call sites e canonicalStore
[lista dos pontos encontrados + o que foi alterado]

## 1.5.4 — Teste
[teste criado? passou? ou foi inviável — por quê]

## OBSERVAÇÕES ADICIONAIS
[qualquer coisa inesperada]

## CRITÉRIO DE CONCLUSÃO
[checklist]

## PRONTO PARA FASE 2?
[sim / não — e por quê]
```

**Após entregar o relatório da Fase 1.5, aguarde. Não inicie a Fase 2 sem aprovação.**

---

*Aprovação Fase 1: 2026-06-26*
*Instruções Fase 1.5 emitidas: 2026-06-26*
*Gerente técnico: Claude*
