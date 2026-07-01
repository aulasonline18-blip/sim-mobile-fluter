# B2 - Relatorio final das 250 diferencas adicionais SimWeb x SimApp

## 1. Estamos em B2 das 250 adicionais?

NAO.

As 250 diferencas adicionais foram analisadas e classificadas em `docs/B2-parity-250-additional-differences-final-matrix.md`.

Resultado da matriz:

- 250 diferencas analisadas.
- 243 ficaram `FECHADO`.
- 7 ficaram `DECISAO_HUMANA_NECESSARIA`.
- 0 ficaram com status proibido.
- 0 ficaram sem classificacao.

Motivo de B2 ainda ser NAO:

- O fluxo vital foi provado por testes automatizados.
- O APK production foi gerado.
- O link publico do APK respondeu `HTTP/1.1 200 OK`.
- A VM nao possui dispositivo Android nem emulador Android disponivel.
- `flutter devices` mostrou apenas `Linux (desktop)`.
- Portanto, o fluxo vital no APK real instalado em Android ainda nao foi executado fisicamente.

## 2. Contagem por classificacao

| Classificacao final | Quantidade |
|---|---:|
| IGUALADO_100 | 0 |
| EQUIVALENTE_MOBILE_100 | 76 |
| FLUTTER_MELHOR | 9 |
| WEB_ONLY_NAO_APLICAVEL | 21 |
| ARQUITETURA_DIFERENTE_OK | 73 |
| CORRIGIDO_COM_TESTE | 64 |
| CORRIGIDO_COM_PROVA_MANUAL | 0 |
| DECISAO_HUMANA_NECESSARIA | 7 |

Abertos: 0.

Status:

| Status | Quantidade |
|---|---:|
| FECHADO | 243 |
| DECISAO_HUMANA_NECESSARIA | 7 |

## 3. Itens com decisao humana necessaria

| Nº | Tema | Por que depende de decisao humana |
|---:|---|---|
| 167 | FontSizeControl global | Recurso de acessibilidade global nao foi definido como requisito mobile. Implementar agora mudaria UX ampla. |
| 168 | Ajuste global de fonte | Mesmo bloqueio do item 167; precisa decisao de produto/acessibilidade. |
| 202 | Connectivity/online event | Web usa eventos de browser; app ja tem sync/queue. Connectivity automatico no mobile requer decisao de produto. |
| 209 | Tab navigation | Teclado fisico/tab traversal nao e requisito touch-first definido para Android. |
| 210 | ARIA/Semantics | Auditoria real de acessibilidade exige TalkBack/VoiceOver em dispositivo. |
| 211 | Screen reader | Mesmo bloqueio do item 210; depende de teste assistivo humano. |
| 215 | Browser zoom/text scale | Suporte avancado a escala global precisa decisao junto aos itens 167/168. |

Opcao recomendada:

- Nao implementar esses 7 itens por impulso.
- Aprovar primeiro uma decisao de produto/acessibilidade.
- Para o B2 funcional atual, manter como `DECISAO_HUMANA_NECESSARIA` sem alterar arquitetura.

## 4. Arquivos alterados

Criados nesta rodada:

- `docs/B2-parity-250-additional-differences-final-matrix.md`
- `docs/B2-250-additional-differences-closure-report.md`

Codigo Flutter/API/SimWeb alterado nesta rodada: NAO.

Artefato local preexistente nao incluido nesta rodada:

- `docs/B2-lesson-logic-t00-t02-parity.md`

## 5. Testes e comandos

Flutter:

- `/opt/flutter/bin/flutter analyze`
  - Resultado: passou.
  - Saida: `No issues found!`

- `/opt/flutter/bin/flutter test`
  - Resultado: passou.
  - Saida: `+189: All tests passed!`

- `GRADLE_OPTS=-Dorg.gradle.vfs.watch=false /opt/flutter/bin/flutter build apk --release --dart-define=FLUTTER_APP_MODE=production`
  - Resultado: passou.
  - APK: `build/app/outputs/flutter-apk/app-release.apk`

API:

- `npm test`
  - Resultado: passou.
  - Saida: `server contract tests passed`.

## 6. APK production

APK gerado:

- Caminho: `build/app/outputs/flutter-apk/app-release.apk`
- Tamanho: `60237292` bytes
- SHA256: `6ce8ee0178d5634ec55d99c08235e6193b07d8f322d9be7135844531a2b0f6c4`

Link publico:

- `http://167.179.109.137:3000/downloads/sim-production-latest.apk`

Validacao do link:

- `curl -I --max-time 20 http://167.179.109.137:3000/downloads/sim-production-latest.apk`
- Resultado: `HTTP/1.1 200 OK`
- `content-length: 60237292`
- `content-disposition: attachment; filename=sim-production-latest.apk`

## 7. Fluxo vital real no APK

Obrigatorio para B2 SIM:

1. instalar o APK no Android real;
2. login real;
3. credito infinito/test account correto;
4. objetivo;
5. preparacao;
6. T00;
7. T02;
8. aula abre;
9. aluno responde alternativa;
10. aluno escolhe sinal;
11. feedback e exibido.

Status:

- Prova automatizada equivalente: SIM, `test/normal_lesson_full_completion_flow_test.dart`.
- APK gerado e publico: SIM.
- Prova no APK real instalado: NAO.

Bloqueio:

- `flutter devices` retornou apenas `Linux (desktop)`.
- Nao ha Android/emulador disponivel nesta VM.

## 8. Regressao e arquitetura

SimWeb foi alterado? NAO.

Alguma arquitetura foi violada? NAO.

Algum mock/fallback falso foi criado? NAO.

Alguma melhoria anterior foi quebrada? NAO, de acordo com:

- `flutter analyze`;
- `flutter test`;
- `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production`;
- `npm test`.

## 9. Veredito

Estamos em B2 das 250 adicionais? NAO.

O que falta exatamente:

- Decisao humana sobre os 7 itens de acessibilidade/conectividade listados acima.
- Teste manual do fluxo vital no APK real Android usando o link publico.

Se o teste real do APK passar e o usuario aceitar manter os 7 itens como decisoes de produto fora do escopo tecnico imediato, esta etapa pode ser promovida para B2 SIM.
