# INSTRUÇÃO DE EXECUÇÃO — FASE 10
## Para o executor Codex: leia este arquivo, execute, reporte.

---

## CONTEXTO RÁPIDO

Você está no projeto Flutter `sim-mobile-fluter`, branch `claude/app-audit-report-5a22ba`.

Fases 1–9 foram concluídas. 124 testes verdes.

**Sua tarefa agora é a Fase 10: eliminar force unwraps críticos e proteger pontos de falha silenciosa.**

Esta fase **não muda comportamento** — só torna o código mais resiliente. Risco baixo.

---

## PONTO DE PARTIDA OBRIGATÓRIO

Antes de qualquer mudança, rode:

```bash
flutter test
```

Confirme que os 124 testes passam. Se não passarem, pare e reporte.

Depois, rode o inventário e documente o resultado no relatório:

```bash
grep -rn "[^?]!\." lib/ --include="*.dart" | grep -v "_test\|^\s*//" | head -40
grep -rn "jsonDecode\|json\.decode" lib/ --include="*.dart" | grep -v "_test"
grep -rn "HttpClient()" lib/ --include="*.dart" | grep -v "_test"
```

---

## SUBTAREFA 10.1 — Corrigir force unwraps em arquivos de produção

Para **cada** force unwrap crítico encontrado, aplique a correção mínima e **commite o arquivo individualmente**.

Correções esperadas (verifique se ainda existem — fases anteriores podem ter movido código):

### `lib/sim/experience/student_experience_placement_adapter.dart`
```dart
// ANTES (exemplo):
final marker = placement.startMarker!.trim();

// DEPOIS:
final marker = placement.startMarker?.trim() ?? '';
```

### `lib/sim/lesson/partial_curriculum_writer.dart`
Qualquer `raw.marker!` ou similar — adicionar null check antes de usar:
```dart
// ANTES:
final marker = raw.marker!;

// DEPOIS:
final marker = raw.marker;
if (marker == null) continue; // ou return, dependendo do contexto
```

### `lib/sim/ui/doubt_input_sheet.dart` (ou nome similar)
```dart
// ANTES:
final url = image!;

// DEPOIS:
final image = ...; // referência ao valor nullable
if (image == null) return imageOnlyMessage;
final url = image;
```

### `lib/sim/state/student_state_store.dart`
Qualquer `_eventLog[lessonLocalId]!` — substituir por:
```dart
// ANTES:
_eventLog[lessonLocalId]!.add(event);

// DEPOIS:
(_eventLog[lessonLocalId] ??= []).add(event);
// ou:
_eventLog.putIfAbsent(lessonLocalId, () => []).add(event);
```

### `lib/main.dart`
Qualquer `a.extractedText!`:
```dart
// ANTES:
a.extractedText!.trim()

// DEPOIS:
a.extractedText?.trim() ?? ''
```

### `lib/sim/classroom/placement_route_controller.dart`
Verificar em torno da linha 109. Aplicar null check explícito.

**Regra:** corrija **um arquivo por vez**, rode `flutter test` após cada arquivo. Se quebrar, reverta só aquele arquivo e documente.

**Commit por arquivo:**
```
git commit -m "fase-10: fix force unwrap in <nome-do-arquivo>"
```

---

## SUBTAREFA 10.2 — Proteger jsonDecode em `student_state_store.dart`

Localizar o `jsonDecode` (ou `json.decode`) sem try-catch no `student_state_store.dart`.

Substituir por:

```dart
dynamic decoded;
try {
  decoded = jsonDecode(encoded);
} on FormatException {
  return StudentLearningState.empty(lessonLocalId: lessonLocalId);
}
```

Se houver mais de um `jsonDecode` no arquivo, proteger todos.

**Verificar:** `flutter analyze` + `flutter test` passam.

**Commitar:**
```
git commit -m "fase-10: protect jsonDecode against corrupt state in student_state_store"
```

---

## SUBTAREFA 10.3 — Verificar HttpClient

Executar:
```bash
grep -rn "HttpClient()" lib/ --include="*.dart" | grep -v "_test"
```

Se encontrar um `HttpClient` criado sem `dispose()` ou `close()`, adicionar:

```dart
void dispose() {
  _client.close(force: true);
}
```

Se o arquivo já tem `dispose()` ou `close()`, documente que já está correto.

Se não encontrar nenhum `HttpClient()`, documente "não encontrado — não aplicável".

**Commitar apenas se houver mudança:**
```
git commit -m "fase-10: close HttpClient on dispose"
```

---

## SUBTAREFA 10.4 — Tratar TimeoutException nas chamadas de cloud

Localizar o arquivo que faz chamadas HTTP para o servidor (provavelmente `sim_server_cloud_functions.dart` ou similar):

```bash
grep -rn "TimeoutException\|timeout" lib/ --include="*.dart" | grep -v "_test"
```

Se as chamadas de API não têm `catch` para `TimeoutException`, adicionar:

```dart
} on TimeoutException {
  throw SimCloudStorageException('Tempo limite da requisição atingido.');
}
// ou, se não existe essa exception, usar uma genérica:
} on TimeoutException catch (e) {
  throw Exception('Timeout: ${e.message}');
}
```

Se já está tratado, documente "já tratado".

**Commitar apenas se houver mudança:**
```
git commit -m "fase-10: handle TimeoutException in cloud functions"
```

---

## PUSH FINAL

```bash
git push -u origin claude/app-audit-report-5a22ba
```

---

## CRITÉRIO DE ABORT

Se `flutter test` quebrar após qualquer correção e a causa não for óbvia em menos de 30 minutos, faça `git revert` do commit problemático e documente no relatório. Não tente consertar na força.

---

## O QUE ENTREGAR

Um relatório de texto com:

1. **Inventário inicial** — resultado dos greps: quantos `!`, onde estão, quais foram corrigidos
2. **10.1 — Force unwraps** — lista de cada arquivo, linha, correção aplicada (ou "não encontrado/já corrigido")
3. **10.2 — jsonDecode** — onde estava, o que mudou
4. **10.3 — HttpClient** — encontrado? onde? o que foi feito
5. **10.4 — TimeoutException** — encontrado? onde? o que foi feito
6. **Checklist de conclusão:**

```
[ ] Force unwraps críticos corrigidos (ou justificados os que ficaram)
[ ] jsonDecode protegido contra FormatException
[ ] HttpClient verificado
[ ] TimeoutException verificada
[ ] flutter analyze: zero erros
[ ] flutter test: todos verdes (mínimo 124)
[ ] git push feito
```

---

**Após entregar o relatório, aguarde aprovação. Não inicie outra fase.**

---

*Instrução Fase 10 emitida: 2026-06-26*
*Gerente técnico: Claude*
