# B2 - Paridade do sistema saudavel de audio SimWeb -> SimApp Flutter/API

## 1. Veredito

Estamos em B2? **SIM**.

O sistema saudavel de audio identificado no B1 foi levado para Flutter/API sem mexer no SimWeb, sem copiar `LessonAvatar.tsx` legado e sem criar controller paralelo. A implementacao ficou nos orgaos corretos: media/audio, material/orchestrator, session runtime, aux rooms e API propria.

## 2. Checklist AUD-B2

| ID | Status final | Prova |
|---|---|---|
| AUD-B2-001 - preparar `audioText` no fluxo vivo/cache/prefetch | COMPLETO COM TESTE | `LessonOrchestrator.setAudioTextPreparer` dispara preparo em cache/fetch/seed; `StudentLessonMaterialService` prepara material restaurado de state/cache; teste `ready material prepares audioText without starting playback`. |
| AUD-B2-002 - fallback local se `GeneratedAudioClient` falhar | COMPLETO COM TESTE | `AudioCore.speak` captura excecao remota e chama `speakWithPlatformTts`; teste `remote audio failure falls back to local TTS without blocking lesson`. |
| AUD-B2-003 - alinhar voz/idioma Flutter/API | COMPLETO COM TESTE | `GenerateLessonAudioRequest.voice`, `voiceByLang`, Flutter envia `voice`; API usa `voiceByLang` em vez de `Kore`; testes Flutter e `npm test`. |
| AUD-B2-004 - provar stop em selecao/sinal/avanco/desmontagem | COMPLETO COM TESTE | `LessonAnswerProgressController` ja chama `audioCore.stop()` em selecionar, sinal e avancar; `LabSession.dispose` e `advanceAula` param controller/doubt audio; teste existente T24 e teste de stop em `media_phase_test`. |
| AUD-B2-005 - conectar audio de duvida | COMPLETO COM TESTE | `LabSession.submitDoubt` chama `DoubtAudio.speakDoubt` quando a resposta chega; `DoubtAudio.speakText` reutiliza o mesmo core; teste `doubt audio appends doubt suffix and respects preference`. |
| AUD-B2-006 - revisao/recuperacao/amparo com audio | COMPLETO COM TESTE | Review/Recovery ganharam acao de audio via `speakAuxRoomContent`; amparo segue `LessonMode.amparo` no caminho normal da aula; teste cobre metodo auxiliar e suites auxiliares/runtime continuam passando. |
| AUD-B2-007 - erro remoto com fallback local e aula nao bloqueada | COMPLETO COM TESTE | Teste especifico de excecao remota prova fallback local; `finish_phase_test` prova estado visual de audio sem travar UI. |

## 3. Arquivos alterados

Flutter:

- `lib/sim/media/audio_core.dart`
- `lib/sim/media/lesson_audio_api_contract.dart`
- `lib/sim/media/student_lesson_media_service.dart`
- `lib/sim/media/doubt_audio.dart`
- `lib/sim/external_ai/sim_server_ai_clients.dart`
- `lib/sim/lesson/lesson_orchestrator.dart`
- `lib/sim/lesson/student_lesson_material_service.dart`
- `lib/sim/organism/sim_organism.dart`
- `lib/features/session/lab_session.dart`
- `lib/features/classroom/aux_room_screens.dart`
- `test/media_phase_test.dart`
- `docs/B1-audio-system-inventory.md`
- `docs/B2-audio-system-parity.md`

API:

- `/root/sim-work/sim-api/src/media/audio-controller.js`
- `/root/sim-work/sim-api/test/server-contract.test.js`

SimWeb:

- Nenhum arquivo alterado.

## 4. Testes criados/atualizados

Atualizados em `test/media_phase_test.dart`:

1. `audio disabled skips generated client and local playback`
2. `remote audio failure falls back to local TTS without blocking lesson`
3. `ready material prepares audioText without starting playback`
4. `doubt audio appends doubt suffix and respects preference`
5. `audio stop covers answer selection, signal, advance and dispose paths`
6. `api contracts preserve limits and constants without secrets`

Atualizados na API:

1. `server-contract.test.js` valida `voiceByLang`.
2. `server-contract.test.js` valida audio default por idioma, cache hit e sem chamada duplicada.

## 5. Provas funcionais

Audio nao bloqueante:

- `AudioCore.speak` retorna fallback local quando remoto falha.
- `StudentLessonMediaService.prepareLessonAudioText` apenas prepara texto e registra evento, sem tocar audio nem chamar endpoint.
- `finish_phase_test` passou com estado visual de audio.

Fallback local:

- Cliente remoto que lanca `StateError` resulta em `platformTtsCalls == 1`.
- Aula continua porque `AudioCore.speak` retorna `true` pelo TTS local.

Preferencia ligado/desligado:

- `AudioPreference` continua default ligado e persistido.
- Com audio desligado, `AudioCore.speak` nao chama `GeneratedAudioClient` nem playback local.
- `DoubtAudio.speakText/speakDoubt` tambem respeitam a preferencia.

Stop/cancelamento:

- Selecao e sinal param audio em `LessonAnswerProgressController`.
- Avanco para item/layer/fim tambem chama `audioCore.stop()`.
- `LabSession.advanceAula`, fechamento de aux rooms e `dispose` param audio de aula e auxiliar.
- `audioPlaying` agora segue `LessonAudioController.falando`, evitando bolha presa depois de `onEnd`.

Duvida/revisao/recuperacao/amparo:

- Duvida fala resposta por `DoubtAudio.speakDoubt` com chave `:doubt`.
- Revisao e recuperacao usam `LabSession.speakAuxRoomContent` e botao de audio no header auxiliar.
- Amparo e reforco usam o caminho normal do runtime (`LessonMode.amparo`/`LessonMode.reforco`) e portanto herdam `LessonAudioController`.

Bolha:

- Continua renderizada quando `session.audioEnabled && session.audioPlaying`.
- `audioPlaying` passa a refletir se o controller ainda esta falando, entao a bolha desaparece quando o audio termina.

Cache:

- `AudioCore` mantem cache por `lessonKey|lang|voice|hash(text)`.
- API mantem cache por `audio:${lessonKey}:${lang}:${hash(text)}`.
- Testes provam chamada duplicada evitada no Flutter e cache hit na API.

## 6. Diferencas restantes

Nenhuma diferenca saudavel bloqueante ficou aberta para B2.

Observacao: o fallback local real depende do adapter da plataforma. Em ambiente de teste, `NoopAudioPlaybackAdapter`/adapter fake provam a rota sem depender de dispositivo.

## 7. Conformidade com a Planta-Mae

Arquivo consultado:

- `PLANTA-MÃE DO SIM IDEAL.txt`

Orgaos/sistemas envolvidos:

- `AudioCore`
- `AudioPreference`
- `StudentLessonMediaService`
- `LessonOrchestrator`
- `StudentLessonMaterialService`
- `LessonAnswerProgressController`
- `LabSession`
- `DoubtAudio`
- `ReviewRoomScreen` / `RecoveryRoomScreen`
- API propria `/api/generate-lesson-audio`

Respostas:

1. Responsabilidade misturada? **NAO**.
2. Estado paralelo criado fora do `StudentLearningState`? **NAO**.
3. Mock/fallback falso de producao criado? **NAO**.
4. Logica pedagogica colocada em UI? **NAO**.
5. Controller/service duplicado? **NAO**.
6. Arquitetura modular preservada? **SIM**.
7. SimWeb alterado? **NAO**.
8. Supabase alterada? **NAO**.
9. T00/T02 alterado? **NAO**.

## 8. Validacoes

Executadas durante a missao:

- `flutter test test/media_phase_test.dart` - passou.
- `npm test` em `/root/sim-work/sim-api` - passou.
- `flutter analyze` - passou, sem issues.
- `flutter test` - passou, 179 testes.
- `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production` - passou, APK gerado em `build/app/outputs/flutter-apk/app-release.apk` com 60.2MB.
- Repeticao final de `npm test` em `/root/sim-work/sim-api` - passou.

## 9. Veredito final

Estamos em B2? **SIM**.
