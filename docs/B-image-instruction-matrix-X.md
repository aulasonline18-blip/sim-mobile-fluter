# B Image Instruction Matrix X

Data: 2026-07-01

## Objetivo X

Ler a missao recebida, extrair todas as instrucoes para uma matriz, reler enquanto novas instrucoes aparecerem e considerar X cumprido somente depois de tres leituras consecutivas sem novas instrucoes.

## Leituras

| Leitura | Novas instrucoes encontradas? | Adicoes principais | Resultado |
|---:|---|---|---|
| 1 | SIM | Objetivo unico, Cidade A/B, 25 portoes, leis da imagem, proibicoes e relatorio final | Continuar lendo |
| 2 | SIM | Protocolo do objetivo X, regra de tres leituras sem novidade, commit/push condicionado a APK real, distincao entre saude do Web e copia cega | Continuar lendo |
| 3 | SIM | Detalhes de cada portao: provas, testes obrigatorios, arquivos minimos, criterios de B parcial e B final | Continuar lendo |
| 4 | NAO | Nenhuma instrucao nova; apenas confirmacao dos itens anteriores | Primeira leitura sem novidade |
| 5 | NAO | Nenhuma instrucao nova | Segunda leitura sem novidade |
| 6 | NAO | Nenhuma instrucao nova | Terceira leitura sem novidade |

Status do objetivo X: EXECUTADO.

## Matriz de instrucoes

| ID | Instrucao | Tipo | Como obedecer | Status inicial |
|---:|---|---|---|---|
| 1 | Fazer o sistema real de imagem do Flutter funcionar no APK | Objetivo | Trabalhar nos portoes tecnicos ate imagem real aparecer | A executar |
| 2 | Reproduzir 100% da saude funcional do SimWeb | Criterio | Usar SimWeb como referencia de saude, nao como copia cega | A executar |
| 3 | Preservar arquitetura Flutter/API e Planta-Mae | Restricao | Nao mover logica para UI/main.dart, manter servicos/orquestradores | A executar |
| 4 | Nao copiar Web cegamente | Restricao | Copiar comportamento saudavel, nao React/CSS/doencas | A executar |
| 5 | Nao transformar Flutter em React | Restricao | Manter implementacao idiomatica Flutter | A executar |
| 6 | Nao produzir apenas relatorio bonito | Criterio | Provar por teste/build/APK | A executar |
| 7 | Nao declarar B por teste unitario se imagem nao aparece no APK | Criterio final | Marcar B = NAO sem prova real no APK | A executar |
| 8 | Aula sem imagem continua normal | Cidade B | Testar fluxo sem imagem | A executar |
| 9 | Aula com visual_trigger software mostra SVG/template local | Cidade B | Testar template local gratuito | A executar |
| 10 | Aula com imagem IA mostra oferta paga explicita | Cidade B | Testar oferta paga | A executar |
| 11 | Recusar imagem paga nao cobra | Cidade B | Testar recusa sem chamada/cobranca | A executar |
| 12 | Aceitar imagem paga gera imagem | Cidade B | Testar aceite e renderizacao | A executar |
| 13 | Credito debita uma unica vez | Cidade B | Testar cobranca/idempotencia | A executar |
| 14 | Duplo toque nao cobra duas vezes | Cidade B | Testar concorrencia/replay | A executar |
| 15 | Retry/replay nao cobra duas vezes | Cidade B | Testar idempotencyKey | A executar |
| 16 | Imagem aparece quando pronta | Cidade B | Notificar UI/renderizar ao READY | A executar |
| 17 | Imagem nao bloqueia texto/pergunta/sinais/feedback/avancar | Lei/Cidade B | Testar imagem lenta e scroll | A executar |
| 18 | Imagem atrasada entra no item certo | Cidade B | Testar troca de item/layer | A executar |
| 19 | Imagem B/C nao invade A | Cidade B | Testar ReadyWindow/slots | A executar |
| 20 | Prefetch nao gera imagem paga | Cidade B | Bloquear imagem paga em background | A executar |
| 21 | Erro de imagem nao quebra aula | Lei/Cidade B | Estado de erro isolado | A executar |
| 22 | Cache usa chave correta | Cidade B | Testar userId/lessonKey/item/layer/lang/hash | A executar |
| 23 | Auth/resource owner impedem cruzamento de usuario | Cidade B | Testar token/user A vs B | A executar |
| 24 | Build passa | Cidade B | Rodar analyze/test/build | A executar |
| 25 | APK real prova imagem | Cidade B final | Testar no celular/APK real | Bloqueio externo se nao houver teste manual |
| 26 | Imagem nunca bloqueia texto | Lei constitucional | Texto primeiro, imagem background | A executar |
| 27 | Imagem preparada em background | Lei constitucional | Orquestrador assíncrono | A executar |
| 28 | T02 envia visual_trigger estruturado | Lei constitucional | Verificar contrato T02/API/Flutter | A executar |
| 29 | Software local gratuito | Lei constitucional | Nao chamar endpoint pago | A executar |
| 30 | IA paga exige aceite explicito | Lei constitucional | acceptedOfferId obrigatorio | A executar |
| 31 | Flutter nao guarda prompt final IA paga hardcoded | Lei constitucional | Manter prompts no servidor | A executar |
| 32 | Nada de logica no main.dart | Proibicao | Nao editar main para imagem | A cumprir |
| 33 | Nada de part/acoplamento artificial | Proibicao | Evitar acoplamentos | A cumprir |
| 34 | Nao bloquear aula por imagem | Proibicao | Testar First Item Fast Path | A cumprir |
| 35 | Nao gerar imagem paga sem aceite | Proibicao | Testes servidor/Flutter | A cumprir |
| 36 | Nao cobrar duas vezes | Proibicao | Idempotencia/duplo toque | A cumprir |
| 37 | Nao ignorar cache/falha/loading infinito | Proibicao | Testes de cache/erro/timeout | A cumprir |
| 38 | Nao mexer no SimWeb | Proibicao | Somente leitura do SimWeb | A cumprir |
| 39 | Nao enfraquecer auth/resource owner | Proibicao | Testes 401/403/user cruzado | A cumprir |
| 40 | Nao usar conta infinita como unica prova | Proibicao | Testar conta normal quando possivel | A cumprir |
| 41 | Criar docs/B-image-real-flow-map.md | Portao 1 | Mapear fluxo real arquivo/funcao | A executar |
| 42 | Portao 2: visual_trigger chega ao app | Portao | Testes valido/ausente/invalido/math/conceitual | A executar |
| 43 | Portao 3: decisao software vs IA | Portao | Testes software/template/ai/nenhum | A executar |
| 44 | Portao 4: SVG/template local funciona | Portao | Testar templates e SVG invalido | A executar |
| 45 | Portao 5: dataUrl/URL renderiza | Portao | Testar PNG/JPEG/SVG/URL/invalido | A executar |
| 46 | Portao 6: UI da imagem nao bloqueia aula | Portao | Testar imagem lenta/falha/feedback | A executar |
| 47 | Portao 7: scroll e imagem atrasada | Portao | Testar atraso/troca/resposta antes da imagem | A executar |
| 48 | Portao 8: layout mobile da imagem | Portao | Testar celular/zoom/aspect ratios | A executar |
| 49 | Portao 9: oferta paga existe | Portao | Testar oferta/recusa/reabertura/item/layer | A executar |
| 50 | Portao 10: aceite explicito | Portao | Testar acceptedOfferId/sem aceite | A executar |
| 51 | Portao 11: credito e cobranca | Portao | Testar saldo/sem saldo/erro/timeout/cache hit | A executar |
| 52 | Portao 12: idempotencia | Portao | Testar duplo toque/retry/replay/concorrencia | A executar |
| 53 | Portao 13: cache local | Portao | Testar reabertura/troca/expiracao | A executar |
| 54 | Portao 14: cache servidor | Portao | Testar user/lang/hash/cache_hit | A executar |
| 55 | Portao 15: auth/resource owner | Portao | Testar token ausente/invalido/user cruzado/APK | A executar |
| 56 | Portao 16: HTTP/requestId/erro util | Portao | Testar status/requestId/retryable | A executar |
| 57 | Portao 17: timeout | Portao | Testar endpoint/provedor/retry | A executar |
| 58 | Portao 18: StudentLearningState | Portao | Testar IMAGE_STARTED/READY/FAILED/replay | A executar |
| 59 | Portao 19: LessonOrchestrator/background | Portao | Testar texto primeiro/imagem depois/B-C | A executar |
| 60 | Portao 20: ReadyWindow/First Item Fast Path | Portao | Testar Slot A sem imagem e prefetch seguro | A executar |
| 61 | Portao 21: historico e reabertura | Portao | Testar historico/drawer/cloud/delete/rename | A executar |
| 62 | Portao 22: foto duvida/anexos separados | Portao | Testar separacao de orgaos | A executar |
| 63 | Portao 23: prova automatizada | Portao | Criar/rodar testes comportamentais | A executar |
| 64 | Portao 24: build APK | Portao | analyze/test/build release production | A executar |
| 65 | Portao 25: prova APK real | Portao final | Teste manual no APK/celular | Bloqueio se sem confirmacao humana |
| 66 | Criar docs/B-image-system-loop-final-report.md | Relatorio | Reportar portoes, provas, comandos e status | A executar |
| 67 | Commit/push somente apos 25 portoes e APK real | Controle git | Nao commit/push antes de prova real | A cumprir |

## Check-in X

Executei X.

Tres leituras consecutivas sem novas instrucoes foram registradas. A matriz acima e a lista estabilizada de instrucoes que vou obedecer na execucao da missao.
