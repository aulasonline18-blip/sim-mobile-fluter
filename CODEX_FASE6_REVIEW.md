# REVISÃO DO GERENTE — FASE 6
## Status: APROVADA

---

## AVALIAÇÃO

Fase 6 concluída corretamente. 119 testes verdes. Código verificado.

**`SupabaseStudentStateCloudStorage`** — implementação correta. Delega para `StudentStateCloudFunctions` (infraestrutura já existente no projeto — `SimServerCloudFunctions`) e `SupabaseSessionProvider` para JWT. Não hardcoda segredos. O app envia o token do usuário autenticado, não um service key. Correto do ponto de vista de segurança.

**Bootstrap em `main.dart`** — `StudentStateStore` agora recebe `cloud: cloudStorage`. Cadeia completa: `SharedPrefs` (local) + `SupabaseStudentStateCloudStorage` (cloud) em um único store canônico.

**`LabSession`** — `hydrateFromCloud()` chamado com `.catchError()` — falha de rede não trava o app. `persistCloud()` chamado no avanço de sessão, também com `.catchError()`. Correto.

**Observação do Codex confirmada:** O servidor (`server.js`) não tem os endpoints `/api/student-state/*`. O cliente Flutter está plugado e não-bloqueante, mas o sync real só acontecerá quando esses endpoints forem criados no backend. Isso é esperado — o alinhamento do app Flutter está sendo feito aqui; o servidor é trabalho separado. O importante é que o app não trava sem esses endpoints.

**Decisão correta:** Usar `StudentStateCloudFunctions` existente em vez de criar uma nova camada Supabase direta. A abstração já estava lá; a Fase 6 apenas criou o adaptador de cola entre o `StudentStateStore` e essa infraestrutura.

---

## ESTADO DO PROJETO APÓS FASES 1–6

```
✅ StudentStateStore com SharedPrefs é o store canônico
✅ MasteryTruthEngine avalia cada resposta — escrita em state.truth tipado
✅ DecisionEngine lê state.truth para decisão de progressão
✅ Todos os eventos canônicos críticos disparados
✅ StudentMasteryTruth e StudentSyncStatus como campos tipados
✅ SupabaseStudentStateCloudStorage conectado ao store
✅ hydrateFromCloud() na abertura da sessão (assíncrono, não-bloqueante)
✅ persistCloud() após avanço e fim de sessão
✅ 119 testes verdes

⚠️  Endpoints de cloud no servidor ainda não existem (trabalho de backend separado)
❌ StudentVisualState e StudentAudioState pendentes (Fase 7+8)
❌ Áudio ainda é mock (Fase 7)
❌ Upload ainda é mock (Fase 8)
❌ LabSession ainda é God Object (Fase 9)
```

---

---

# INSTRUÇÃO PARA EXECUÇÃO — FASE 7

## OBJETIVO

Remover o mock de áudio e conectar o `LessonAudioController` real ao fluxo principal. Hoje `LabSession.toggleAudio()` é um mock que define `audioError = 'Áudio pausado.'` sem chamar nenhum serviço real.

---

## ANTES DE COMEÇAR — LEITURA OBRIGATÓRIA

Ler completamente:
- `lib/sim/media/lesson_audio_controller.dart` — como funciona o controller real
- `lib/sim/media/audio_core.dart` — infraestrutura de áudio
- `lib/sim/media/student_lesson_media_service.dart` — serviço de mídia
- `lib/main.dart` — buscar `toggleAudio`, `audioEnabled`, `audioError` — ver o mock completo
- `lib/sim/organism/sim_organism.dart` — confirmar que `lessonAudioController` está disponível no organism

Executar para mapear todo o código de áudio mock:
```bash
grep -rn "toggleAudio\|audioEnabled\|audioError\|audioUrl\|Áudio pausado" lib/ --include="*.dart"
```

Documentar todos os resultados antes de qualquer mudança.

---

## TAREFA 7.1 — Entender a interface do `LessonAudioController`

Ler `lib/sim/media/lesson_audio_controller.dart` e documentar:
- Qual método inicia/para o áudio?
- Recebe `lessonLocalId`? Recebe o organismo?
- O que retorna? `Stream`? `Future`? Estado reativo?
- Qual estado expõe para a UI? (`isPlaying`, `isLoading`, `error`, `audioUrl`?)

Isso define como a UI (hoje lê `session.audioEnabled`) vai ser conectada.

---

## TAREFA 7.2 — Substituir `LabSession.toggleAudio()` por chamada real

**Arquivo:** `lib/main.dart`

Localizar o método `toggleAudio()` na `LabSession`. Hoje deve ser algo como:
```dart
// MOCK ATUAL:
void toggleAudio() {
  audioError = 'Áudio pausado.';
  audioEnabled = false;
  notifyListeners();
}
```

Substituir pela chamada real ao controller do organismo:
```dart
Future<void> toggleAudio() async {
  final organism = _currentOrganism;  // ou como o organism é acessado
  if (organism == null) return;
  await organism.lessonAudioController.toggle(
    lessonLocalId: lessonLocalId!,
    // outros parâmetros conforme a assinatura real
  );
  notifyListeners();
}
```

**ATENÇÃO:** Verificar como a `LabSession` acessa o organismo ativo. Se não há referência direta, verificar se o organismo é acessível via outro mecanismo. Documentar o que foi encontrado.

---

## TAREFA 7.3 — Criar `StudentAudioState` e adicionar ao `StudentLearningState`

Agora que o áudio vai ser real, criar a classe tipada (que foi deixada para esta fase):

**Arquivo:** `lib/sim/state/student_learning_state.dart` (ou arquivo separado)

```dart
enum AudioStatus { none, generating, ready, error }

class StudentAudioState {
  const StudentAudioState({
    this.status = AudioStatus.none,
    this.audioUrl,
    this.audioText,
    this.lastError,
  });

  final AudioStatus status;
  final String? audioUrl;
  final String? audioText;
  final String? lastError;

  JsonMap toJson() => {
    'status': status.name,
    if (audioUrl != null) 'audio_url': audioUrl,
    if (audioText != null) 'audio_text': audioText,
    if (lastError != null) 'last_error': lastError,
  };

  factory StudentAudioState.fromJson(JsonMap json) => StudentAudioState(
    status: AudioStatus.values.firstWhere(
      (e) => e.name == json['status'],
      orElse: () => AudioStatus.none,
    ),
    audioUrl: json['audio_url'] as String?,
    audioText: json['audio_text'] as String?,
    lastError: json['last_error'] as String?,
  );

  StudentAudioState copyWith({
    AudioStatus? status,
    String? audioUrl,
    String? audioText,
    String? lastError,
  }) => StudentAudioState(
    status: status ?? this.status,
    audioUrl: audioUrl ?? this.audioUrl,
    audioText: audioText ?? this.audioText,
    lastError: lastError ?? this.lastError,
  );
}
```

Adicionar campo `audioState` ao `StudentLearningState` (nullable, compatível com estados antigos). Usar chave `audio_state_typed` no JSON.

---

## TAREFA 7.4 — Disparar `AUDIO_READY` quando áudio estiver pronto

**Arquivo:** `lib/sim/media/lesson_audio_controller.dart`

Quando o áudio for gerado com sucesso, disparar evento:

```dart
store.appendEvent(
  lessonLocalId: lessonLocalId,
  type: 'AUDIO_READY',
  source: 'lesson-audio-controller',
  payload: {
    'audio_url': url,
    'audio_text': text,
    'marker': marker,
    'layer': layer.value,
  },
);
```

E atualizar o estado com `StudentAudioState` tipado:
```dart
stateService.mutate(lessonLocalId, (state) => state.copyWith(
  audioState: StudentAudioState(
    status: AudioStatus.ready,
    audioUrl: url,
    audioText: text,
  ),
));
```

---

## TAREFA 7.5 — Atualizar a UI para ler do estado, não do `session.audioEnabled`

**Arquivo:** `lib/main.dart` (ou widgets de aula)

Localizar onde a UI usa `session.audioEnabled` e `session.audioError`. Substituir por leitura do estado do organismo/store quando disponível. Se a LabSession ainda precisar expor `audioEnabled` como propriedade calculada, pode fazer:

```dart
bool get audioEnabled =>
    _currentOrganism?.audioCore.isPlaying ?? false;
```

Se a integração for muito complexa nesta fase (a LabSession ainda vai ser decomposta na Fase 9), documentar o que foi feito e o que ficou para a Fase 9.

---

## TAREFA 7.6 — Garantir que falha de áudio não interrompe a aula

Verificar que se `LessonAudioController` falhar (rede, TTS indisponível):
- A aula continua normalmente
- O botão de áudio mostra estado de erro, não trava tudo
- Nenhum `throw` não capturado sobe para a UI

Documentar o comportamento de erro no relatório.

---

## TAREFA 7.7 — Criar testes para a Fase 7

Criar arquivo: `test/fase7_audio_test.dart`

**Teste 1 — StudentAudioState serialização:**
Criar `StudentAudioState(status: AudioStatus.ready, audioUrl: 'https://...')`. Serializar e desserializar. Verificar igualdade.

**Teste 2 — AUDIO_READY aparece no event log:**
Simular geração de áudio com mock. Verificar que `AUDIO_READY` foi disparado no store.

**Teste 3 — Falha de áudio não quebra o estado da aula:**
Se `LessonAudioController` retornar erro, verificar que `state.audioState.status == AudioStatus.error` e que `state.progress` não foi alterado.

---

## TAREFA 7.8 — Commitar em subtarefas

```
git commit -m "fase-7: add StudentAudioState typed class to StudentLearningState"
git commit -m "fase-7: replace toggleAudio mock with real LessonAudioController"
git commit -m "fase-7: dispatch AUDIO_READY and update state.audioState"
git commit -m "fase-7: audio tests"
git push
```

---

## CRITÉRIO DE CONCLUSÃO DA FASE 7

```
[ ] Código mock de toggleAudio() removido de main.dart
[ ] LessonAudioController.toggle() chamado no lugar do mock
[ ] StudentAudioState criada e adicionada ao StudentLearningState
[ ] AUDIO_READY disparado quando áudio gerado com sucesso
[ ] state.audioState atualizado com status e URL
[ ] Falha de áudio isolada — aula continua normalmente
[ ] Testes criados e passando
[ ] flutter analyze: zero erros
[ ] flutter test: todos verdes (mínimo 119 + novos)
[ ] git status limpo
```

---

## FORMATO DO RELATÓRIO DA FASE 7

```
# RELATÓRIO — FASE 7 CONCLUÍDA

## Inventário inicial
[resultado do grep de toggleAudio/audioEnabled/audioError]
[como o mock estava implementado — linhas exatas]

## 7.1 — Interface do LessonAudioController
[métodos encontrados, como o controller gerencia estado]

## 7.2 — Substituição do mock
[o que foi alterado em toggleAudio()]

## 7.3 — StudentAudioState
[criada? campos? adicionada ao StudentLearningState?]

## 7.4 — AUDIO_READY
[onde foi disparado, payload]

## 7.5 — UI
[como a UI foi conectada ao estado real]

## 7.6 — Comportamento de erro
[o que acontece quando áudio falha]

## 7.7 — Testes
[quais passaram, quais foram inviáveis]

## OBSERVAÇÕES ADICIONAIS
[qualquer coisa inesperada no LessonAudioController ou AudioCore]

## CRITÉRIO DE CONCLUSÃO
[checklist]

## PRONTO PARA FASE 8?
[sim / não — e por quê]
```

**Após entregar o relatório, aguarde. Não inicie a Fase 8 sem aprovação.**

---

*Aprovação Fase 6: 2026-06-26*
*Instruções Fase 7 emitidas: 2026-06-26*
*Gerente técnico: Claude*
