# Plano de saúde da sala de aula principal

Fonte: `docs/B-classroom-main-screen-80-parts-400-plus-differences.md`.

| Grupo | Diferenças relacionadas | Saúde do SimWeb | Estado atual Flutter | Ação ideal | Risco de regressão | Teste/prova |
|---|---|---|---|---|---|---|
| Zoom/fonte | Partes 71-80 | Controle global de 5 níveis, persistido, com limite claro. | Aula usava fontes fixas sem controle do aluno. | Criar órgão de escala com 5 níveis, botão flutuante, persistência e aplicação por `MediaQuery`. | Tela voltar a ficar grande demais ou botão sumir. | `classroom_main_screen_health_test`: 5 níveis e persistência. |
| Layout/header | Partes 1-14 | Header fixo não deve esconder conteúdo e botões têm semântica. | Header mobile já existia, mas sem rótulos explícitos e sem escala coordenada. | Manter arquitetura Flutter, passar escala ao menu e adicionar Semantics em menu, áudio e revisão. | Header cortar contexto ou perder ação. | `flutter test`, Semantics no teste novo. |
| Scroll | Partes 15-28 | Web reage a crescimento do conteúdo durante typewriter/renderização. | Flutter usava chamadas pontuais de `ensureVisible`. | Fazer scroll estabilizado em múltiplas passagens e recalcular ao trocar zoom. | Sinais, feedback ou avançar ficarem fora da tela. | Teste de tela pequena com zoom máximo. |
| Alternativas | Partes 40-48 | Alternativas indicam toque, seleção e estado disabled. | `AnswerButton` compartilhado já cuidava do visual, mas sem Semantics. | Preservar componente e adicionar rótulo/estado Semantics. | Aluno ou leitor de tela não identificar alternativas. | Teste Semantics `Alternativa B`. |
| Sinais | Partes 49-56 | Sinais aparecem abaixo da alternativa e são acionáveis. | Sinais já apareciam, mas precisavam prova com zoom/tela pequena. | Manter posição e adicionar Semantics para `1/2/3`. | Aluno não ver ou não conseguir tocar no sinal. | Teste zoom máximo com sinal visível. |
| Feedback | Partes 57-66 | Feedback e botão avançar ficam visíveis após sinal. | Feedback já existia, mas scroll podia não estabilizar com zoom. | Scroll para feedback, Semantics no avançar e prova em tela pequena. | Aula travar na prática por botão fora da tela. | Teste zoom máximo com feedback e `>>` visíveis. |
| Loading/erro/retry | Partes 66-68 | Loading e erro precisam ação clara. | Retry existia, mas sem Semantics explícito. | Rotular retry sem alterar operação chamada. | Erro parecer congelamento ou retry inacessível. | `flutter test` e Semantics no código. |
| Acessibilidade | Partes transversais | HTML/ARIA do Web deve virar equivalente mobile. | Flutter tinha `GestureDetector` sem rótulos em pontos críticos. | Usar `Semantics` em botões principais. | Regressão de acessibilidade básica. | `classroom_main_screen_health_test`. |
| Provas visuais | Partes transversais | Web tem comportamento observável; Flutter precisa prova no APK. | Havia testes gerais, mas faltava microprova da sala. | Criar testes de widget e gerar APK para prova manual no celular. | B falso sem APK real testado. | Build release + teste manual pendente. |

Decisão: não copiar React, CSS ou DOM. A correção foi consolidada por saúde real: zoom/fonte, scroll, visibilidade, Semantics e prova de tela pequena.
