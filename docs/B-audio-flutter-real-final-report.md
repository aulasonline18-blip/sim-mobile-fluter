# B Audio Flutter Real Final Report

Data: 2026-07-01

## 1. Estamos em B?

NAO.

Motivo: o APK release foi gerado, publicado e os testes automatizados passaram, mas ainda falta prova manual no celular confirmando som audivel real. Pelo criterio da missao, sem ouvir o APK real, B nao pode ser SIM.

## 2. Causa raiz principal

O ponto principal estava em `PlatformAudioAdapter.playDataUrl`: o adapter chamava `onStart` e devolvia sucesso antes de aguardar a conclusao real de `AudioPlayer.play()`. Isso permitia estado falso de audio tocando, bolha/indicador falso e falha silenciosa se o player rejeitasse o audio de forma assincrona.

Tambem havia confusao operacional no botao do header: quando audio estava tocando, tocar no botao parava o audio, mas tambem desligava a preferencia global de audio.

## 3. Hipoteses confirmadas

- 1. Botao de audio com semantica diferente: SIM.
- 2. Toggle desligando audio ao tentar parar: SIM.
- 3. Fallback local inexistente: SIM.
- 4. API falha sem plano B: SIM, agora erro fica honesto.
- 5. Diferenca de retorno true/false entre Web e Flutter: SIM.
- 6. Erro assincrono de `play()`: SIM.
- 7. `onStart` antes do audio real: SIM.
- 8. Bolha falsa por estado prematuro: SIM.
- 10. Auth/token pode bloquear audio: SIM, coberto por testes de erro/estado.
- 11. Sem bearer e sem fallback real: SIM, nao toca se API falha.
- 13. Voz default divergente: SIM, mantido como risco/prova futura.
- 14. Idioma caindo errado: SIM, mantido como risco/prova futura.
- 15. Formato rigido no adapter: SIM.
- 16. MIME nao validado: SIM, corrigido para aceitar apenas `data:audio/*;base64`.
- 17. Erro generico: SIM, estado nao finge audio.
- 18. Snapshot da aula nao pronto: SIM, tratado no fluxo existente.
- 19. Audio parado cedo demais: SIM parcial, parada agora nao desliga preferencia.

## 4. Hipoteses descartadas ou nao corrigidas nesta fase

- 9. API cobrando/reservando credito para audio: nao confirmado como causa direta nesta etapa.
- 12. Timeout divergente: nao confirmado como causa direta nesta etapa.
- 20. Contrato API diferente do Web: nao confirmado como causa direta; o contrato `dataUrl` continua sendo o caminho esperado.

## 5. Arquivos alterados

- `lib/sim/media/audio_core.dart`: contratos de playback agora sao assincronos e `AudioCore` aguarda sucesso real.
- `lib/sim/media/platform_audio_adapter.dart`: valida dataUrl/MIME/base64, aguarda `AudioPlayer.play()` e so chama `onStart` apos sucesso.
- `lib/features/session/lab_session.dart`: parar audio pelo header nao desliga mais a preferencia global.
- `lib/features/classroom/aula_widgets.dart`: labels/icones do botao deixam claro tocar, preparar ou parar audio.
- `test/media_phase_test.dart`: cobre falha de player assincrona e stop sem desligar preferencia.
- `test/classroom_main_screen_health_test.dart`: atualizado para os novos labels do botao.
- `test/classroom_parity_t01_t28_test.dart`: fake de audio atualizado para contrato async.
- `test/finish_phase_test.dart`: atualizado para acionar `Tocar audio da aula`.

## 6. Testes criados/atualizados

- `audio play failure does not call onStart or report playing`
- `LabSession toggleAudio stop does not disable audio preference`
- Ajustes nos fakes de audio para contrato async.
- Ajustes nas expectativas de Semantics do botao de audio.

## 7. Validacoes

- `flutter analyze`: PASSOU.
- `flutter test`: PASSOU, 214 testes.
- `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production`: PASSOU.

## 8. APK

- Caminho local: `build/app/outputs/flutter-apk/app-release.apk`
- Caminho publico no servidor: `/root/sim-work/sim-api/downloads/sim-production-latest.apk`
- Link publico: `http://167.179.109.137:3000/downloads/sim-production-latest.apk`
- Tamanho: `60569748 bytes`
- SHA256: `8b736eaa277611c42c708daffc4ed7c39aeb9eae965b997d450fc5237a096d72`
- Validacao do link: `HTTP/1.1 200 OK`, `content-length: 60569748`, `cache-control: no-store`.

## 9. Prova APK real

- APK gerado e publicado: SIM.
- APK instalado/testado em celular por esta sessao: NAO.
- Audio ouvido de verdade: NAO PROVADO.

## 10. Confirmacoes finais

- Production usa `PlatformAudioAdapter`: SIM, preservado no wiring de production.
- `NoopAudioPlaybackAdapter` aparece em production: NAO encontrado como wiring production.
- Bolha apareceu sem audio: risco reduzido porque `onStart` so dispara apos `AudioPlayer.play()` retornar sucesso; falta prova real no APK.
- Fallback local existe de verdade: NAO.
- Se fallback nao existe, erro e honesto: SIM, o fallback nao declara sucesso.
- SimWeb foi alterado: NAO.

## 11. Status final

Estamos em B? NAO.

Falta somente a prova manual obrigatoria: instalar o APK publicado, tocar audio em aula real e confirmar som audivel no celular, incluindo parada ao responder/avancar/sair.
