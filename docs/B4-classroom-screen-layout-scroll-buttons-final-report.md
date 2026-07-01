# B4 - Relatorio Final Da Tela De Aula

## Veredito

Estamos em B4? **NAO**.

As 80 diferencas foram analisadas e fechadas na matriz. A diferenca mais sensivel, scroll automatico para pergunta/sinais/feedback, foi corrigida com teste automatizado. Ainda nao posso declarar B4 SIM porque a missao exige prova manual no APK real em celular Android, e este ambiente nao tem dispositivo Android conectado.

## Respostas Obrigatorias

1. As 80 diferencas foram analisadas? **SIM**.
2. Quantas ficaram IGUALADO_100? **7**.
3. Quantas ficaram EQUIVALENTE_MOBILE_100? **38**.
4. Quantas ficaram ARQUITETURA_DIFERENTE_OK? **9**.
5. Quantas ficaram PLATAFORMA_DIFERENTE_OK? **17**.
6. Quantas ficaram FLUTTER_MELHOR? **2**.
7. Quantas ficaram CORRIGIDO_COM_TESTE? **7**.
8. Quantas ficaram CORRIGIDO_COM_PROVA_MANUAL? **0**.
9. Quantas ficaram DECISAO_HUMANA_NECESSARIA? **0**.
10. Quantas ficaram pendentes? **0 na matriz; falta prova manual em APK real para declarar B4 SIM**.
11. Scroll automatico esta correto? **SIM em teste automatizado; falta prova em celular real**.
12. Indicadores 1/2/3 aparecem no lugar certo? **SIM em teste automatizado**.
13. Feedback aparece visivel? **SIM em teste automatizado**.
14. Retry funciona? **SIM por teste/codigo existente**.
15. Duvida funciona? **SIM por teste existente**.
16. Duvida com foto funciona ou esta documentada? **SIM por fluxo/testes existentes de dúvida/anexo; falta prova manual de câmera real no APK**.
17. Revisao/recuperacao renderizam corretamente? **SIM por testes existentes; falta prova visual manual no APK**.
18. Imagem/audio nao quebram layout? **SIM por testes existentes de midia; falta prova visual manual no APK**.
19. Fluxo vital continua funcionando? **SIM por testes automatizados e build; falta prova no APK instalado em celular**.
20. SimWeb foi alterado? **NAO**.
21. Arquitetura foi violada? **NAO**.
22. Alguma feature anterior quebrou? **NAO observado nos testes rodados**.

## Arquivos Alterados

- `lib/features/classroom/aula_screen.dart`
- `test/widget_test.dart`
- `docs/B4-classroom-screen-layout-scroll-buttons-final-matrix.md`
- `docs/B4-classroom-screen-layout-scroll-buttons-final-report.md`

Tambem continuam presentes alteracoes locais anteriores da B3:

- `pubspec.yaml`
- `pubspec.lock`
- `lib/features/session/lab_session.dart`
- `lib/shared/widgets/shared_widgets.dart`

## O Que Foi Corrigido

- A tela de aula ganhou alvos separados de scroll:
  - conteudo/teoria;
  - pergunta;
  - sinais 1/2/3;
  - feedback;
  - erro.
- A rotina de scroll agora escolhe o alvo pelo estado da fase:
  - `expandida` / `processando` -> sinais;
  - `concluido` -> feedback;
  - `erroEngine` -> erro;
  - conteudo novo -> pergunta.
- Quando o alvo ainda nao esta montado no `ListView`, a tela usa fallback para o fim do scroll, equivalente pratico ao `bottomRef` do Web.
- O teste novo usa viewport baixo e nao chama `ensureVisible`, provando que o proprio runtime visual leva sinais e feedback para a area visivel.

## Testes Criados/Alterados

- `test/widget_test.dart`
  - `aula keeps signals and feedback visible after answer flow`

Esse teste prova:

- aula abre;
- a alternativa B fica alcancavel em viewport baixo;
- selecionar alternativa mostra sinais;
- sinal 2 fica dentro da viewport;
- enviar sinal mostra feedback;
- feedback fica dentro da viewport.

## Comandos Rodados

- `/opt/flutter/bin/flutter test test/widget_test.dart --plain-name "aula keeps signals and feedback visible after answer flow"`: **passou**.
- `/opt/flutter/bin/flutter analyze`: **passou**.
- `/opt/flutter/bin/flutter test`: **passou, 191 testes**.
- `/opt/flutter/bin/flutter build apk --release --dart-define=FLUTTER_APP_MODE=production`: **passou**.
- `/opt/flutter/bin/flutter devices`: **passou, mas encontrou apenas Linux desktop; nenhum Android conectado**.

API `npm test`: **nao rodado**, porque a API nao foi alterada nesta missao.

## APK / Link / SHA256

- APK gerado: `build/app/outputs/flutter-apk/app-release.apk`
- Tamanho: **60.569.836 bytes**
- SHA256: **cef2603d7ce46edb9cf20dc0a3a93cd6260e799c348bbb7c66790efda97cbc46**
- Link publico: `http://167.179.109.137:3000/downloads/sim-production-latest.apk`
- Validacao do link: `curl -I --max-time 20 http://167.179.109.137:3000/downloads/sim-production-latest.apk` retornou **200 OK**, `content-type: application/vnd.android.package-archive`, `content-length: 60569836`.

## Prova De Arquitetura

- Nenhuma logica pedagogica foi movida para a UI.
- A tela apenas escolhe alvo de scroll conforme fase ja calculada pelo runtime.
- T00/T02 nao foram alterados.
- Auth, credito, sync, backup, imagem e audio pipeline nao foram alterados.
- SimWeb nao foi alterado.
- Nenhum mock/fallback falso de producao foi criado.

## Pendencia Para B4 SIM

Executar no APK real em celular:

1. tela de aula inicial;
2. explicacao;
3. pergunta;
4. alternativas;
5. alternativa selecionada;
6. indicadores 1/2/3;
7. feedback;
8. proxima layer;
9. scroll depois do feedback;
10. imagem da aula, se houver;
11. duvida aberta;
12. duvida com texto;
13. duvida com foto/galeria, se disponivel;
14. revisao;
15. recuperacao;
16. erro/retry, se reproduzivel;
17. bolha de audio tocando.
