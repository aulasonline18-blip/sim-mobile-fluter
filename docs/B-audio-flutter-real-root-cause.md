# Audio Flutter Real - Root Cause

| Nº | Hipótese | Arquivo | Prova encontrada | Confirmada? SIM/NÃO | Correção necessária? | Risco |
|---:|---|---|---|---|---|---|
| 1 | Botão de áudio com semântica diferente | `lib/features/classroom/aula_widgets.dart:182-190`; `src/cyber/aula/useLessonRuntimeEngine.tsx:203-211/573-578` | Web separa preferência (`onToggleAudio`) da ação de ouvir (`onAudio`); Flutter usa o header para `session.toggleAudio`, que também tenta tocar. | SIM | Ajustar semântica para tocar/parar, sem fingir preferência. | Aluno toca e só muda estado. |
| 2 | Toggle desligando áudio ao tentar parar | `lib/features/session/lab_session.dart:1386-1390` | Ao parar áudio tocando, Flutter também seta `audioEnabled=false` e grava preferência desligada. | SIM | Parar áudio sem desligar preferência. | Próximo toque pode não chamar API por preferência desligada. |
| 3 | Fallback local inexistente | `lib/sim/media/platform_audio_adapter.dart:37-42`; `src/cyber/audio.ts:226-250` | Web usa `speechSynthesis`; Flutter retorna `false` em `speakWithPlatformTts`. | SIM | Erro honesto ou TTS real. Nesta etapa: erro honesto. | App parecer que tem fallback, mas não fala. |
| 4 | API falha sem plano B | `lib/sim/media/audio_core.dart:110-138`; `src/cyber/audio.ts:217-222` | Web cai para browser TTS; Flutter cai para adapter local que retorna false. | SIM | Não marcar tocando; mostrar erro. | Silêncio com bolha/estado falso. |
| 5 | Diferença de retorno true/false | `src/cyber/audio.ts:206-223`; `lib/sim/media/audio_core.dart:94-138` | Web retorna `true` ao agendar; Flutter aguarda geração/playback. | SIM | Preservar Flutter, mas garantir que `true` significa player aceitou tocar. | Estado diverge. |
| 6 | Erro assíncrono de `play()` | `lib/sim/media/platform_audio_adapter.dart:27-34` | `unawaited(_activePlayer.play(...))` descarta erro de playback. | SIM | Aguardar `play()` e capturar exceção. | Falha real vira `audioPlaying=true`. |
| 7 | `onStart` antes do áudio real | `lib/sim/media/platform_audio_adapter.dart:31-33` | `opts.onStart` roda antes de `AudioPlayer.play`. | SIM | Chamar `onStart` só depois de `await play`. | Bolha/onda antes do som. |
| 8 | Bolha falsa | `lib/features/classroom/aula_screen.dart:855-864`; `lab_session.dart:1408` | Bolha depende de `audioPlaying`, que dependia de retorno prematuro do adapter. | SIM | Corrigir origem do estado. | Bolha sem som. |
| 9 | API cobrando/reservando crédito para áudio | `/root/sim-work/sim-api/src/media/audio-controller.js:4` | Servidor reserva crédito antes do Gemini. | SIM | Não mexer agora, salvo prova de cobrança indevida. | Crédito mascarar falha de áudio. |
| 10 | Auth/token bloqueando Gemini | `sim_ai_server_config.dart:26-36`; `router.js:48-52` | Header bearer é obrigatório para rota protegida. | SIM | Já preserva status/requestId; testar sem tocar. | 401 virar silêncio. |
| 11 | Sem bearer e sem fallback real | `audio_core.dart:120-138`; `platform_audio_adapter.dart:37-42` | Sem API, fallback local production retorna false. | SIM | Erro honesto. | Usuário sem som. |
| 12 | Timeout divergente | `lesson_audio_api_contract.dart`; `/root/sim-work/sim-api/src/media/audio-controller.js:4` | Cliente usa 95s; servidor usa 90s. | NÃO | Diferença atual é segura; cliente espera um pouco mais que servidor. | Baixo. |
| 13 | Voz default divergente | `audio_core.dart:3-18`; `src/cyber/audio.ts:46-52` | Web cache default `cedar`; Flutter default `Charon`. API usa Charon/Fenrir. | SIM | Preservar Charon por alinhamento com API. | Baixo. |
| 14 | Idioma caindo errado | `audio_core.dart:179-215`; `lab_session.dart:935-936/1406` | Flutter usa `stableLang ?? selectedLanguageCode`; fallback desconhecido vira `en-US`. | SIM | Não corrigir agora sem caso real; já mapeia muitos idiomas. | Voz errada em idioma raro. |
| 15 | Formato rígido no adapter | `platform_audio_adapter.dart:56-65` | Adapter só decodifica payload após vírgula e não validava MIME/base64 antes. | SIM | Validar `data:audio/*;base64`. | Tentar tocar dado inválido. |
| 16 | MIME não validado | `platform_audio_adapter.dart:57-62` | Qualquer dataUrl com vírgula era aceito para base64. | SIM | Validar MIME de áudio. | Player falhar tarde. |
| 17 | Erro genérico | `lab_session.dart:1412-1414` | Captura `_` e mostra mensagem genérica. | SIM | Mensagem honesta; detalhes técnicos já em exceção/requestId. | Diagnóstico fraco. |
| 18 | Snapshot da aula não pronto | `lab_session.dart:970-978/1402-1404` | `_currentLessonContentForAudio()` lança se `aulaSnapshot?.conteudo` é null. | SIM | Manter erro honesto; não marcar tocando. | Botão visível antes da aula pronta. |
| 19 | Áudio parado cedo demais | `aula_screen.dart:119-128/178-194`; `lab_session.dart:1167/1185/1231` | Stop roda em mudança de posição, lifecycle, resposta, sinal e avanço. | SIM | Preservar stops corretos; testar que play não falha por stop prematuro. | Cortar áudio. |
| 20 | Contrato API diferente do Web | `sim_server_ai_clients.dart:127-168`; `audio-controller.js:4`; `generate-lesson-audio.ts:149-154` | API SIM retorna campos extras, mas `dataUrl` existe como no Web. | NÃO | Sem correção; contrato mínimo compatível. | Baixo. |

## Causa raiz principal

O risco mais direto para "áudio falso" era o `PlatformAudioAdapter` retornar sucesso e disparar `onStart` antes de `AudioPlayer.play()` concluir. Isso podia ligar `audioPlaying`, bolha e avatar sem som audível.
