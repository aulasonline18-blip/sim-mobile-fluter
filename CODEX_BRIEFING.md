# BRIEFING PARA O CODEX — PROJETO SIM MOBILE FLUTTER
## Alinhamento 100% com a Arquitetura Ideal (PACOTE-MESTRE)

---

## 1. QUEM VOCÊ É E QUAL É SEU PAPEL

Você é o engenheiro executor deste projeto.
Eu (Claude) sou o gerente técnico.

Toda fase é revisada por mim antes de avançar para a próxima.
Você não avança de fase sem minha aprovação.
Você não toma decisões arquiteturais sozinho — executa o que está especificado.
Se encontrar algo inesperado ou ambíguo, para e reporta.

---

## 2. CONTEXTO DO PROJETO

Este é o **SIM Mobile** — um app Flutter educacional de IA que ensina qualquer matéria para qualquer aluno.

O SIM funciona assim:
- O aluno preenche uma ficha com seu objetivo de aprendizado
- O sistema gera um currículo atômico completo (T01)
- Para cada item do currículo, gera uma aula com explicação + pergunta + alternativas (T02)
- O aluno responde, o sistema avalia, decide o próximo passo
- Áudio, imagem e sincronização com nuvem são serviços independentes

O app já tem código funcionando. Não é um projeto do zero.

---

## 3. QUAL É O PROBLEMA

O app foi construído com boa arquitetura **nas partes isoladas**, mas tem um problema central:

**Existem dois sistemas de estado em paralelo, e o sistema mais fraco governa o fluxo principal.**

Além disso, componentes arquiteturais críticos foram implementados mas não conectados ao fluxo principal:

- `StudentStateStore` — existe, mas não é o store principal
- `LearningDecisionEngine` — existe, mas não decide o fluxo real
- `MasteryTruthEngine` — existe, mas não é chamado quando o aluno responde
- `CanonicalLearningEvent` (Event Log) — existe, mas metade dos eventos nunca são disparados
- Áudio e upload de arquivos são **mocks** — retornam dados falsos

O resultado: o app parece funcionar, mas por baixo é frágil, perde progresso em edge cases, não sincroniza corretamente entre dispositivos, e não tem evidência pedagógica real de aprendizagem.

---

## 4. QUAL É O OBJETIVO DESTE TRABALHO

**Alinhar o app 100% com a arquitetura do PACOTE-MESTRE.**

Resumo da arquitetura ideal:

```
ESTADO DO ALUNO (StudentStateStore)
        ↓
MOTOR DE DECISÃO (LearningDecisionEngine)
        ↓
GERADOR (T01 / T02 / Áudio / Imagem)
        ↓
MOTOR DE VERDADE (MasteryTruthEngine)
        ↓
ESTADO DO ALUNO (atualizado)
```

**Princípio central (nunca violar):**
> "O Estado do Aluno é a fonte única da verdade.
> Todos os serviços leem dele, escrevem nele,
> e nunca dependem diretamente uns dos outros."

**O que não muda:**
- Os prompts de T01, T02, T04 — não serão tocados
- A lógica de geração de conteúdo — não muda
- A interface visual — não muda

**O que muda:**
- A orquestração — quem decide o que acontece
- A persistência — como o estado é salvo e recuperado
- A progressão — quem decide avançar layer, avançar item, reforçar

---

## 5. AS FASES DO TRABALHO

O trabalho está dividido em 11 fases. Cada fase tem critério de conclusão claro.
**Você executa uma fase por vez. Reporta. Aguarda aprovação. Avança.**

| # | Fase | O que faz | Risco |
|---|---|---|---|
| 0 | Preparação e inventário | Mapeia o código sem alterar nada | Zero |
| 1 | Unificar os dois stores | `StudentStateStore` vira o único store | Médio |
| 2 | Conectar MasteryTruthEngine | Engine avalia cada resposta do aluno | Médio |
| 3 | Conectar LearningDecisionEngine | Engine decide cada próxima ação | Alto |
| 4 | Completar o Event Log | Todos os eventos canônicos são disparados | Baixo |
| 5 | Tipar campos genéricos do estado | Remover `extra: JsonMap` para campos críticos | Baixo |
| 6 | Sincronização real | Cloud sync conectado ao fluxo principal | Médio |
| 7 | Áudio real | Remover mock, conectar `LessonAudioController` | Baixo |
| 8 | Upload real | Remover mock, conectar `SimServerAttachmentClient` | Médio |
| 9 | Decompor `LabSession` | Separar o God Object em 4 providers | Alto |
| 10 | Corrigir erros críticos | 6 force unwraps, jsonDecode sem try-catch, etc. | Baixo |
| 11 | 10 testes do PACOTE-MESTRE | Validar cada teste de aceitação | Zero |

---

## 6. REGRAS INVIOLÁVEIS PARA TODA A EXECUÇÃO

```
1. NUNCA apague código legado antes de provar que o substituto funciona.
2. NUNCA avance para a próxima fase sem o checklist da fase atual completo.
3. NUNCA altere prompts de T01, T02, T04.
4. NUNCA faça localStorage.clear() ou apague progresso de aluno.
5. NUNCA sobrescreva estado remoto mais avançado com estado local vazio.
6. NUNCA refatore por estética — só o que está especificado.
7. SEMPRE commite ao final de cada subtarefa da fase.
8. SEMPRE reporte o que foi feito, o que foi encontrado, o que ficou pendente.
9. SE encontrar ambiguidade, para e pergunta. Não interpreta livremente.
10. SE um teste quebrar, volta ao commit anterior. Não tenta consertar na força.
```

---

## 7. ESTRUTURA DO REPOSITÓRIO

```
lib/
  main.dart                          ← App entry, LabSession (God Object - será decomposta na Fase 9)
  sim/
    state/
      student_learning_state.dart    ← Modelo canônico do estado do aluno ✅
      student_state_store.dart       ← Store canônico com persistência + eventos ✅ (desconectado)
      student_learning_state_service.dart ← Store simples em memória ⚠️ (é o que governa hoje)
      learning_decision_engine.dart  ← Motor de decisão ✅ (desconectado)
      mastery_truth_engine.dart      ← Motor de verdade pedagógica ✅ (desconectado)
      student_learning_governor.dart ← Orquestrador de resposta ✅ (desconectado)
      internal_organs_governor.dart  ← Usa StudentStateStore (camada secundária)
      foundation_sync.dart           ← Usa StudentStateStore (camada secundária)
      foundation_identity.dart       ← Usa StudentStateStore (camada secundária)
    organism/
      sim_organism.dart              ← Peça central do app - injeta StudentLearningStateService
    classroom/
      lesson_runtime_engine.dart     ← Governa fluxo de aula
      lesson_answer_progress_controller.dart ← Processa resposta do aluno (sem MasteryTruthEngine)
      lesson_position_engine.dart    ← Decide posição (sem LearningDecisionEngine)
    experience/
      student_experience_engine.dart ← T04 + T01 — gera currículo
    lesson/
      student_lesson_material_service.dart ← T02 — gera aula
    media/
      lesson_audio_controller.dart   ← Áudio (existe mas não conectado ao fluxo principal)
      lesson_visual_pipeline.dart    ← Imagem (parcialmente conectado)
    cloud/
      student_state_store.dart       ← Cloud sync (existe mas não conectado ao fluxo principal)
```

---

---

# INSTRUÇÃO PARA EXECUÇÃO — FASE 0

## OBJETIVO DA FASE 0

Mapear o estado atual do código sem alterar absolutamente nada.

A Fase 0 é somente leitura. Nenhum arquivo será criado, modificado ou deletado.
O produto desta fase é um relatório estruturado com os mapeamentos abaixo.

---

## TAREFA 0.1 — Mapear todos os pontos de injeção de `StudentLearningStateService`

Encontre todos os arquivos e linhas onde `StudentLearningStateService` é:
- Importado
- Instanciado
- Injetado como parâmetro
- Seus métodos chamados (`read()`, `write()`, `mutate()`, `ensure()`, `appendEvent()`, `appendAttempt()`)

**Entregável:** Tabela com colunas: `Arquivo | Linha | Tipo de uso | Método chamado`

---

## TAREFA 0.2 — Mapear todos os pontos de decisão de progressão fora do `LearningDecisionEngine`

Encontre todos os lugares no código onde uma dessas decisões é tomada **sem passar pelo `decideNextActionFromState()`**:
- Avançar de layer (l1 → l2 → l3)
- Avançar de item (itemIdx++)
- Enviar para reforço
- Marcar item como concluído
- Mostrar tela de conclusão

Foque especialmente em:
- `lib/sim/classroom/lesson_answer_progress_controller.dart`
- `lib/sim/classroom/lesson_runtime_engine.dart`
- `lib/sim/classroom/lesson_position_engine.dart`
- `lib/sim/state/student_lesson_executor.dart`

**Entregável:** Tabela com colunas: `Arquivo | Linha | Decisão tomada | Lógica usada`

---

## TAREFA 0.3 — Mapear todos os pontos onde `MasteryTruthEngine` deveria ser chamado mas não é

Encontre todos os lugares onde uma tentativa do aluno é registrada ou avaliada sem chamar `MasteryTruthEngine.evaluateMarker()`.

Foque em:
- `lib/sim/classroom/lesson_answer_progress_controller.dart` — método `enviarSinal()`
- `lib/sim/state/student_lesson_executor.dart` — método `processAnswerWithEngine()`
- Qualquer outro lugar que escreve em `state.attempts`

**Entregável:** Tabela com colunas: `Arquivo | Linha | O que faz | MasteryTruthEngine chamado?`

---

## TAREFA 0.4 — Mapear eventos canônicos que deveriam ser disparados mas não são

Compare os eventos que deveriam existir (lista abaixo) com os lugares no código onde cada ação acontece. Verifique se `store.appendEvent()` ou `store.mutateWithEvent()` é chamado nesses lugares.

Eventos esperados:
```
CURRICULUM_GENERATED        → lib/sim/experience/student_experience_engine.dart
LESSON_TEXT_READY           → lib/sim/lesson/student_lesson_material_service.dart
ITEM_ADVANCED               → onde quer que itemIdx seja incrementado
ITEM_MASTERED               → onde quer que um item seja marcado concluído
AUDIO_READY                 → lib/sim/media/lesson_audio_controller.dart
IMAGE_READY                 → lib/sim/media/lesson_visual_pipeline.dart
REINFORCEMENT_REQUIRED      → onde quer que reforço seja acionado
REVIEW_SCHEDULED            → onde quer que revisão seja agendada
WEAKNESS_REGISTERED         → onde quer que item seja marcado como fraco
TECHNICAL_CACHE_CLEARED     → lib/sim/lesson/lesson_material_cache.dart
```

**Entregável:** Tabela com colunas: `Evento | Arquivo onde deveria ser disparado | Linha | É disparado hoje? (sim/não)`

---

## TAREFA 0.5 — Mapear todo o código mock em produção

Encontre todas as ocorrências de:
- String `'LABORATORY MOCK'` em qualquer arquivo
- `audioError = 'Áudio pausado.'` e lógica fake de `toggleAudio()`
- `Future.delayed` usado para simular operações reais
- Qualquer função que deveria chamar uma API mas retorna dados hardcoded

**Entregável:** Tabela com colunas: `Arquivo | Linha | Descrição do mock | O que deveria fazer de verdade`

---

## TAREFA 0.6 — Verificar existência e estado dos assets

Execute:
```bash
ls -la /home/user/sim-mobile-fluter/assets/
```

E verifique no código todos os `Image.asset('assets/...')` para confirmar que cada arquivo referenciado existe fisicamente.

**Entregável:** Lista de assets referenciados vs assets existentes. Marcar quais estão faltando.

---

## TAREFA 0.7 — Checklist de smoke test manual (documentar comportamento atual)

Documente o comportamento atual do app para os seguintes cenários. Este será o critério de regressão para todas as fases seguintes:

```
[ ] 1. Criar aula nova → T4 interpreta → T1 gera currículo → primeira aula abre
[ ] 2. Responder corretamente com sinal 1 (fácil) na L1 → app avança para L2 ou L3
[ ] 3. Responder errado na L1 → app faz reforço ou mantém na L1
[ ] 4. Responder errado 2x no mesmo item → comportamento do app
[ ] 5. Fechar app → reabrir → progresso persiste? (sim/não)
[ ] 6. Clicar no botão de áudio → o que acontece?
[ ] 7. Tentar fazer upload de arquivo → o que acontece?
[ ] 8. Chegar no último item e responder corretamente → tela de conclusão aparece?
```

Para cada item: descreva o que acontece hoje, mesmo que seja comportamento errado ou mock.

---

## FORMATO DO RELATÓRIO DA FASE 0

Ao terminar, entregue um relatório com esta estrutura:

```
# RELATÓRIO — FASE 0 CONCLUÍDA

## 0.1 — Pontos de injeção de StudentLearningStateService
[tabela]

## 0.2 — Pontos de decisão fora do LearningDecisionEngine
[tabela]

## 0.3 — Pontos onde MasteryTruthEngine deveria ser chamado
[tabela]

## 0.4 — Eventos canônicos faltantes
[tabela]

## 0.5 — Código mock em produção
[tabela]

## 0.6 — Assets
[lista]

## 0.7 — Checklist smoke test
[checklist com observações]

## OBSERVAÇÕES ADICIONAIS
[Qualquer coisa encontrada que não estava nos itens acima e que o gerente precisa saber]

## PRONTO PARA FASE 1?
[sim / não — e por quê]
```

---

## CRITÉRIO DE CONCLUSÃO DA FASE 0

A Fase 0 está concluída quando:
- Todas as 7 tarefas têm seus entregáveis completos
- Nenhum arquivo foi modificado (verificar com `git status` — deve estar limpo)
- O relatório foi entregue ao gerente para aprovação

**Após entregar o relatório, aguarde. Não inicie a Fase 1 sem aprovação explícita.**

---

*Documento criado em: 2026-06-26*
*Gerente técnico: Claude (Sonnet 4.6)*
*Executor: Codex*
*Branch de trabalho: `claude/app-audit-report-5a22ba`*
