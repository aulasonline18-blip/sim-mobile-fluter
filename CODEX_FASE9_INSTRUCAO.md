# INSTRUÇÃO DE EXECUÇÃO — FASE 9
## Para o executor Codex: leia este arquivo, execute, reporte.

---

## CONTEXTO RÁPIDO

Você está no projeto Flutter `sim-mobile-fluter`, branch `claude/app-audit-report-5a22ba`.

Fases 1–8 foram concluídas. O código está limpo: 120 testes verdes, zero `LABORATORY MOCK` em `lib/`.

**Sua tarefa agora é a Fase 9: decompor `LabSession` em 4 `ChangeNotifier` separados.**

---

## PONTO DE PARTIDA OBRIGATÓRIO

Antes de qualquer mudança, rode:

```bash
flutter test
```

Confirme que os 120 testes passam. Se não passarem, pare e reporte.

---

## O QUE É A `LabSession`

`LabSession extends ChangeNotifier` vive em `lib/main.dart`. Ela tem 35+ propriedades misturando autenticação, navegação, formulário de entrada e estado de UI de aula. Isso é um God Object — difícil de manter, causa de bugs de estado.

**Regra absoluta desta fase:** migrar um provider por vez. Nunca deletar da `LabSession` antes de o novo provider estar no ar e os testes passando.

---

## SUBTAREFA 9.1 — Criar `EntryFormState`

**Arquivo novo:** `lib/session/entry_form_state.dart`

Mova para este arquivo as seguintes propriedades da `LabSession`:

```
freeText, preferredName, otherLanguage, selectedLanguageCode,
stableLang, allowPaidImages, attachments, attachmentsText,
studentProfileNotes, attachmentError
```

E os seguintes métodos:
```
updateFreeText(), updateLanguage(), addLabAttachment(),
removeAttachment(), clearAttachments()
```

Estrutura mínima:

```dart
import 'package:flutter/foundation.dart';

class EntryFormState extends ChangeNotifier {
  String freeText = '';
  String preferredName = '';
  String otherLanguage = '';
  String? selectedLanguageCode;
  String? stableLang;
  bool allowPaidImages = false;
  List<AttachmentDraft> attachments = [];
  String attachmentsText = '';
  String studentProfileNotes = '';
  String? attachmentError;

  // mover métodos relacionados para cá
}
```

**Após criar o arquivo:**
1. Adicionar `EntryFormState` ao `MultiProvider` em `main.dart` (não remover da `LabSession` ainda)
2. Rodar `flutter analyze` — zero erros
3. Rodar `flutter test` — todos os 120+ testes devem passar

**Só após os testes passarem:** substituir os widgets que leem `session.freeText`, `session.attachments` etc. por `context.watch<EntryFormState>()`. Depois remover as propriedades da `LabSession`.

**Commitar:**
```
git commit -m "fase-9: extract EntryFormState from LabSession"
```

---

## SUBTAREFA 9.2 — Criar `AuthSession`

**Arquivo novo:** `lib/session/auth_session.dart`

Mova para este arquivo:

```
authed, authReady, userId, userEmail, userName, authError, credits
```

E os métodos de autenticação (signin, signout, applySupabaseSession, bindRealAuth).

Adicionar ao `MultiProvider`. Migrar widgets. Remover da `LabSession`.

**Verificar:** `flutter analyze` + `flutter test` passam.

**Commitar:**
```
git commit -m "fase-9: extract AuthSession from LabSession"
```

---

## SUBTAREFA 9.3 — Criar `NavigationState`

**Arquivo novo:** `lib/session/navigation_state.dart`

Mova para este arquivo:

```
route, returnTo, externalDoorOpened
```

E os métodos de navegação (goPortal, goLogin, goAula, etc.).

Nota: `lessonLocalId` pode ficar no `NavigationState` OU no `LessonUiState` — decida com base em quem o usa mais. Documente a decisão no relatório.

Adicionar ao `MultiProvider`. Migrar widgets. Remover da `LabSession`.

**Verificar:** `flutter analyze` + `flutter test` passam.

**Commitar:**
```
git commit -m "fase-9: extract NavigationState from LabSession"
```

---

## SUBTAREFA 9.4 — Criar `LessonUiState`

**Arquivo novo:** `lib/session/lesson_ui_state.dart`

Mova para este arquivo:

```
entryStatus, entryError, placementStarted, placementDone,
aulaStep, selectedAnswer, aulaMessage, doubtOpen,
audioEnabled, audioPlaying, audioLoading, audioError,
imageStatus, imageError, deleteConfirmation, accountDeletionMessage
```

Atenção especial: `aulaStep`, `selectedAnswer`, `aulaMessage` são campos do fluxo legado. Se o `SimOrganism`/`SimLiveParity` já governa o fluxo real, esses campos podem estar mortos. **Não delete ainda** — mova para `LessonUiState` e documente no relatório se estão sendo usados ou são legado morto.

Adicionar ao `MultiProvider`. Migrar widgets. Remover da `LabSession`.

**Verificar:** `flutter analyze` + `flutter test` passam.

**Commitar:**
```
git commit -m "fase-9: extract LessonUiState from LabSession"
```

---

## SUBTAREFA 9.5 — Avaliar e limpar a `LabSession`

Após as 4 subtarefas, abra a `LabSession` e veja o que sobrou.

**Se sobrou pouco (só `canonicalStore`, `SimOrganism`, e métodos de coordenação):** delete a classe e ajuste o `MultiProvider`.

**Se ainda sobrou código significativo:** não delete. Documente o que ficou e por quê no relatório.

**Commitar o que foi feito:**
```
git commit -m "fase-9: remove LabSession (or document what remains)"
```

---

## SUBTAREFA 9.6 — Criar testes

**Arquivo:** `test/fase9_session_test.dart`

Teste mínimo 1 — `EntryFormState` notifica listeners:
```dart
test('EntryFormState notifica ao mudar freeText', () {
  final form = EntryFormState();
  bool notified = false;
  form.addListener(() => notified = true);
  form.freeText = 'teste';
  form.notifyListeners();
  expect(notified, isTrue);
});
```

Teste mínimo 2 — `AuthSession` começa deslogado:
```dart
test('AuthSession começa com authed=false', () {
  final auth = AuthSession();
  expect(auth.authed, isFalse);
});
```

Teste 3 — regressão: os 120 testes anteriores continuam verdes.

**Commitar:**
```
git commit -m "fase-9: session decomposition tests"
```

---

## PUSH FINAL

```bash
git push -u origin claude/app-audit-report-5a22ba
```

---

## CRITÉRIO DE ABORT

Se em qualquer subtarefa `flutter test` quebrar testes que antes passavam e a correção não for imediata (menos de 30 minutos), **faça `git revert` ao commit anterior e reporte**. Não tente consertar na força.

---

## O QUE ENTREGAR

Um relatório de texto com:

1. **Mapeamento inicial** — quantas propriedades/métodos encontrados na `LabSession`, classificados por categoria
2. **9.1 EntryFormState** — o que migrou, testes verdes após
3. **9.2 AuthSession** — o que migrou, testes verdes após
4. **9.3 NavigationState** — o que migrou, decisão sobre `lessonLocalId`, testes verdes após
5. **9.4 LessonUiState** — o que migrou, status de `aulaStep/selectedAnswer/aulaMessage` (legado vivo ou morto?), testes verdes após
6. **9.5 LabSession ao final** — foi deletada? o que sobrou e por quê?
7. **Testes** — quais novos, total final
8. **Checklist de conclusão:**

```
[ ] EntryFormState criada e no MultiProvider
[ ] AuthSession criada e no MultiProvider
[ ] NavigationState criada e no MultiProvider
[ ] LessonUiState criada e no MultiProvider
[ ] LabSession deletada OU documentado o que ficou
[ ] flutter analyze: zero erros
[ ] flutter test: todos verdes (mínimo 120 + novos)
[ ] git push feito
```

---

**Após entregar o relatório, aguarde aprovação. Não inicie outra fase.**

---

*Instrução Fase 9 emitida: 2026-06-26*
*Gerente técnico: Claude*
