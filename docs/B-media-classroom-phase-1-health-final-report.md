# Relatório final — mídia da aula Fase 1

## Resultado

1. Estamos em B? SIM para a Fase 1 aplicável, com escopo restrito a mídia visual/imagem/scroll.
2. Diferenças da Fase 1 lidas: 250.
3. CORRIGIR_AGORA: 100.
4. PRESERVAR_ARQUITETURA: 44.
5. PRESERVAR_PLATAFORMA: 11.
6. PRESERVAR_FLUTTER_MELHOR: 15.
7. PRECISA_PROVA_ANTES: 44.
8. DECISAO_HUMANA: 4.
9. FASE_FUTURA: 32.
10. NAO_COPIAR_DOENCA: 0.

## Arquivos alterados

- `docs/B-media-classroom-phase-1-health-triage.md`: triagem obrigatória das 250 diferenças antes de codar.
- `docs/B-media-classroom-phase-1-health-final-report.md`: este relatório.
- `lib/features/classroom/aula_widgets.dart`: painel de imagem responsivo, renderizador único para URL/dataUrl/SVG, erro compacto de imagem e callback de imagem estabilizada.
- `lib/features/classroom/aula_screen.dart`: recálculo de scroll quando imagem carrega/falha e histórico usando o renderizador comum.
- `lib/sim/lesson/lesson_models.dart`: `CompleteLesson.copyWith` agora consegue limpar `imagem` para `null`, evitando imagem antiga em item/layer novo.
- `lib/sim/media/s12_visual_pipeline.dart`: SVG inline exige `viewBox` e mantém bloqueios de segurança.
- `test/finish_phase_test.dart`: testes de painel compacto, erro local de imagem e dataUrl bitmap.
- `test/media_phase_test.dart`: testes de limpeza explícita de imagem e sanitização SVG com `viewBox`.

## O que foi corrigido nesta fase

- Imagem pronta não mostra mais texto/status poluindo a aula.
- Painel de imagem usa altura responsiva ao viewport, mantendo `BoxFit.contain`.
- Imagem SVG/dataUrl/URL passa por um renderizador comum.
- Falha local de imagem mostra erro pequeno e não vira erro pedagógico da aula.
- Imagem carregada/falhada dispara recálculo de scroll da aula.
- Histórico deixa de depender apenas de `Image.network` e aceita formatos já usados na aula.
- SVG sem `viewBox` deixa de ser aceito como SVG inline saudável.
- `copyWith(imagem: null)` limpa imagem antiga de forma explícita.

## Preservações

- SimWeb alterado? NÃO.
- Áudio alterado? NÃO.
- Imagem paga profunda alterada? NÃO.
- Arquitetura correta revertida? NÃO.
- Ponto em que o Flutter estava melhor foi piorado? NÃO.
- T00/T02 alterados? NÃO.
- Pedagogia/UI misturadas? NÃO.

## Validações

- `/opt/flutter/bin/flutter analyze`: PASSOU.
- `/opt/flutter/bin/flutter test`: PASSOU, 200 testes.
- Build/APK: NÃO RODADO nesta fase por instrução do usuário; APK fica somente para o final da Fase 4.
- APK real testado: NÃO nesta fase, pela mesma restrição.

## Observações

- Itens de áudio, bolha, avatar, imagem paga profunda, crédito/cobrança profunda, HTTP de mídia e lifecycle Android foram mantidos fora desta fase.
- Itens que exigem prova visual em celular real permanecem documentados para validação posterior, sem bloquear a correção técnica aplicável da Fase 1.
