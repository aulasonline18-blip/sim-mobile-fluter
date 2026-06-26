# REVISÃO DO GERENTE — FASE 8
## Status: APROVADA COM OBSERVAÇÃO DOCUMENTADA

---

## AVALIAÇÃO

Fase 8 concluída corretamente. 120 testes verdes. Zero ocorrências de `LABORATORY MOCK` em `lib/`.

**`addLabAttachment()` substituído** — agora chama `SimServerAttachmentClient.processAttachment()` via multipart autenticado. Estado de transição correto: `reading` → `ready` (com texto e método reais) ou `error` (com mensagem isolada). UI não trava durante extração.

**Aviso visual de mock removido** — a tela de objetivo não mostra mais indicador de simulação.

**Teste com client fake** — prova que o texto salvo vem da resposta do client, não de string fixa. Correto.

**Observação documentada — file_picker:**
A seleção nativa de arquivo/foto (`image_picker`, `file_picker`) ainda não está no projeto. O fluxo de processamento está conectado ao servidor, mas depende do picker para o caminho completo "usuário escolhe arquivo → extrai texto → entra no T00". Isso é trabalho de UI/dependência externa e não faz parte da arquitetura de estado. Pode ser adicionado como tarefa independente quando conveniente.

---

## ESTADO DO PROJETO APÓS FASES 1–8

```
✅ StudentStateStore com SharedPrefs + Supabase cloud
✅ MasteryTruthEngine, DecisionEngine, Event Log completos
✅ StudentMasteryTruth, StudentSyncStatus, StudentAudioState tipados
✅ toggleAudio() usa LessonAudioController real
✅ addLabAttachment() usa SimServerAttachmentClient real
✅ Zero LABORATORY MOCK em produção
✅ 120 testes verdes

⚠️  NoopAudioPlaybackAdapter — reprodução nativa de som pendente
⚠️  file_picker/image_picker não instalado (seleção de arquivo pendente)
⚠️  Endpoints de cloud no servidor ainda não existem (backend separado)
❌ LabSession ainda é God Object com 35+ propriedades (Fase 9 — ALTA)
```

---

---

# INSTRUÇÃO PARA EXECUÇÃO — FASE 9

## OBJETIVO

Decompor a `LabSession` God Object em 4 `ChangeNotifier` separados. Esta é a fase de maior risco estrutural. Execute com cuidado máximo.

**Regra absoluta desta fase:** a cada subtarefa concluída, rodar `flutter analyze` + `flutter test`. Se qualquer teste quebrar, reverter ao commit anterior antes de continuar.

---

## ANTES DE COMEÇAR — LEITURA E MAPEAMENTO OBRIGATÓRIOS

### Passo 1 — Contar referências a LabSession na UI
```bash
grep -rn "session\.\|LabSession\|context\.watch\|Provider\.of" lib/ --include="*.dart" | grep -v "class LabSession\|^lib/sim" | wc -l
```

### Passo 2 — Mapear propriedades por categoria

Abrir `lib/main.dart` e listar cada propriedade de `LabSession` classificando assim:

| Propriedade | Categoria |
|---|---|
| authed, authReady, userId, userEmail, userName, authError, credits | AuthSession |
| route, returnTo, externalDoorOpened | NavigationState |
| freeText, preferredName, otherLanguage, selectedLanguageCode, stableLang, allowPaidImages, attachments, attachmentsText, studentProfileNotes | EntryFormState |
| lessonLocalId, entryStatus, entryError, placementStarted, placementDone, aulaStep, selectedAnswer, aulaMessage, doubtOpen, audioEnabled, audioPlaying, audioLoading, audioError, imageStatus, imageError, deleteConfirmation, accountDeletionMessage | LessonUiState |

Documentar esta tabela no relatório.

### Passo 3 — Listar TODOS os métodos de LabSession e sua categoria

Listar cada método público da `LabSession` e em qual provider ele ficará. Documentar antes de codar.

---

## ESTRATÉGIA DE EXECUÇÃO — INCREMENTAL, NÃO BIG BANG

**NÃO faça:** criar os 4 providers novos e deletar `LabSession` de uma vez.

**FAÇA:** migrar um provider por vez, coexistindo com `LabSession` durante a transição.

**Ordem recomendada (menor risco primeiro):**
1. `EntryFormState` — apenas dados do formulário, zero lógica de auth ou navegação
2. `AuthSession` — encapsula Supabase auth, relativamente isolada
3. `NavigationState` — roteamento
4. `LessonUiState` — o mais acoplado, por último

---

## TAREFA 9.1 — Criar `EntryFormState`

**Arquivo:** `lib/session/entry_form_state.dart` (novo diretório `lib/session/`)

```dart
import 'package:flutter/foundation.dart';
import '../sim/state/student_learning_state.dart';

class AttachmentDraft {
  // Verificar se já existe em main.dart e mover para cá
}

class EntryFormState extends ChangeNotifier {
  String freeText = '';
  String preferredName = '';
  String otherLanguage = '';
  String? selectedLanguageCode;
  bool allowPaidImages = false;
  List<AttachmentDraft> attachments = [];
  String attachmentsText = '';
  String studentProfileNotes = '';
  String? attachmentError;

  // Mover para cá os métodos: updateFreeText(), updateLanguage(),
  // addLabAttachment(), removeAttachment(), clearAttachments()
}
```

**Após criar:** adicionar ao `MultiProvider` em `main.dart`. Não remover propriedades da `LabSession` ainda — deixar os dois coexistindo.

**Verificar:** `flutter analyze` + `flutter test` passam. Só então continuar.

---

## TAREFA 9.2 — Migrar widgets de formulário para `EntryFormState`

Localizar todos os widgets em `main.dart` que leem `session.freeText`, `session.attachments`, etc. Substituir por `context.watch<EntryFormState>()` ou `context.read<EntryFormState>()`.

**Somente após todos os widgets migrados:** remover as propriedades correspondentes da `LabSession`.

**Verificar:** `flutter analyze` + `flutter test` passam.

---

## TAREFA 9.3 — Criar `AuthSession`

**Arquivo:** `lib/session/auth_session.dart`

```dart
class AuthSession extends ChangeNotifier {
  bool authed = false;
  bool authReady = false;
  int credits = 0;
  String? userId;
  String? userEmail;
  String? userName;
  String? authError;

  void bindRealAuth() { ... }
  void applySupabaseSession(Session? session) { ... }
  Future<void> signInWithGoogle() { ... }
  Future<void> signOut() { ... }
  // etc.
}
```

Mover os métodos de auth da `LabSession` para cá.

Adicionar ao `MultiProvider`. Migrar widgets. Remover da `LabSession`.

**Verificar:** `flutter analyze` + `flutter test` passam.

---

## TAREFA 9.4 — Criar `NavigationState`

**Arquivo:** `lib/session/navigation_state.dart`

```dart
class NavigationState extends ChangeNotifier {
  String route = '/';
  String returnTo = '/';
  String? lessonLocalId;
  String? externalDoorOpened;

  void goPortal() { route = '/'; notifyListeners(); }
  void goLogin({String target = '/'}) { ... }
  void goAula(String id) { lessonLocalId = id; route = '/cyber/aula'; notifyListeners(); }
  // etc.
}
```

Migrar e verificar.

---

## TAREFA 9.5 — Criar `LessonUiState`

**Arquivo:** `lib/session/lesson_ui_state.dart`

Esta é a mais complexa. Contém o estado de UI da aula que ainda está atrelado ao `SimOrganism` e ao fluxo de aula.

```dart
class LessonUiState extends ChangeNotifier {
  String entryStatus = 'idle';
  String? entryError;
  bool placementStarted = false;
  bool placementDone = false;
  bool doubtOpen = false;
  bool audioEnabled = true;
  bool audioPlaying = false;
  bool audioLoading = false;
  String? audioError;
  String imageStatus = 'idle';
  String? imageError;
  String deleteConfirmation = '';
  String? accountDeletionMessage;
}
```

**ATENÇÃO:** `aulaStep`, `selectedAnswer`, `aulaMessage` hoje são usados pelo código legado de `AulaLabScreen`. Se `SimLiveParity`/`SimOrganism` já governa o fluxo real (Fase 1.5 confirmou isso), esses campos são do código legado que será removido no futuro. Documentar o que fazer com eles — podem ficar na `LessonUiState` temporariamente.

---

## TAREFA 9.6 — Remover LabSession quando completamente esvaziada

Após todas as 4 subtarefas anteriores, a `LabSession` deve ter sobrado apenas com:
- `canonicalStore` (passar para `NavigationState` ou outro provider)
- `SimOrganism` interno (passar para `LessonUiState`)
- Métodos que coordenam os 4 providers

Se a `LabSession` ficou com muito pouco, deletá-la completamente e ajustar o `MultiProvider`.

Se ainda sobrou código complexo de coordenação, documentar o que ficou e por quê.

---

## TAREFA 9.7 — Criar testes para a Fase 9

**Teste 1 — EntryFormState persiste freeText:**
Criar `EntryFormState`. Setar `freeText = 'test'`. Verificar que `notifyListeners` foi chamado.

**Teste 2 — AuthSession responde a signOut:**
Criar `AuthSession`. Chamar `signOut()`. Verificar que `authed = false`.

**Teste 3 — Sem regressão: 120 testes existentes continuam verdes.**

---

## TAREFA 9.8 — Commitar em subtarefas

```
git commit -m "fase-9: extract EntryFormState from LabSession"
git commit -m "fase-9: extract AuthSession from LabSession"
git commit -m "fase-9: extract NavigationState from LabSession"
git commit -m "fase-9: extract LessonUiState from LabSession"
git commit -m "fase-9: remove LabSession (or document what remains)"
git commit -m "fase-9: session decomposition tests"
git push
```

---

## CRITÉRIO DE CONCLUSÃO DA FASE 9

```
[ ] EntryFormState extrai: freeText, preferredName, attachments e métodos relacionados
[ ] AuthSession extrai: authed, userId, signInWithGoogle, signOut, applySupabaseSession
[ ] NavigationState extrai: route, returnTo, lessonLocalId, goPortal, goAula
[ ] LessonUiState extrai: entryStatus, placementStarted, doubtOpen, audioEnabled, etc.
[ ] LabSession deletada OU documentado o que ficou e por quê
[ ] MultiProvider atualizado com os 4 providers novos
[ ] flutter analyze: zero erros em cada subtarefa
[ ] flutter test: todos verdes em cada subtarefa (mínimo 120 + novos)
[ ] git status limpo
```

---

## AVISO — CRITÉRIO DE ABORT

Se em qualquer subtarefa `flutter test` quebrar testes que antes passavam, e a correção não for imediata (< 30 min), **reverter ao commit anterior e reportar**. Não tente consertar na força — reportar o problema ao gerente.

---

## FORMATO DO RELATÓRIO DA FASE 9

```
# RELATÓRIO — FASE 9 CONCLUÍDA

## Mapeamento inicial
[tabela de propriedades por categoria]
[lista de métodos por provider]

## 9.1 — EntryFormState
[o que migrou, o que ficou, testes verdes após]

## 9.2 — AuthSession
[o que migrou, testes verdes após]

## 9.3 — NavigationState
[o que migrou, testes verdes após]

## 9.4 — LessonUiState
[o que migrou, o que ficou — especialmente aulaStep/selectedAnswer legados]

## 9.5 — LabSession ao final
[foi deletada? o que sobrou? por quê?]

## 9.6 — Testes
[quais novos, total final]

## OBSERVAÇÕES ADICIONAIS
[qualquer coisa inesperada — acoplamentos não mapeados, código legado encontrado]

## CRITÉRIO DE CONCLUSÃO
[checklist]

## PRONTO PARA FASE 10?
[sim / não — e por quê]
```

**Após entregar o relatório, aguarde. Não inicie a Fase 10 sem aprovação.**

---

*Aprovação Fase 8: 2026-06-26*
*Instruções Fase 9 emitidas: 2026-06-26*
*Gerente técnico: Claude*
