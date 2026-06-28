# REVISÃO DO GERENTE — FASE 5
## Status: APROVADA

---

## AVALIAÇÃO

Fase 5 concluída corretamente. 117 testes verdes. Código verificado.

**`StudentMasteryTruth`** — implementada em `student_learning_state.dart` com `fromJson`, `fromLegacy`, `copyWith`, `empty`. A factory `fromLegacy()` é um detalhe particularmente bom: permite migrar estados antigos que só têm `extra['truth']` sem perder dados nem crashar.

**`StudentSyncStatus`** — implementada com `fromJson`, `copyWith`, `empty`. Enum `SyncState` próprio.

**`truth` não-nullable** — melhor que a spec original propunha (nullable). Todo `StudentLearningState` tem `truth: const StudentMasteryTruth.empty()` desde a criação. Elimina null-checks desnecessários em todos os leitores.

**Coexistência legado/tipado** — correto. `toJson()` usa `truth_typed` (não sobrescreve `extra['truth']`). `fromJson()` lê `truth_typed` com fallback `fromLegacy(json['truth'])`. A decisão certa.

**`_masteryForMarker()`** — lê `state.truth.itemConsolidationStatus[marker]` diretamente (O(1)). Só cai no fallback `extra['truth']` se `typedStatus == null`. Caminho principal sem boxing/casting.

**`writeTruthToState()`** — escreve no campo tipado (`state.truth.copyWith(...)`) e mantém `extra['truth']` para compatibilidade. Dupla escrita correta.

**`StudentVisualState` e `StudentAudioState`** — corretamente deixadas para Fases 7 e 8.

---

## ESTADO DO PROJETO APÓS FASES 1–5

```
✅ StudentStateStore com SharedPrefs é o store canônico
✅ MasteryTruthEngine avalia cada resposta — escrita tipada em state.truth
✅ DecisionEngine lê state.truth (tipado) para decisão de progressão
✅ Todos os eventos canônicos críticos disparados (Fases 3+4)
✅ StudentMasteryTruth e StudentSyncStatus como campos tipados
✅ Migração transparente de estados antigos via fromLegacy()
✅ 117 testes verdes

❌ StudentVisualState e StudentAudioState pendentes (Fases 7+)
❌ Cloud sync não conectado ao fluxo principal (Fase 6)
❌ Áudio e upload ainda são mocks (Fases 7+8)
❌ LabSession ainda é God Object (Fase 9)
```

---

---

# INSTRUÇÃO PARA EXECUÇÃO — FASE 6

## OBJETIVO

Conectar a sincronização real (Supabase) ao fluxo principal. Hoje o `StudentStateStore` tem toda a infraestrutura de sync (`hydrateFromCloud`, `persistCloud`, `syncState`, High Water Mark), mas o fluxo principal da aula não chama esses métodos. O progresso do aluno só sobe para a nuvem manualmente ou nunca.

---

## ANTES DE COMEÇAR — LEITURA OBRIGATÓRIA

Ler completamente:
- `lib/sim/state/student_state_store.dart` — métodos `hydrateFromCloud()`, `persistCloud()`, `syncState()`, `highWaterMark()`
- `lib/sim/cloud/student_learning_sync.dart` — como sync é feito hoje
- `lib/sim/cloud/lesson_cloud_bootstrap.dart` — como bootstrap de cloud funciona
- `lib/sim/organism/sim_organism.dart` — onde o organism é inicializado (método `laboratory()`)
- `lib/main.dart` — buscar onde `LabSession` abre uma aula (rota `/cyber/aula`) — ver onde o organism é construído

**Pergunta crítica antes de qualquer código:** O `StudentStateStore` já tem `StudentStateCloudStorage` conectado hoje? Executar:
```bash
grep -rn "StudentStateCloudStorage\|cloudStorage\|hydrateFromCloud\|persistCloud" lib/ --include="*.dart"
```
Documentar todos os resultados antes de qualquer mudança.

---

## TAREFA 6.1 — Criar `SupabaseStudentStateCloudStorage`

**Arquivo:** `lib/sim/state/supabase_student_state_storage.dart`

Implementar `StudentStateCloudStorage` usando o cliente Supabase já disponível no projeto:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'student_learning_state.dart';
import 'student_state_store.dart';

class SupabaseStudentStateCloudStorage implements StudentStateCloudStorage {
  const SupabaseStudentStateCloudStorage(this._client);

  final SupabaseClient _client;
  static const String _table = 'student_learning_states';

  @override
  Future<StudentLearningState?> loadCloud(String lessonLocalId) async {
    try {
      final row = await _client
          .from(_table)
          .select()
          .eq('lesson_local_id', lessonLocalId)
          .maybeSingle();
      if (row == null) return null;
      final stateJson = row['state'];
      if (stateJson is! Map) return null;
      return StudentLearningState.fromJson(JsonMap.from(stateJson));
    } catch (_) {
      return null;  // falha de rede não bloqueia app
    }
  }

  @override
  Future<void> persistCloud(StudentLearningState state, int hwm) async {
    try {
      await _client.from(_table).upsert({
        'lesson_local_id': state.lessonLocalId,
        'user_id': state.userId,
        'state': state.toJson(),
        'high_water_mark': hwm,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // falha de rede não crashar o app — logar silenciosamente
    }
  }
}
```

**ATENÇÃO:** Verificar a assinatura exata de `StudentStateCloudStorage` antes de implementar. Se `persistCloud()` recebe apenas `StudentLearningState` (sem `hwm`), adaptar. Não inventar assinatura — ler a interface real primeiro.

**ATENÇÃO 2:** Verificar se a tabela `student_learning_states` já existe no Supabase do projeto. Buscar em `lib/` por migrations ou schema SQL:
```bash
find /home/user/sim-mobile-fluter -name "*.sql" 2>/dev/null
grep -rn "student_learning_states\|create table" lib/ --include="*.dart"
```
Se a tabela não existir, documentar no relatório — a Fase 6 pode ser concluída com `SupabaseStudentStateCloudStorage` implementada mas com nota de que a tabela precisa ser criada no banco antes de usar.

---

## TAREFA 6.2 — Conectar `SupabaseStudentStateCloudStorage` ao `StudentStateStore` no bootstrap

**Arquivo:** `lib/main.dart`

No bootstrap (onde `canonicalStore` é criado), adicionar o cloud storage:

```dart
// ANTES (Fase 1):
final canonicalStore = StudentStateStore(local: stateStorage);

// DEPOIS (Fase 6):
final supabaseClient = Supabase.instance.client;
final cloudStorage = SupabaseStudentStateCloudStorage(supabaseClient);
final canonicalStore = StudentStateStore(
  local: stateStorage,
  cloud: cloudStorage,  // ← ADICIONAR
);
```

Verificar se `StudentStateStore` aceita `cloud` como parâmetro opcional. Se não aceitar, verificar como `StudentStateCloudStorage` é injetado — pode ser via outro mecanismo.

---

## TAREFA 6.3 — Chamar `hydrateFromCloud()` na abertura de sessão

**Arquivo:** `lib/sim/organism/sim_organism.dart`

Em `SimOrganism.laboratory()`, após criar o `activeStore`, adicionar hydration da nuvem de forma assíncrona e não-bloqueante:

```dart
static SimOrganism laboratory({
  String lessonLocalId = 'lab-live-entry',
  StudentStateStore? canonicalStore,
}) {
  final activeStore = canonicalStore ?? StudentStateStore(...);
  final stateService = StudentStateStoreAdapter(activeStore);
  stateService.ensure(lessonLocalId: lessonLocalId, userId: 'lab-user');

  // Hidratar da nuvem de forma assíncrona (não bloqueia a abertura da aula):
  activeStore.hydrateFromCloud(lessonLocalId).ignore();

  // ... resto do factory
}
```

`hydrateFromCloud()` já implementa o High Water Mark internamente — se a nuvem tem estado mais avançado, substitui o local; se o local é mais avançado, mantém o local.

**IMPORTANTE:** `ignore()` é intencional — não await. A aula abre imediatamente com o estado local. Se a nuvem tiver algo mais novo, o estado é atualizado em background e os listeners do `ChangeNotifier` notificam a UI.

---

## TAREFA 6.4 — Disparar `persistCloud()` após eventos de progresso

**Arquivo:** `lib/sim/classroom/lesson_answer_progress_controller.dart`

Em `_applyPostMasteryDecision()`, quando `ITEM_ADVANCED` ou `ITEM_MASTERED` são disparados, fazer sync para nuvem:

```dart
// Após disparar ITEM_ADVANCED ou ITEM_MASTERED:
final activeStore = store;
if (activeStore != null &&
    (decision.actionType == DecisionActionType.advanceItem ||
     evidence.status == MasteryStatus.mastered)) {
  activeStore.persistCloud(lessonLocalId).ignore();
}
```

E ao final de uma sessão (quando `FINAL_COMPLETION_ALLOWED` é disparado em `avancar()`):
```dart
store?.persistCloud(lessonLocalId).ignore();
```

---

## TAREFA 6.5 — NÃO implementar interface de "conflito visível"

Se `syncState()` detectar conflito (estado local vs. nuvem com HWM diferente), o `StudentStateStore` já resolve automaticamente pelo High Water Mark. Não é necessário mostrar UI de conflito nesta fase. Documentar no relatório.

---

## TAREFA 6.6 — Criar testes para a Fase 6

Criar arquivo: `test/fase6_cloud_sync_test.dart`

**Teste 1 — persistCloud é chamado em memória (sem Supabase real):**
Criar `MockCloudStorage` que implementa `StudentStateCloudStorage` e registra chamadas. Criar store com mock. Simular `ITEM_ADVANCED`. Verificar que `persistCloud` foi chamado.

**Teste 2 — hydrateFromCloud usa High Water Mark:**
Criar store com estado local (hwm=100). Mock de cloud retorna estado com hwm=200. Chamar `hydrateFromCloud()`. Verificar que estado local foi substituído pelo cloud.

**Teste 3 — hydrateFromCloud não sobrescreve local mais avançado:**
Estado local com hwm=300. Cloud com hwm=200. Chamar `hydrateFromCloud()`. Verificar que estado local foi mantido.

Esses testes não precisam de Supabase real — usar mocks em memória.

---

## TAREFA 6.7 — Commitar em subtarefas

```
git commit -m "fase-6: implement SupabaseStudentStateCloudStorage"
git commit -m "fase-6: connect cloud storage to canonical store in bootstrap"
git commit -m "fase-6: hydrate from cloud on session open in SimOrganism"
git commit -m "fase-6: persist to cloud after ITEM_ADVANCED and session end"
git commit -m "fase-6: cloud sync tests with in-memory mocks"
git push
```

---

## CRITÉRIO DE CONCLUSÃO DA FASE 6

```
[ ] SupabaseStudentStateCloudStorage implementa StudentStateCloudStorage
[ ] Cloud storage conectado ao StudentStateStore no bootstrap
[ ] hydrateFromCloud() chamado na abertura de sessão (assíncrono, não-bloqueante)
[ ] persistCloud() chamado após ITEM_ADVANCED e ao final da sessão
[ ] High Water Mark resolve conflito automaticamente (sem UI de conflito)
[ ] Testes com mock passando (sem Supabase real necessário)
[ ] flutter analyze: zero erros
[ ] flutter test: todos verdes (mínimo 117 + novos)
[ ] Se tabela SQL não existir: documentado no relatório (não bloqueia fase)
[ ] git status limpo
```

---

## FORMATO DO RELATÓRIO DA FASE 6

```
# RELATÓRIO — FASE 6 CONCLUÍDA

## Inventário inicial
[resultado do grep de hydrateFromCloud/persistCloud/StudentStateCloudStorage]
[tabela SQL existe? onde foi encontrada?]

## 6.1 — SupabaseStudentStateCloudStorage
[arquivo criado? assinatura real de StudentStateCloudStorage? diferenças encontradas]

## 6.2 — Bootstrap
[como cloud foi conectado ao store — parâmetro, campo, outro mecanismo]

## 6.3 — hydrateFromCloud na abertura
[onde foi adicionado, como é assíncrono/não-bloqueante]

## 6.4 — persistCloud após progresso
[quais eventos disparam o sync]

## 6.5 — Conflito
[confirmação de que High Water Mark resolve automaticamente]

## 6.6 — Testes
[quais passaram, mock usado]

## OBSERVAÇÕES ADICIONAIS
[qualquer coisa inesperada no StudentStateStore ou cloud infra]

## CRITÉRIO DE CONCLUSÃO
[checklist]

## PRONTO PARA FASE 7?
[sim / não — e por quê]
```

**Após entregar o relatório, aguarde. Não inicie a Fase 7 sem aprovação.**

---

*Aprovação Fase 5: 2026-06-26*
*Instruções Fase 6 emitidas: 2026-06-26*
*Gerente técnico: Claude*
