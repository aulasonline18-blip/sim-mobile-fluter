# REVISÃO DO GERENTE — FASE 9
## Status: APROVADA COM OBSERVAÇÃO DOCUMENTADA

---

## AVALIAÇÃO

Fase 9 concluída. 124 testes verdes (+4 novos). `flutter analyze` zero erros.

**Decisão de arquitetura correta — fachada em vez de MultiProvider:**
O app não usa `MultiProvider`; passa `LabSession` por construtor e `setState`. Inventar uma troca para Provider seria uma reescrita grande, fora do escopo desta fase. A decisão de manter `LabSession` como adaptador/fachada foi a certa. Cada propriedade agora é um getter/setter que delega ao sub-provider real:

```dart
bool get authed => authSession.authed;
String get freeText => entryForm.freeText;
String get route => navigationState.route;
// ...
```

**4 ChangeNotifiers criados e funcionando:**
- `EntryFormState` — freeText, attachments, idioma, nome, `addLabAttachment()` real (código da Fase 8 migrado corretamente)
- `AuthSession` — authed, userId, signIn/signOut/Google, Supabase subscription com `dispose()` correto
- `NavigationState` — route, returnTo, goPortal/goLogin/goAula com `safeNavigationReturnTo()`
- `LessonUiState` — entryStatus, placement, aulaStep, doubtOpen, audioEnabled, deleteConfirmation

**`_notifyFromChild()` correto** — cada sub-provider emite `notifyListeners()`, a `LabSession` re-emite para os widgets que ainda dependem dela. Sem perda de reatividade.

**`AuthSession.dispose()` correto** — cancela `StreamSubscription<AuthState>`. Sem leak de Supabase.

**`aulaStep/selectedAnswer/aulaMessage` documentados como legado vivo** — foram movidos para `LessonUiState`, mantidos por compatibilidade com `AulaLabScreen`. Correto — não deletar sem confirmar que `SimLiveParity` os substituiu completamente.

**`lessonLocalId` ficou no `LessonUiState`** — decisão razoável, é campo de UI de aula.

---

## ESTADO DO PROJETO APÓS FASES 1–9

```
✅ StudentStateStore com SharedPrefs + Supabase cloud
✅ MasteryTruthEngine, DecisionEngine, Event Log completos
✅ StudentMasteryTruth, StudentSyncStatus, StudentAudioState tipados
✅ toggleAudio() usa LessonAudioController real
✅ addLabAttachment() usa SimServerAttachmentClient real
✅ Zero LABORATORY MOCK em produção
✅ EntryFormState — formulário de entrada isolado
✅ AuthSession — autenticação isolada, dispose() correto
✅ NavigationState — roteamento isolado
✅ LessonUiState — estado de UI de aula isolado
✅ LabSession como fachada/adaptador (documentado)
✅ 124 testes verdes

⚠️  LabSession ainda existe como fachada (remoção é trabalho futuro quando widgets migrarem para sub-providers diretos)
⚠️  aulaStep/selectedAnswer/aulaMessage no LessonUiState — legado vivo, remover quando AulaLabScreen for substituída por SimLiveParity
⚠️  NoopAudioPlaybackAdapter — reprodução nativa de som pendente
⚠️  file_picker/image_picker não instalado
⚠️  Endpoints de cloud no servidor ainda não existem (backend separado)
```

---

---

# INSTRUÇÃO PARA EXECUÇÃO — FASE 10

## OBJETIVO

Eliminar os force unwraps (`!`) críticos e adicionar proteção a pontos de falha silenciosa. Esta é a fase de menor risco estrutural — não muda comportamento, só torna o código mais resiliente.

**Regra absoluta desta fase:** a cada correção, rodar `flutter analyze` + `flutter test`. Se qualquer teste quebrar, reverter ao commit anterior antes de continuar.

---

## ANTES DE COMEÇAR

Execute e documente o resultado:

```bash
grep -rn "!\." lib/ --include="*.dart" | grep -v "_test\|//\|assert" | head -30
grep -rn "jsonDecode\|json\.decode" lib/ --include="*.dart" | grep -v "_test"
grep -rn "HttpClient\b" lib/ --include="*.dart" | grep -v "_test"
```

---

## TAREFA 10.1 — Eliminar force unwraps críticos

Os force unwraps a corrigir (verificar se ainda existem — Fase 8/9 pode ter movido alguns):

| Arquivo | Localização | Correção |
|---|---|---|
| `student_experience_placement_adapter.dart` | `placement.startMarker!` | `placement.startMarker?.trim() ?? ''` |
| `partial_curriculum_writer.dart` | `raw.marker!` em 2 lugares | null check antes de usar |
| `doubt_input_sheet.dart` | `image!` | guard clause `if (image == null) return imageOnlyMessage` |
| `student_state_store.dart` | `_eventLog[...]!` em 2 lugares | `_eventLog.putIfAbsent(...)` |
| `main.dart` | `a.extractedText!` | `a.extractedText?.trim() ?? ''` |
| `placement_route_controller.dart` | force unwrap linha 109 | null check explícito |

**Para cada arquivo:**
1. Abrir o arquivo
2. Localizar o `!`
3. Aplicar a correção mínima
4. Rodar `flutter analyze` + `flutter test`
5. Commitar o arquivo

**Não corrija todos de uma vez.** Um arquivo por commit.

---

## TAREFA 10.2 — Proteger jsonDecode em `student_state_store.dart`

Localizar o `jsonDecode` sem try-catch. Substituir por:

```dart
dynamic decoded;
try {
  decoded = jsonDecode(encoded);
} on FormatException {
  return StudentLearningState.empty(lessonLocalId: lessonLocalId);
}
```

Estado corrompido no disco não deve crashar o app — deve começar do zero silenciosamente.

**Verificar:** `flutter analyze` + `flutter test` passam.

---

## TAREFA 10.3 — Fechar `HttpClient` em `DartIoSimHttpTransport`

Verificar `lib/sim/external_ai/dart_io_sim_http_transport.dart` (ou nome similar). Se houver um `HttpClient` criado sem `dispose()`:

```dart
void dispose() {
  _client.close(force: true);
}
```

Se o arquivo não existir com esse nome, fazer o grep abaixo e adaptar:

```bash
grep -rn "HttpClient()" lib/ --include="*.dart"
```

---

## TAREFA 10.4 — Tratar `TimeoutException` nas chamadas de API

Em `sim_server_cloud_functions.dart` (ou o arquivo que faz as chamadas HTTP de cloud), verificar se há `try-catch` cobrindo `TimeoutException`. Se não houver:

```dart
} on TimeoutException {
  throw SimCloudStorageException('Tempo limite da requisição atingido.');
}
```

O app não deve travar silenciosamente quando o servidor demorar demais.

---

## TAREFA 10.5 — Commitar em subtarefas

```
git commit -m "fase-10: fix force unwrap in student_experience_placement_adapter"
git commit -m "fase-10: fix force unwrap in partial_curriculum_writer"
git commit -m "fase-10: fix force unwrap in student_state_store"
git commit -m "fase-10: protect jsonDecode against corrupt state"
git commit -m "fase-10: close HttpClient on dispose"
git commit -m "fase-10: handle TimeoutException in cloud functions"
git push
```

---

## CRITÉRIO DE CONCLUSÃO DA FASE 10

```
[ ] grep '!\.' lib/ retorna zero em arquivos de produção (ou cada restante é justificado)
[ ] jsonDecode protegido contra FormatException
[ ] HttpClient tem dispose() ou é gerenciado corretamente
[ ] TimeoutException capturada nas chamadas de cloud
[ ] flutter analyze: zero erros
[ ] flutter test: todos verdes (mínimo 124 + novos se aplicável)
[ ] git status limpo
```

---

## FORMATO DO RELATÓRIO DA FASE 10

```
# RELATÓRIO — FASE 10 CONCLUÍDA

## Inventário inicial
[resultado dos greps — quantos force unwraps, onde]

## 10.1 — Force unwraps corrigidos
[lista de arquivos, linha, correção aplicada — ou "não encontrado" se já foi corrigido em fase anterior]

## 10.2 — jsonDecode protegido
[onde estava, o que mudou]

## 10.3 — HttpClient
[encontrado? onde? o que foi feito]

## 10.4 — TimeoutException
[encontrado? onde? o que foi feito]

## OBSERVAÇÕES ADICIONAIS
[qualquer coisa inesperada]

## CRITÉRIO DE CONCLUSÃO
[checklist]

## PRONTO PARA FASE 11?
[sim / não — e por quê]
```

**Após entregar o relatório, aguarde. Não inicie a Fase 11 sem aprovação.**

---

*Aprovação Fase 9: 2026-06-26*
*Instruções Fase 10 emitidas: 2026-06-26*
*Gerente técnico: Claude*
