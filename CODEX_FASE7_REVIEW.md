# REVISÃO DO GERENTE — FASE 7
## Status: APROVADA COM OBSERVAÇÃO DOCUMENTADA

---

## AVALIAÇÃO

Fase 7 concluída corretamente. 119 testes verdes. Código verificado.

**`toggleAudio()` substituído** — o mock anterior foi removido. A nova implementação usa `_audioControllerFor(id).playConteudo()` com tratamento de erro completo. Falha → `audioError` preenchido, aula continua. Parar → `pararAudio()` via controller real. Correto.

**Eventos de áudio** — `AUDIO_STARTED`, `AUDIO_READY`, `AUDIO_FAILED` disparados em `StudentLessonMediaService`. Preenche a lacuna que estava aberta desde a Fase 4.

**`StudentAudioState`** — criado como campo tipado em `StudentLearningState` (padrão Fase 5). Serializado como `audio_typed`. Consistente com `truth_typed` e `sync_status_typed`.

**Observação importante — `NoopAudioPlaybackAdapter`:**
A geração de áudio está conectada ao servidor. A reprodução nativa (plugin de player, controles de play/pause no dispositivo) ainda usa `NoopAudioPlaybackAdapter`. Isso significa que o áudio pode ser *gerado e armazenado* mas não *reproduzido com som físico* ainda. Esta distinção é correta — geração de conteúdo (responsabilidade do app) está feita. Reprodução nativa é responsabilidade do `AudioCore` e pode ser endurecida separadamente quando um plugin de player for escolhido (just_audio, audioplayers, etc.). Documentado, não bloqueia.

---

## ESTADO DO PROJETO APÓS FASES 1–7

```
✅ StudentStateStore com SharedPrefs + Supabase cloud
✅ MasteryTruthEngine, DecisionEngine, Event Log completos
✅ StudentMasteryTruth, StudentSyncStatus, StudentAudioState tipados
✅ toggleAudio() usa LessonAudioController real
✅ AUDIO_STARTED, AUDIO_READY, AUDIO_FAILED disparados
✅ Falha de áudio isolada — aula continua
✅ 119 testes verdes

⚠️  NoopAudioPlaybackAdapter — reprodução nativa de som pendente
⚠️  Endpoints de cloud no servidor ainda não existem (backend separado)
❌ Upload ainda é mock LABORATORY MOCK (Fase 8)
❌ LabSession ainda é God Object com 35+ propriedades (Fase 9)
```

---

---

# INSTRUÇÃO PARA EXECUÇÃO — FASE 8

## OBJETIVO

Remover o mock de upload/extração de texto de arquivo e conectar o `SimServerAttachmentClient` real. Hoje `LabSession.addLabAttachment()` injeta texto falso `'LABORATORY MOCK: texto extraído...'` em vez de extrair o texto real do arquivo.

---

## ANTES DE COMEÇAR — LEITURA OBRIGATÓRIA

Ler completamente:
- `lib/main.dart` — buscar `addLabAttachment`, `LABORATORY MOCK`, `AttachmentDraft` — ver o mock completo
- `lib/sim/external_ai/sim_server_attachment_client.dart` — o cliente real de extração
- Verificar se `SimServerAttachmentClient` está instanciado no `SimOrganism` ou na `LabSession`

Executar:
```bash
grep -rn "LABORATORY MOCK\|addLabAttachment\|AttachmentDraft\|extractText\|attachment" lib/ --include="*.dart" | grep -v "_test"
```

Documentar todos os resultados antes de qualquer mudança.

---

## TAREFA 8.1 — Entender a interface do `SimServerAttachmentClient`

Ler `lib/sim/external_ai/sim_server_attachment_client.dart` e documentar:
- Qual método extrai texto? Qual assinatura?
- Recebe URL? Base64? Path do arquivo?
- Retorna `String`? Objeto? `Future`?
- Como autentica (JWT do usuário? API key?)

Isso define exatamente como substituir o mock.

---

## TAREFA 8.2 — Substituir o mock em `LabSession.addLabAttachment()`

**Arquivo:** `lib/main.dart`

Localizar `addLabAttachment()`. Hoje deve ser algo como:
```dart
// MOCK ATUAL:
void addLabAttachment(String source) {
  final mockText = 'LABORATORY MOCK: texto extraído do anexo...';
  attachments = [...attachments, AttachmentDraft(
    type: 'text/extracted',
    dataUrl: source,
    extractedText: mockText,
  )];
  notifyListeners();
}
```

Substituir pela chamada real:
```dart
Future<void> addLabAttachment(String source) async {
  // Mostrar estado de loading
  attachments = [...attachments, AttachmentDraft(
    type: 'text/extracting',
    dataUrl: source,
    extractedText: null,
  )];
  notifyListeners();

  try {
    final client = _attachmentClient;  // injetado ou criado
    final result = await client.extractText(
      source: source,
      // ... outros parâmetros conforme assinatura real
    );
    // Substituir o placeholder pelo resultado real
    attachments = attachments.map((a) {
      if (a.dataUrl == source && a.type == 'text/extracting') {
        return AttachmentDraft(
          type: 'text/extracted',
          dataUrl: source,
          extractedText: result.text,  // REAL
        );
      }
      return a;
    }).toList();
  } catch (e) {
    // Remover placeholder em caso de erro
    attachments = attachments.where((a) => a.dataUrl != source).toList();
    attachmentError = 'Não foi possível extrair o texto do anexo.';
  }
  notifyListeners();
}
```

**ATENÇÃO:** Adaptar conforme a assinatura real do cliente. Não inventar parâmetros.

---

## TAREFA 8.3 — Garantir que `SimServerAttachmentClient` está disponível na `LabSession`

Verificar se a `LabSession` tem acesso a um `SimServerAttachmentClient`. Se não tiver:
- Verificar se está no `SimOrganism` (pode ser `organism.attachmentClient` ou similar)
- Se não estiver em lugar nenhum, criar instância diretamente na `LabSession` com as configurações do servidor existentes (`SimAiServerConfig`)

Documentar o que foi encontrado.

---

## TAREFA 8.4 — Remover todas as strings `LABORATORY MOCK` do código de produção

Executar após a implementação:
```bash
grep -rn "LABORATORY MOCK" lib/ --include="*.dart"
```

O resultado deve ser **zero ocorrências** em `lib/`. Se alguma restar em código de laboratório intencional (`sim_laboratory_adapters.dart`), documentar por quê foi mantida.

---

## TAREFA 8.5 — Criar testes para a Fase 8

Criar arquivo: `test/fase8_attachment_test.dart`

**Teste 1 — AttachmentDraft serialização:**
Criar `AttachmentDraft` com texto extraído. Verificar campos.

**Teste 2 — addLabAttachment com mock client:**
Criar mock do `SimServerAttachmentClient` que retorna texto fixo. Chamar `addLabAttachment()`. Verificar que `attachments.last.extractedText` é o texto do mock (não `LABORATORY MOCK`).

**Teste 3 — Falha de extração não quebra o estado:**
Mock retorna erro. Verificar que o attachment placeholder foi removido e `attachmentError` foi preenchido.

---

## TAREFA 8.6 — Commitar em subtarefas

```
git commit -m "fase-8: replace addLabAttachment mock with SimServerAttachmentClient"
git commit -m "fase-8: remove all LABORATORY MOCK strings from production flow"
git commit -m "fase-8: attachment extraction tests"
git push
```

---

## CRITÉRIO DE CONCLUSÃO DA FASE 8

```
[ ] Mock 'LABORATORY MOCK' removido do fluxo de produção
[ ] addLabAttachment() chama SimServerAttachmentClient.extractText() real
[ ] Estado de loading durante extração (não bloqueia UI)
[ ] Falha de extração isolada — LabSession não crasha
[ ] grep 'LABORATORY MOCK' lib/ retorna zero (ou documentado se intencional)
[ ] Testes criados e passando
[ ] flutter analyze: zero erros
[ ] flutter test: todos verdes (mínimo 119 + novos)
[ ] git status limpo
```

---

## FORMATO DO RELATÓRIO DA FASE 8

```
# RELATÓRIO — FASE 8 CONCLUÍDA

## Inventário inicial
[resultado do grep LABORATORY MOCK — quantas ocorrências, em quais arquivos]
[como o mock estava implementado — linhas exatas]

## 8.1 — Interface do SimServerAttachmentClient
[métodos encontrados, assinatura real]

## 8.2 — Substituição do mock
[código novo de addLabAttachment(), diferenças encontradas]

## 8.3 — Disponibilidade do client na LabSession
[como o client foi obtido — organism? criado diretamente? outro?]

## 8.4 — Remoção de LABORATORY MOCK
[resultado do grep após a mudança]

## 8.5 — Testes
[quais passaram, quais foram inviáveis]

## OBSERVAÇÕES ADICIONAIS
[qualquer coisa inesperada no SimServerAttachmentClient]

## CRITÉRIO DE CONCLUSÃO
[checklist]

## PRONTO PARA FASE 9?
[sim / não — e por quê]
```

**Após entregar o relatório, aguarde. Não inicie a Fase 9 sem aprovação.**

---

*Aprovação Fase 7: 2026-06-26*
*Instruções Fase 8 emitidas: 2026-06-26*
*Gerente técnico: Claude*
