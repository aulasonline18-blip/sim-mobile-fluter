# REVISÃO DO GERENTE — FASE 0
## Status: APROVADA COM OBSERVAÇÕES

---

## AVALIAÇÃO DO RELATÓRIO

O relatório está correto, completo e bem estruturado. Confirmou todos os problemas identificados.
Fase 0 aprovada. Pode avançar para a Fase 1 após ler as instruções abaixo.

---

## OBSERVAÇÕES DO GERENTE SOBRE O RELATÓRIO

### Sobre 0.1 — Pontos de injeção
Confirmado. 11 arquivos injetam `StudentLearningStateService`. O mais crítico é `sim_organism.dart` linhas 112-199 — é o ponto central de bootstrapping do app. A substituição começa ali.

### Sobre 0.2 — Decisões fora do DecisionEngine
**Correção importante:** O `student_lesson_executor.dart` (linhas 147-162) NA VERDADE chama `decideNextActionFromState()` dentro de `processAnswerWithEngine()`. Li o código completo. O DecisionEngine já está no caminho principal — mas via `StudentLearningStateService` fraco, sem persistência e sem eventos canônicos. Isso muda a estratégia da Fase 3 (será mais simples do que previsto).

As linhas `main.dart:399-407` (`aulaStep += 1`) e `main.dart:376-383` (`selectedAnswer`) são código legado da `LabSession` que será removido na Fase 9. Não bloqueia nada agora.

### Sobre 0.3 — MasteryTruthEngine
Confirmado. `processAnswerWithEngine()` usa o `LearningDecisionEngine` mas não o `MasteryTruthEngine`. A tentativa é gravada, a decisão de layer/item é tomada pelo engine, mas a avaliação pedagógica real (mastered / weak / falseMastery) nunca acontece no fluxo principal.

### Sobre 0.4 — Eventos faltantes
Confirmado. `AUDIO_READY` e `IMAGE_READY` existem no serviço de mídia, mas `CURRICULUM_GENERATED`, `LESSON_TEXT_READY`, `ITEM_ADVANCED`, `ITEM_MASTERED`, `REINFORCEMENT_REQUIRED`, `WEAKNESS_REGISTERED`, `TECHNICAL_CACHE_CLEARED` nunca são disparados.

### Sobre 0.5 — Mocks
Confirmado e mapeado com precisão. Nota: `sim_laboratory_adapters.dart` é deliberadamente um adapter de laboratório — esse código mock ali é intencional e não será removido. Os mocks problemáticos são os que estão em `main.dart` no fluxo de produção.

### Sobre 0.6 — Assets
Nenhum asset faltando. Ótimo.

### Sobre 0.7 — Smoke test
**Gap identificado:** O smoke test foi inferido do código, não executado manualmente. Para esta fase de somente leitura, é aceitável. Porém, antes de iniciar a Fase 1, o smoke test real precisa ser executado no emulador/dispositivo para documentar o comportamento exato hoje. Isso vira o baseline de regressão.

### Sobre a branch `claude/quirky-fermat-tevk9i`
Essa branch não existe no repositório remoto ao qual tenho acesso — parece ser um artefato local da VM do Codex. Não bloqueia. Continue na branch `claude/app-audit-report-5a22ba`.

---

# INSTRUÇÃO PARA EXECUÇÃO — FASE 1

## OBJETIVO DA FASE 1

**Unificar os dois sistemas de estado em um único `StudentStateStore` canônico.**

Ao final desta fase:
- O `StudentStateStore` será o único store que governa o fluxo principal
- O `StudentLearningStateService` continuará existindo no código mas não será mais o governante
- O progresso do aluno será persistido localmente (não apenas em memória)
- Nenhum comportamento visível para o usuário muda

---

## PRÉ-REQUISITO OBRIGATÓRIO ANTES DE COMEÇAR

**Execute o smoke test manualmente no emulador/dispositivo e documente o comportamento real:**

```
[ ] 1. Criar aula nova → T4 interpreta → currículo gerado → primeira aula abre
[ ] 2. Responder certo com sinal 1 (fácil) na L1 → avanço para qual layer?
[ ] 3. Responder errado na L1 → o que aparece?
[ ] 4. Errar 2x no mesmo item → o que acontece?
[ ] 5. Fechar app completamente → reabrir → progresso está lá? (sim/não)
[ ] 6. Clicar no botão de áudio → o que aparece?
[ ] 7. Chegar no último item e responder corretamente → tela de conclusão aparece?
```

Documente **o que o app faz hoje**, mesmo que errado. Isso é o baseline.
Salve em `CODEX_SMOKE_BASELINE.md` na raiz do projeto.
Se qualquer item do smoke test deixar de funcionar ao longo da Fase 1, PARE imediatamente e reporte.

---

## TAREFA 1.0 — Adicionar `shared_preferences` ao `pubspec.yaml`

**ATENÇÃO:** O projeto só tem `supabase_flutter` e `cupertino_icons` como dependências.
`shared_preferences` NÃO está no `pubspec.yaml`. Precisa ser adicionado antes de tudo.

Adicionar em `pubspec.yaml` na seção `dependencies:`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  supabase_flutter: ^2.15.0
  shared_preferences: ^2.3.2    # ← ADICIONAR
```

Depois executar:
```bash
flutter pub get
```

Verificar que o pub get termina sem erros antes de continuar.

**Alternativa:** Se preferir evitar nova dependência, use `supabase_flutter` que provavelmente já usa internamente algum storage local — verificar se expõe alguma interface de storage. Porém `shared_preferences` é a opção mais direta e segura.

**Critério:** `flutter pub get` sem erros, `shared_preferences` aparece em `pubspec.lock`.

---

## TAREFA 1.1 — Criar implementação real de `StudentStateLocalStorage`

Criar arquivo: `lib/sim/state/shared_prefs_state_storage.dart`

Este arquivo implementa a interface `StudentStateLocalStorage` usando `SharedPreferences`.

```dart
import 'package:shared_preferences/shared_preferences.dart';
import 'student_state_store.dart';

class SharedPrefsStudentStateLocalStorage
    implements StudentStateLocalStorage {
  SharedPrefsStudentStateLocalStorage(this._prefs);

  final SharedPreferences _prefs;

  static const String _statePrefix = 'sim-state-v1-';
  static const String _eventsPrefix = 'sim-events-v1-';

  @override
  String? readState(String lessonLocalId) {
    return _prefs.getString('$_statePrefix$lessonLocalId');
  }

  @override
  void writeState(String lessonLocalId, String encoded) {
    _prefs.setString('$_statePrefix$lessonLocalId', encoded);
  }

  @override
  String? readEvents(String lessonLocalId) {
    return _prefs.getString('$_eventsPrefix$lessonLocalId');
  }

  @override
  void writeEvents(String lessonLocalId, String encoded) {
    _prefs.setString('$_eventsPrefix$lessonLocalId', encoded);
  }
}
```

**Critério:** Arquivo criado, compila sem erros, a interface está completamente implementada.

---

## TAREFA 1.2 — Criar `StudentStateStoreAdapter`

Criar arquivo: `lib/sim/state/student_state_store_adapter.dart`

Este adapter faz o `StudentStateStore` parecer um `StudentLearningStateService` para todos os módulos que já usam o store fraco. É o "cabo adaptador" que permite trocar o motor sem mudar as tomadas.

```dart
import 'student_learning_state.dart';
import 'student_learning_state_service.dart';
import 'student_state_store.dart';

/// Adapter que expõe StudentStateStore com a interface de StudentLearningStateService.
/// Permite migrar gradualmente os módulos sem alterar suas assinaturas.
class StudentStateStoreAdapter implements StudentLearningStateService {
  StudentStateStoreAdapter(this._store);

  final StudentStateStore _store;

  @override
  StudentLearningState? read(String lessonLocalId) {
    // readState sempre retorna um estado (cria vazio se não existir)
    // Para manter compatibilidade com o contrato nullable do ServiceFraco:
    final state = _store.readState(lessonLocalId);
    // Se o estado é literalmente vazio e recém-criado, retornar null
    // para compatibilidade com código que checa "if (state != null)"
    if (state.createdAt == state.updatedAt &&
        state.curriculum == null &&
        state.progress == null) {
      return null;
    }
    return state;
  }

  @override
  List<String> listLessonIds() {
    // StudentStateStore não tem listagem — retornar lista vazia por ora
    // Será completado na Fase 6 com índice local
    return const [];
  }

  @override
  StudentLearningState ensure({
    required String lessonLocalId,
    String? userId,
  }) {
    return _store.readState(lessonLocalId).copyWith(userId: userId);
  }

  @override
  StudentLearningState write(StudentLearningState state) {
    return _store.writeState(state);
  }

  @override
  StudentLearningState mutate(
    String lessonLocalId,
    StudentStateMutator mutator,
  ) {
    return _store.patchState(lessonLocalId, mutator);
  }

  @override
  StudentLearningState appendEvent(
    String lessonLocalId,
    StudentLearningEvent event, {
    int maxEvents = 500,
  }) {
    // Delegar ao store canônico via appendEvent
    _store.appendEvent(
      lessonLocalId: lessonLocalId,
      type: event.type,
      payload: event.payload,
      source: 'legacy-adapter',
    );
    return _store.readState(lessonLocalId);
  }

  @override
  StudentLearningState appendAttempt(
    String lessonLocalId,
    LessonAttempt attempt, {
    int maxAttempts = 300,
  }) {
    return _store.patchState(
      lessonLocalId,
      (state) => state.copyWith(
        attempts: [...state.attempts, attempt],
      ),
    );
  }
}
```

**ATENÇÃO:** Verificar a assinatura exata dos métodos em `StudentLearningStateService` antes de implementar. O adapter deve implementar `StudentLearningStateService` 100% — se a assinatura diferir, ajuste o adapter (não o service).

**Critério:** Arquivo criado, `StudentStateStoreAdapter implements StudentLearningStateService` compila sem warnings.

---

## TAREFA 1.3 — Inicializar `SharedPreferences` e `StudentStateStore` no bootstrap

Localizar o ponto de entrada do app em `main.dart` onde o app é inicializado (provavelmente `runApp` ou `main()`).

Adicionar antes do `runApp`:

```dart
// Em: main()
final prefs = await SharedPreferences.getInstance();
final stateStorage = SharedPrefsStudentStateLocalStorage(prefs);
final canonicalStore = StudentStateStore(local: stateStorage);
```

Passar `canonicalStore` para os widgets/providers que precisam dele.
Se existir um `Provider` ou `InheritedWidget` no topo da árvore, adicionar o store ali.

**Critério:** `StudentStateStore` instanciado com storage real no bootstrap, antes do primeiro frame.

---

## TAREFA 1.4 — Substituir `StudentLearningStateService` por `StudentStateStoreAdapter` no `SimOrganism`

Localizar `sim_organism.dart`, linhas 99-199.

**Passo a passo:**

1. Onde hoje é instanciado `StudentLearningStateService()`, substituir por `StudentStateStoreAdapter(canonicalStore)`.
2. O type das variáveis locais que recebem o service deve mudar para `StudentLearningStateService` (que o adapter implementa) — não para `StudentStateStoreAdapter` diretamente. Isso mantém o polimorfismo.
3. Todos os módulos que recebem o service como injeção continuam recebendo o mesmo tipo — nenhum deles precisa mudar.

Exemplo da mudança em `SimOrganism.boot()`:

```dart
// ANTES:
final stateService = StudentLearningStateService();
stateService.ensure(lessonLocalId: lessonLocalId, userId: 'lab-user');

// DEPOIS:
final stateService = StudentStateStoreAdapter(canonicalStore);
stateService.ensure(lessonLocalId: lessonLocalId, userId: 'lab-user');
```

**Critério:** `sim_organism.dart` compila. A instância de `StudentLearningStateService()` direta foi removida do organism.

---

## TAREFA 1.5 — Migrar dados existentes do formato antigo

Verificar se existem dados em SharedPreferences com as chaves antigas (do `StudentLearningStateService` anterior, se ele tinha persistência).

Buscar no projeto por `SharedPreferences` e `prefs.setString`/`prefs.getString` em outros arquivos além do que acabamos de criar — para não sobrescrever dados existentes.

Se encontrar chaves com prefixo diferente de `sim-state-v1-` que contenham estado de aluno, criar uma migração simples:

```dart
// Na inicialização, após criar o storage:
await _migrateIfNeeded(prefs, stateStorage);

Future<void> _migrateIfNeeded(
  SharedPreferences prefs,
  SharedPrefsStudentStateLocalStorage storage,
) async {
  // Listar chaves com prefixo antigo, reescrever no novo prefixo
  // Se não encontrar nada, retornar silenciosamente
}
```

Se não existir nenhuma chave antiga, documentar isso no relatório e avançar.

**Critério:** Nenhum dado de aluno existente é perdido durante a migração.

---

## TAREFA 1.6 — Executar o smoke test e comparar com o baseline

Após as tarefas 1.1 a 1.5, executar o mesmo checklist do smoke test:

```
[ ] 1. Criar aula nova → currículo gerado → primeira aula abre
[ ] 2. Responder certo sinal 1 L1 → avanço correto
[ ] 3. Responder errado L1 → comportamento correto
[ ] 4. Errar 2x → comportamento correto
[ ] 5. Fechar app → reabrir → AGORA O PROGRESSO DEVE PERSISTIR (diferença esperada)
[ ] 6. Botão de áudio → mesmo comportamento de antes
[ ] 7. Último item → conclusão aparece
```

O item 5 é onde esperamos diferença: antes o progresso era perdido ao fechar (store em memória). Agora deve persistir (store com SharedPreferences).

Se qualquer outro item mudar de comportamento em relação ao baseline, PARE e reporte antes de continuar.

**Critério:** Todos os itens do smoke test passam. Item 5 agora persiste corretamente.

---

## TAREFA 1.7 — Commitar em subtarefas

Commitar separadamente a cada subtarefa concluída:

```
git add lib/sim/state/shared_prefs_state_storage.dart
git commit -m "fase-1: add SharedPrefsStudentStateLocalStorage"

git add lib/sim/state/student_state_store_adapter.dart
git commit -m "fase-1: add StudentStateStoreAdapter bridging store to service interface"

git add lib/main.dart
git commit -m "fase-1: bootstrap StudentStateStore with SharedPrefs in main()"

git add lib/sim/organism/sim_organism.dart
git commit -m "fase-1: sim_organism uses StudentStateStoreAdapter as canonical store"
```

Não commitar tudo em um único commit gigante.

---

## CRITÉRIO DE CONCLUSÃO DA FASE 1

A Fase 1 está concluída quando **todos** os itens abaixo são verdadeiros:

```
[ ] SharedPrefsStudentStateLocalStorage criado e compilando
[ ] StudentStateStoreAdapter criado e implementando StudentLearningStateService
[ ] StudentStateStore instanciado no bootstrap com storage real
[ ] sim_organism.dart não instancia mais StudentLearningStateService() diretamente
[ ] flutter analyze retorna zero erros (warnings são aceitáveis, erros não)
[ ] Smoke test completo — todos os 7 itens passam
[ ] Item 5 do smoke test agora persiste (era a principal falha antes)
[ ] git status mostra branch limpa (nenhum arquivo modificado não commitado)
[ ] StudentLearningStateService.dart ainda existe (não foi deletado — isso é intencional)
```

**Após entregar o relatório da Fase 1, aguarde. Não inicie a Fase 2 sem aprovação explícita.**

---

## FORMATO DO RELATÓRIO DA FASE 1

```
# RELATÓRIO — FASE 1 CONCLUÍDA

## Smoke test baseline (executado antes de começar)
[resultado de cada item do checklist]

## 1.1 — SharedPrefsStudentStateLocalStorage
[arquivo criado? chaves usadas? observações]

## 1.2 — StudentStateStoreAdapter
[arquivo criado? métodos implementados? diferenças encontradas na interface?]

## 1.3 — Bootstrap
[onde foi inicializado? como foi passado para os providers?]

## 1.4 — Substituição no SimOrganism
[o que exatamente foi alterado? linhas modificadas]

## 1.5 — Migração de dados
[havia dados antigos? foi necessário migrar? chaves encontradas]

## 1.6 — Smoke test pós-fase
[resultado de cada item — comparar com baseline]

## OBSERVAÇÕES ADICIONAIS
[qualquer coisa inesperada encontrada durante a execução]

## CRITÉRIO DE CONCLUSÃO
[marcar cada item do checklist como concluído ou não]

## PRONTO PARA FASE 2?
[sim / não — e por quê]
```

---

*Aprovação Fase 0: 2026-06-26*
*Instruções Fase 1 emitidas: 2026-06-26*
*Gerente técnico: Claude*
