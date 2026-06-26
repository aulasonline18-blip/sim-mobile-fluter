# INSTRUÇÃO DE EXECUÇÃO — FASE 11
## Para o executor Codex: leia este arquivo, execute, reporte.

---

## CONTEXTO RÁPIDO

Você está no projeto Flutter `sim-mobile-fluter`, branch `claude/app-audit-report-5a22ba`.

Fases 1–10 foram concluídas. 124 testes verdes. Zero `LABORATORY MOCK`. Zero force unwraps críticos.

**Sua tarefa agora é a Fase 11: verificar os 10 testes de aceitação do PACOTE-MESTRE.**

Esta fase **não escreve código novo**. Você vai rodar o app, observar o comportamento e documentar o resultado de cada teste. Se algo falhar, documente e pare — não tente consertar.

---

## PONTO DE PARTIDA OBRIGATÓRIO

```bash
flutter test
```

Confirme 124 testes verdes. Se não passarem, pare e reporte.

---

## OS 10 TESTES

Para cada teste: execute, observe, documente o resultado exato.

---

### Teste 1 — Entrada completa
**O que fazer:** Criar uma nova aula. Preencher objetivo. Submeter.

**O que verificar:**
- T00 (bootstrap) é chamado — currículo é gerado
- Primeira aula abre com conteúdo real (não placeholder)
- `StudentLearningState` foi gravado no SharedPrefs após o bootstrap

**Como verificar o SharedPrefs:** adicionar um log temporário ou verificar via `StudentStateStore.readState(lessonLocalId)` depois do bootstrap.

---

### Teste 2 — Currículo completo gerado de uma vez
**O que fazer:** Após Teste 1, inspecionar o estado salvo.

**O que verificar:**
- Currículo tem mais de 3 itens
- Não há segunda chamada de geração após a primeira
- Todos os itens têm `marker` não-vazio

---

### Teste 3 — Progressão por layers
**O que fazer:** Responder ao item atual.

**O que verificar:**
- L1 → responde → avança para L2
- L2 → responde → avança para L3
- L3 → responde → avança para próximo item
- `itemIdx` incrementa no estado após completar as 3 layers

---

### Teste 4 — Imagem não bloqueia texto
**O que fazer:** Navegar para aula que tenta gerar imagem.

**O que verificar:**
- Texto da aula aparece mesmo sem imagem
- Se imagem falhar, aula continua
- `allowPaidImages = false` respeita a preferência do aluno

---

### Teste 5 — Progresso persiste após fechar o app
**O que fazer:** Fazer progresso em uma aula. Fechar o app completamente. Reabrir.

**O que verificar:**
- itemIdx, layer e marker atual persistem
- Aula reabre no ponto correto

---

### Teste 6 — Sincronização entre dispositivos
**ATENÇÃO:** Os endpoints de cloud no servidor (`/api/student-state/*`) ainda não existem.

**O que fazer:** Tentar fazer progresso e verificar se `persistCloud()` é chamado sem crashar.

**Resultado aceito:** se os endpoints não existem, documentar "BLOQUEADO — backend pendente. App não crasha, simplesmente não sincroniza."

---

### Teste 7 — Backup
**O que fazer:** Chamar `StudentStateStore.exportBackup(lessonLocalId)` programaticamente após uma sessão.

**O que verificar:**
- Retorna JSON com event log e estado
- `importBackup()` restaura o estado corretamente
- `replayEvents()` reproduz o estado

Se não houver forma de testar via UI, documentar como teste de código:
```dart
final backup = await store.exportBackup(lessonLocalId);
await store.importBackup(backup);
final restored = store.readState(lessonLocalId);
// verificar que restored.itemIdx == original.itemIdx
```

---

### Teste 8 — Falha de IA não interrompe a aula
**O que fazer:** Desligar a rede ou usar config de servidor inválida.

**O que verificar:**
- Falha de áudio → aula continua, botão mostra erro
- Falha de imagem → texto continua acessível
- Nenhum crash

---

### Teste 9 — Conclusão de currículo
**O que fazer:** Se possível, completar todos os itens.

**O que verificar:**
- Tela de conclusão aparece
- Progresso não é apagado
- Estado marca currículo como concluído

Se não for viável completar manualmente, documentar como "PENDENTE — requer sessão completa de teste manual."

---

### Teste 10 — Estado não depende de memória
**O que fazer:** Forçar encerramento do processo do app. Reabrir.

**O que verificar:**
- Tela reconstrói do estado lido do SharedPrefs
- `itemIdx`, `layer`, `marker` corretos sem nenhuma variável em memória

---

## O QUE ENTREGAR

Para cada teste:

```
### Teste N — [Nome]
Status: PASSOU / FALHOU / BLOQUEADO
O que foi observado: [exatamente o que aconteceu]
Ponto de falha (se falhou): [arquivo, método, comportamento errado]
```

E ao final:

```
## RESUMO FINAL
Testes que passaram: N/10
Testes bloqueados (backend pendente ou infraestrutura): N/10
Testes que falharam: N/10

## PRONTO PARA ENCERRAR O CICLO?
[sim / não — e por quê]
```

---

## REGRA ABSOLUTA DESTA FASE

**Não corrija código nesta fase.** Se encontrar um bug, documente com precisão (arquivo, linha, comportamento esperado vs observado) e reporte. Correção será fase separada se necessário.

---

**Após entregar o relatório, aguarde aprovação.**

---

*Instrução Fase 11 emitida: 2026-06-26*
*Gerente técnico: Claude*
