# REVISÃO DO GERENTE — FASE 4
## Status: APROVADA

---

## AVALIAÇÃO

Fase 4 concluída corretamente. 115 testes verdes. Código verificado.

**`StudentExperienceEngine`** — `CURRICULUM_GENERATED` disparado com payload rico (topic, totalItems, firstMarker, firstItemIndex). Correto.

**`StudentLessonMaterialService`** — `LESSON_TEXT_READY` disparado via `_appendLessonTextReady()` em dois pontos: após geração e após espera (`waitedMs` no payload para diagnóstico de performance). Boa decisão de incluir `waitedMs`.

**`LessonAnswerProgressController`** — `_appendWeaknessEventsIfNeeded()` é acionado quando `evidence.needsReinforcement == true`, disparando `WEAKNESS_REGISTERED` + `REINFORCEMENT_REQUIRED` com payload completo. Padrão consistente com `_appendCanonicalOrLegacyEvent()` estabelecido na Fase 3.

**`AUDIO_READY` e `IMAGE_READY`** — corretamente deixados para Fases 7+.

---

## ESTADO DO PROJETO APÓS FASES 1–4

```
✅ StudentStateStore com SharedPrefs é o store canônico
✅ StudentStateStoreAdapter conecta o store a todos os módulos legados
✅ MasteryTruthEngine avalia cada resposta do aluno
✅ DecisionEngine lê mastery truth para decidir progressão
✅ MASTERY_EVALUATED, NEXT_ACTION_DECIDED, ITEM_ADVANCED, ITEM_MASTERED
✅ CURRICULUM_GENERATED disparado após T00
✅ LESSON_TEXT_READY disparado após T02
✅ WEAKNESS_REGISTERED + REINFORCEMENT_REQUIRED disparados
✅ 115 testes verdes

❌ extra['truth'], extra['sync'], extra['next_action'] em JsonMap genérico (Fase 5)
❌ AUDIO_READY e IMAGE_READY pendentes (Fases 7+)
❌ Áudio e upload ainda são mocks
❌ Cloud sync não conectado ao fluxo principal
```

---

---

# INSTRUÇÃO PARA EXECUÇÃO — FASE 5

## OBJETIVO

Tipar os campos críticos de `StudentLearningState` que hoje vivem em `extra: JsonMap`. Os campos `truth` (mastery), `sync`, `visual` e `audio` devem ter classes Dart próprias. Isso elimina o acesso frágil por string-key e permite `copyWith()` e `fromJson()` tipados.

---

## ANTES DE COMEÇAR — LEITURA OBRIGATÓRIA

Ler completamente:
- `lib/sim/state/student_learning_state.dart` — ver a estrutura atual de `StudentLearningState` e todos os campos em `extra`
- `lib/sim/state/mastery_truth_engine.dart` — ver `writeTruthToState()` — o que exatamente escreve em `extra['truth']`
- `lib/sim/state/learning_decision_engine.dart` — ver `_masteryForMarker()` — o que exatamente lê de `extra['truth']`
- `lib/sim/classroom/lesson_answer_progress_controller.dart` — ver onde `extra['next_action']` é escrito e lido

**Inventariar antes de qualquer código:** quais chaves de `extra` estão em uso no projeto inteiro.

Executar:
```bash
grep -rn "extra\[" lib/ --include="*.dart" | grep -v "_test"
```

Documentar todas as chaves encontradas. Isso define o escopo da migração.

---

## TAREFA 5.1 — Criar `StudentMasteryTruth`

Criar arquivo: `lib/sim/state/student_mastery_truth.dart`

```dart
import 'student_learning_state.dart';

class StudentMasteryTruth {
  const StudentMasteryTruth({
    this.masteryEvidence = const [],
    this.falseMasteryFlags = const [],
    this.needsRetestFlags = const [],
    this.itemConsolidationStatus = const {},
  });

  final List<JsonMap> masteryEvidence;        // lista de MasteryEvidence.toJson()
  final List<String> falseMasteryFlags;        // markers com falseMastery
  final List<String> needsRetestFlags;         // markers que precisam retest
  final Map<String, String> itemConsolidationStatus;  // marker → status name

  JsonMap toJson() => {
    'mastery_evidence': masteryEvidence,
    'false_mastery_flags': falseMasteryFlags,
    'needs_retest_flags': needsRetestFlags,
    'item_consolidation_status': itemConsolidationStatus,
  };

  factory StudentMasteryTruth.fromJson(JsonMap json) => StudentMasteryTruth(
    masteryEvidence: (json['mastery_evidence'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(),
    falseMasteryFlags: (json['false_mastery_flags'] as List? ?? [])
        .whereType<String>()
        .toList(),
    needsRetestFlags: (json['needs_retest_flags'] as List? ?? [])
        .whereType<String>()
        .toList(),
    itemConsolidationStatus: (json['item_consolidation_status'] as Map? ?? {})
        .map((k, v) => MapEntry(k.toString(), v.toString())),
  );

  StudentMasteryTruth copyWith({
    List<JsonMap>? masteryEvidence,
    List<String>? falseMasteryFlags,
    List<String>? needsRetestFlags,
    Map<String, String>? itemConsolidationStatus,
  }) => StudentMasteryTruth(
    masteryEvidence: masteryEvidence ?? this.masteryEvidence,
    falseMasteryFlags: falseMasteryFlags ?? this.falseMasteryFlags,
    needsRetestFlags: needsRetestFlags ?? this.needsRetestFlags,
    itemConsolidationStatus: itemConsolidationStatus ?? this.itemConsolidationStatus,
  );
}
```

---

## TAREFA 5.2 — Criar `StudentSyncStatus`

Criar arquivo: `lib/sim/state/student_sync_status.dart`

```dart
import 'student_learning_state.dart';

enum SyncState { synced, syncing, conflict, error, neverSynced }

class StudentSyncStatus {
  const StudentSyncStatus({
    this.state = SyncState.neverSynced,
    this.localUpdatedAt,
    this.cloudUpdatedAt,
    this.lastSyncError,
    this.lastSyncAt,
  });

  final SyncState state;
  final int? localUpdatedAt;
  final int? cloudUpdatedAt;
  final String? lastSyncError;
  final int? lastSyncAt;

  JsonMap toJson() => {
    'state': state.name,
    if (localUpdatedAt != null) 'local_updated_at': localUpdatedAt,
    if (cloudUpdatedAt != null) 'cloud_updated_at': cloudUpdatedAt,
    if (lastSyncError != null) 'last_sync_error': lastSyncError,
    if (lastSyncAt != null) 'last_sync_at': lastSyncAt,
  };

  factory StudentSyncStatus.fromJson(JsonMap json) {
    final stateName = json['state']?.toString() ?? '';
    return StudentSyncStatus(
      state: SyncState.values.firstWhere(
        (e) => e.name == stateName,
        orElse: () => SyncState.neverSynced,
      ),
      localUpdatedAt: json['local_updated_at'] as int?,
      cloudUpdatedAt: json['cloud_updated_at'] as int?,
      lastSyncError: json['last_sync_error'] as String?,
      lastSyncAt: json['last_sync_at'] as int?,
    );
  }

  StudentSyncStatus copyWith({
    SyncState? state,
    int? localUpdatedAt,
    int? cloudUpdatedAt,
    String? lastSyncError,
    int? lastSyncAt,
  }) => StudentSyncStatus(
    state: state ?? this.state,
    localUpdatedAt: localUpdatedAt ?? this.localUpdatedAt,
    cloudUpdatedAt: cloudUpdatedAt ?? this.cloudUpdatedAt,
    lastSyncError: lastSyncError ?? this.lastSyncError,
    lastSyncAt: lastSyncAt ?? this.lastSyncAt,
  );
}
```

---

## TAREFA 5.3 — Adicionar `truth` e `syncStatus` ao `StudentLearningState`

**Arquivo:** `lib/sim/state/student_learning_state.dart`

Adicionar os dois novos campos ao construtor, `copyWith()`, `toJson()` e `fromJson()`:

```dart
// No construtor:
this.truth,
this.syncStatus,

// Tipos dos campos (nullable — compatibilidade com estados antigos):
final StudentMasteryTruth? truth;
final StudentSyncStatus? syncStatus;
```

Em `toJson()`:
```dart
if (truth != null) 'truth_typed': truth!.toJson(),
if (syncStatus != null) 'sync_status_typed': syncStatus!.toJson(),
```

Em `fromJson()`:
```dart
truth: json['truth_typed'] is Map
    ? StudentMasteryTruth.fromJson(Map<String, dynamic>.from(json['truth_typed'] as Map))
    : null,
syncStatus: json['sync_status_typed'] is Map
    ? StudentSyncStatus.fromJson(Map<String, dynamic>.from(json['sync_status_typed'] as Map))
    : null,
```

**IMPORTANTE:** Usar chaves diferentes (`truth_typed`, `sync_status_typed`) para os novos campos tipados, para coexistir com os campos legados `extra['truth']` e `extra['sync']` sem quebrar estados persistidos anteriormente. A migração é aditiva: os dois coexistem até a Fase 9.

---

## TAREFA 5.4 — Atualizar `MasteryTruthEngine.writeTruthToState()` para usar campo tipado

**Arquivo:** `lib/sim/state/mastery_truth_engine.dart`

Localizar `writeTruthToState()`. Hoje escreve em `state.extra['truth']`.

Após a Fase 5, deve escrever em **ambos**: no campo tipado E manter o legado em `extra` para compatibilidade:

```dart
StudentLearningState writeTruthToState(
  StudentLearningState state,
  MasteryEvidence evidence,
) {
  // Atualizar campo tipado:
  final currentTruth = state.truth ?? const StudentMasteryTruth();
  final updatedEvidence = [
    ...currentTruth.masteryEvidence
        .where((e) => e['marker_id'] != evidence.marker),
    evidence.toJson(),
  ];
  final updatedConsolidation = {
    ...currentTruth.itemConsolidationStatus,
    evidence.marker: evidence.status.name,
  };
  final updatedFalseMastery = evidence.status == MasteryStatus.falseMastery
      ? {...currentTruth.falseMasteryFlags.toSet(), evidence.marker}.toList()
      : currentTruth.falseMasteryFlags
          .where((m) => m != evidence.marker)
          .toList();
  final updatedNeedsRetest = evidence.needsReview
      ? {...currentTruth.needsRetestFlags.toSet(), evidence.marker}.toList()
      : currentTruth.needsRetestFlags
          .where((m) => m != evidence.marker)
          .toList();

  final newTruth = currentTruth.copyWith(
    masteryEvidence: updatedEvidence,
    itemConsolidationStatus: updatedConsolidation,
    falseMasteryFlags: updatedFalseMastery,
    needsRetestFlags: updatedNeedsRetest,
  );

  // Manter extra['truth'] para compatibilidade com código legado:
  return state.copyWith(
    truth: newTruth,
    extra: {...state.extra, 'truth': newTruth.toJson()},
  );
}
```

---

## TAREFA 5.5 — Atualizar `_masteryForMarker()` para preferir campo tipado

**Arquivo:** `lib/sim/state/learning_decision_engine.dart`

Atualizar `_masteryForMarker()` para ler do campo tipado quando disponível, com fallback para `extra['truth']`:

```dart
_MasteryDecisionSnapshot _masteryForMarker(
  StudentLearningState state,
  String? marker,
) {
  if (marker == null || marker.isEmpty) {
    return const _MasteryDecisionSnapshot(status: null, needsReinforcement: false);
  }

  // Preferir campo tipado (Fase 5+):
  final typedTruth = state.truth;
  if (typedTruth != null) {
    final status = typedTruth.itemConsolidationStatus[marker];
    var needsReinforcement = status == 'weak' || status == 'falseMastery';
    for (final item in typedTruth.masteryEvidence.reversed) {
      if (item['marker_id']?.toString() == marker) {
        needsReinforcement = item['needs_reinforcement'] == true;
        break;
      }
    }
    return _MasteryDecisionSnapshot(
      status: status,
      needsReinforcement: needsReinforcement,
    );
  }

  // Fallback para extra['truth'] (legado):
  final truth = state.extra['truth'];
  // ... (manter código existente do fallback)
}
```

---

## TAREFA 5.6 — NÃO criar `StudentVisualState` e `StudentAudioState` ainda

A Fase 7 (áudio) e a pipeline visual têm suas próprias interfaces hoje. Criar as classes agora sem conectar ao fluxo real cria código morto. As classes serão criadas quando as Fases 7 e 8 forem executadas, junto com a conexão real.

Documentar esta decisão no relatório.

---

## TAREFA 5.7 — Criar testes para a Fase 5

Criar arquivo: `test/fase5_typed_state_test.dart`

```dart
test('writeTruthToState escreve em campo tipado e em extra[truth]', () {
  // Criar estado vazio
  // Criar MasteryEvidence com status mastered para marker 'M1'
  // Chamar writeTruthToState()
  // Verificar state.truth?.itemConsolidationStatus['M1'] == 'mastered'
  // Verificar state.extra['truth']['item_consolidation_status']['M1'] == 'mastered'
});

test('_masteryForMarker lê de campo tipado quando disponível', () {
  // Criar estado com state.truth preenchido (via writeTruthToState)
  // Chamar decideNextActionFromState()
  // Verificar que o campo tipado foi usado (não extra)
  // (indireto: verificar que a decisão correta é tomada)
});

test('fromJson preserva compatibilidade com estado antigo sem truth_typed', () {
  // Criar JSON de estado sem 'truth_typed'
  // Desserializar com StudentLearningState.fromJson()
  // Verificar state.truth == null (sem crash)
  // Verificar state.extra ainda funciona normalmente
});
```

---

## TAREFA 5.8 — Commitar em subtarefas

```
git commit -m "fase-5: add StudentMasteryTruth and StudentSyncStatus typed classes"
git commit -m "fase-5: add truth and syncStatus typed fields to StudentLearningState"
git commit -m "fase-5: writeTruthToState writes to typed field and extra for compat"
git commit -m "fase-5: decision engine prefers typed truth field"
git commit -m "fase-5: typed state tests"
git push
```

---

## CRITÉRIO DE CONCLUSÃO DA FASE 5

```
[ ] StudentMasteryTruth criada com toJson/fromJson/copyWith
[ ] StudentSyncStatus criada com toJson/fromJson/copyWith
[ ] StudentLearningState tem campos truth e syncStatus (nullable)
[ ] toJson usa chaves truth_typed e sync_status_typed (não sobrescreve legado)
[ ] fromJson desserializa truth_typed e sync_status_typed sem quebrar estados antigos
[ ] writeTruthToState escreve em campo tipado E mantém extra['truth']
[ ] _masteryForMarker lê de campo tipado com fallback para extra['truth']
[ ] StudentVisualState e StudentAudioState documentadas como pendentes (Fases 7+)
[ ] Testes criados e passando
[ ] flutter analyze: zero erros
[ ] flutter test: todos verdes (mínimo 115 + novos)
[ ] git status limpo
```

---

## FORMATO DO RELATÓRIO DA FASE 5

```
# RELATÓRIO — FASE 5 CONCLUÍDA

## Inventário de extra[] keys encontradas
[resultado do grep — todas as chaves usadas]

## 5.1 — StudentMasteryTruth
[criada? campos? observações]

## 5.2 — StudentSyncStatus
[criada? campos? observações]

## 5.3 — Novos campos no StudentLearningState
[campos adicionados, chaves toJson/fromJson]

## 5.4 — writeTruthToState atualizado
[escreve em ambos? código da atualização]

## 5.5 — _masteryForMarker atualizado
[preferência por campo tipado implementada?]

## 5.6 — StudentVisualState e StudentAudioState
[confirmação de que ficaram para Fases 7+]

## 5.7 — Testes
[quais passaram, quais foram inviáveis]

## OBSERVAÇÕES ADICIONAIS
[qualquer coisa inesperada — especialmente se extra[] tinha chaves não mapeadas]

## CRITÉRIO DE CONCLUSÃO
[checklist]

## PRONTO PARA FASE 6?
[sim / não — e por quê]
```

**Após entregar o relatório, aguarde. Não inicie a Fase 6 sem aprovação.**

---

*Aprovação Fase 4: 2026-06-26*
*Instruções Fase 5 emitidas: 2026-06-26*
*Gerente técnico: Claude*
