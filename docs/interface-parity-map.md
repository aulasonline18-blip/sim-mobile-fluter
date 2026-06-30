# Interface Parity Map - SimWeb para SimApp Flutter

Base da auditoria: 2026-06-30.

- SimWeb: `/root/sim-work/sim-web`, branch `main`, commit `d113cf4` (`Lovable update`).
- SimApp Flutter: `/root/sim-mobile-fluter`, branch `main`, commit `7f06676` (`docs: map amparo interface parity`).
- Fonte primária desta missão: SimWeb rodando + código real do SimWeb.
- Capturas reais ja obtidas do SimWeb em 390x844:
  - `docs/interface-screenshots/simweb/portal-390x844.png`
  - `docs/interface-screenshots/simweb/login-390x844.png`
  - `docs/interface-screenshots/simweb/idioma-390x844.png` (rota protegida/sem sessao renderizou branco; referencia visual continua pelo codigo ate haver sessao autenticada capturavel).

## Inventario De Telas E Estados SimWeb

| Tela/Estado | Arquivo SimWeb | Componentes/textos/botoes/estados | Equivalente Flutter | Diferenca encontrada | Prints necessarios |
|---|---|---|---|---|---|
| Portal/inicio | `src/cyber/PortalScreen.tsx`, rota `src/routes/index.tsx` | Header com menu se logado, pill de creditos com `Link2`, card com logo `/monkey-logo.png`, H1 `SIM`, tagline, statement, botao start/signin com `Play`, card de ajuda social. Cores: branco/cinza, radius 24-28, sombras leves. | `lib/features/portal/portal_flow.dart` (`PortalScreen`, `PortalHeroCard`, `HelpCard`) | PARCIAL. Estrutura principal existe. Flutter exibe texto `SIM v1  â€¢  Cyber-Premium` com encoding quebrado; precisa comparar HelpCard completo e drawer. | 390x844 e 480x900: portal logado/deslogado. |
| Login | `src/routes/login.tsx` | Logo S em card 64, titulo SIM, modo `Sign in`/`Create account`, botao Google com SVG, divisor `or`, campos email/senha/nome, erro, toggle signin/signup, loading. | `lib/features/auth/login_screen.dart` | PARCIAL. Estrutura e acoes existem. Precisa validar textos exatos, estados de erro/loading, toggle signup e retorno seguro. | Login signin, signup, erro e loading. |
| Idioma | `src/routes/cyber.idioma.tsx`, `src/cyber/CyberStepShell.tsx` | Step shell 1/5, barra 6px, titulo `Choose your language`, texto explicativo, botoes de idiomas com bandeira, `Other language`, box com input e `Continue`. | `lib/features/onboarding/onboarding_screens.dart` (`IdiomaScreen`) | PARCIAL/QUASE IGUAL. Layout traduzido. Encoding de textos especiais no Flutter aparece quebrado em algumas strings; precisa screenshot. | Lista normal e outro idioma aberto. |
| Objetivo/anexos | `src/routes/cyber.objeto.tsx` | Step shell, campo unico `freeText`, nome preferido, anexos ate 3, menu de anexo com documento/camera/galeria, erros para audio/video/objetivo curto, contador 1500, botao continuar. | `lib/features/onboarding/onboarding_screens.dart` (`ObjetoScreen`) | PARCIAL. Funcionalidade existe, mas precisa comparar ordem, textos, menu de anexos, estados `uploading/processing/ready/error` e imagem paga. | Vazio, texto curto, anexo pronto, menu aberto, erro. |
| Preparacao/curriculo/robo | `src/cyber/SimPreparationExperience.tsx`, rota `src/routes/cyber.curriculo.tsx` | Card `sim-prep`, presenter SVG animado, titulo por stage, mensagens rotativas, barra progresso, pulse, botao disabled/ready, hint. | `lib/features/onboarding/preparation_and_placement.dart`, `lib/sim/ui/widgets/sim_preparation_experience.dart` | PARCIAL. Widget Flutter existe e eh visualmente inspirado, mas precisa comparar animacoes, tamanhos, mensagens, ready button e erro. | Stages profile/curriculum/lesson/done/error. |
| Placement/nivelamento | `src/cyber/placement/*`, rota `src/routes/cyber.placement.tsx` | Subfluxo 4 passos: escolha, intro, pergunta, resultado; usa CyberStepShell e T02 placement flag. | `lib/features/onboarding/preparation_and_placement.dart`, `lib/sim/placement/placement_screens.dart` | PARCIAL. Fluxo existe, precisa comparar cada substep, labels e estado preparing. | 4 substeps. |
| Aula principal/topbar | `src/cyber/aula/LessonMainScreen.tsx` | Header fixo: menu, barra progresso 3px, label mono, audio toggle, review button condicional. Nao ha botao duvida no header. | `lib/features/classroom/aula_screen.dart`, `lib/features/classroom/aula_widgets.dart` (`AulaTopBar`) | PARCIAL. Flutter tem menu/progresso/audio/review, mas adiciona icone de duvida no header; no Web a duvida aparece apos resposta concluida. Isso e diferenca de interface/fluxo. | Aula lendo, header com/sem review. |
| Explicacao | `LessonMainScreen.tsx`, `Typewriter.tsx` | Card `glass-soft`, label `aula_theory`, marker/item, typewriter, imagem paga, duvida progress/explicacao, imagem. Pergunta so aparece apos typewriter. | `AulaLabScreen`, `SimTypewriter`, `LessonImagePanel` | PARCIAL. Mecanica existe. Precisa alinhar card/label/divisor, texto, imagem/audio status e gating por typewriter. | Aula com texto, imagem paga, imagem gerada, audio on/off. |
| Pergunta | `LessonMainScreen.tsx` | Divisor gradiente, label `aula_challenge`, h2 20px, aparece apos teoria pronta. | `AulaLabScreen` | PARCIAL. Flutter usa divider simples + card separado de pergunta; Web usa seções separadas sem card envolvendo pergunta/opcoes. | Pergunta antes/depois typewriter. |
| Alternativas A/B/C | `LessonMainScreen.tsx`, `components.tsx` | Botoes `glass`, padding 20, letras em quadrado 36, active com `var(--color-primary)` e shadow glow, `active:scale`. | `shared_widgets.dart` (`AnswerButton`) | PARCIAL. Flutter usa label `A.`/`B.`/`C.` com ponto; Web mostra `A`/`B`/`C` sem ponto. Border ativo usa `simDark`, nao `color-primary` separado. | A/B/C normal, selecionado, locked. |
| Sinais 1/2/3 | `components.tsx` (`SinalBtn`) | Aparecem abaixo da alternativa selecionada, border-left, tres botoes flex, numero grande em mono, label uppercase. | `AulaLabScreen` (`_SinalRow`) e aux room | PARCIAL. Funcao existe; precisa comparar label, layout, border-left e toque. | Alternativa selecionada com sinais. |
| Feedback | `components.tsx` (`FeedbackBox`) | Card glass com border e glow cor sucesso/warn, mensagem e botao proximo no mesmo bloco; aparece apos sinal. | `AulaLabScreen` (`_FeedbackBox`) | PARCIAL. Existe, precisa validar visual, labels e disabled quando proxima aula nao pronta/duvida processing. | Acerto, erro, next disabled/ready. |
| Duvida | `LessonMainScreen.tsx`, `DoubtInputSheet.tsx`, `DoubtProgressBar.tsx` | Botao `Duvida` aparece em `phase.concluido` antes do feedback; sheet bottom com textarea 1200, anexar foto/camera/galeria, erro, enviar, progress e explicacao dentro card da teoria. | `AulaLabScreen`, `_DoubtInputSheet`, `DoubtProgressBar` | PARCIAL/FALHA VISUAL: Flutter tambem tem icone de duvida no header; sheet Flutter precisa ser comparada contra Web para imagem/menu/limite/erro. | Botao duvida, sheet, progress, explicacao, erro. |
| Revisao | `AuxRoomScreens.tsx` | Tela escolha 5/10, preparing com mesmo robo, questoes auxiliares com A/B/C e sinais, feedback, voltar. | `lib/features/classroom/aux_room_screens.dart` | PARCIAL. Fluxo existe; precisa comparar escolha 5/10, header, progress e feedback. | Choose, preparing, question, result, failed. |
| Recuperacao | `AuxRoomScreens.tsx` | Intro/preparing/ready/failed/done/question com mesma estrutura de aux. | `lib/features/classroom/aux_room_screens.dart` | PARCIAL. Fluxo existe; precisa comparar intro, done, erro e retorno. | Intro, preparing, question, done. |
| Amparo/sala auxiliar | `src/cyber/aula/AuxRoomScreens.tsx`, `src/sim/lesson/studentAuxRoomService.ts` | Amparo aparece como sala auxiliar quando regra pedagogica pede; usa padrao aux/prep. | `lib/sim/classroom/amparo_controller.dart`, `aux_room_screens.dart` | INCONCLUSIVO. Precisa mapear tela concreta do Web para amparo e equivalente Flutter. | Tela de amparo se acionavel. |
| Drawer/historico | `src/cyber/AulaDrawer.tsx` | Sheet lateral estilo ChatGPT; nova aula, recarregar creditos logado, lista local/nuvem, busca, paginacao 30+30, renomear, apagar local-first com tombstone, abrir local/cloud, backup import/export, exportar status, logout, solicitar exclusao, status compacto. | `shared_widgets.dart` (`showAulaMenu`) e `portal_flow.dart` drawer | FALHA/PARCIAL. Flutter drawer atual tem historico/busca/footer e acoes basicas, mas ainda nao prova lista cloud/local, paginacao 30+30, renomear/apagar por item, recarregar creditos dentro do drawer, logout e exclusao de conta como Web. | Drawer aberto, busca, renomear, apagar, cloud/local, carregar mais. |
| Creditos | `src/routes/creditos.tsx` | Header com back, titulo `pay_my_credits`, balance card, recharge card, packs 100/200/500 com `Zap`/loading, hosted checkout, erros, modal embedded se modo legado. | `lib/features/billing/billing_and_simple_pages.dart` (`CreditsLabScreen`) | FALHA/PARCIAL. Flutter tem tela simplificada com saldo e packs; faltam header Web, balance visual, loading por pack, erro hosted, banner/test mode/modal. | Loading auth, saldo, packs, loading pack, erro checkout. |
| Conclusao | `LessonStateScreens.tsx`, `SimPreparationExperience stage=done` | Tela full com robo done, ready true, CTA done. | `LessonDoneScreen` | PARCIAL. Usa mesmo widget, precisa comparar CTA e destino. | Done. |
| Loading | `LessonStateScreens.tsx`, `LessonMainScreen.tsx` | Auth loading simples, curriculum hydrating spinner, aula loading card com label theory/progresso/retry. | Flutter `PhaseBoundaryScreen`, `AulaLabScreen` | PARCIAL. Estados existem; precisa comparar mensagens/stages e o fato de Flutter esconde prep se `prefs == null`. | Auth, hydrating, aula loading. |
| Erro | `LessonStateScreens.tsx`, `CyberErrorBoundary.tsx` | Cards glass, mensagem, retry/buy credits, trocar objetivo, request/error context. | Flutter `PhaseBoundaryScreen`, `AulaLabScreen` | PARCIAL. Existe, mas precisa validar textos exatos, requestId e botoes. | T00 error, T02 error, credits error. |
| Estado vazio/sem curriculo | `LessonStateScreens.tsx` (`LessonNoCurriculumScreen`) | Card central com h1/body e link `/cyber/objeto`. | Flutter aula/prep fallbacks | INCONCLUSIVO. Precisa localizar tela Flutter equivalente e testar. | Sem curriculo. |
| Retomada de aula | `AulaDrawer.tsx`, state/cloud store | Abrir local/cloud, hidratar state, navegar aula, dispatch active lesson changed. | `showAulaMenu`, `LabSession.openSupport`, state store | PARCIAL. Persistencia existe por testes, mas UI drawer nao tem paridade Web. | Retomar aula pelo drawer. |

## Matriz De Paridade Inicial

Status permitidos: `NAO INICIADO`, `PARCIAL`, `IGUAL VISUALMENTE`, `IGUAL FUNCIONALMENTE`, `APROVADO`.

| Tela/Componente | SimWeb fonte | Flutter atual | Diferenca | Gravidade | Correcao necessaria | Status |
|---|---|---|---|---|---|---|
| Portal | `PortalScreen.tsx` | `PortalScreen` Flutter | Estrutura existe; precisa corrigir encoding/textos e validar HelpCard/drawer. | Media | Comparar screenshot e alinhar textos/spacing. | PARCIAL |
| Login | `routes/login.tsx` | `LoginScreen` | Estrutura existe; validar toggle/erro/loading/returnTo. | Media | Testes widget e screenshot. | PARCIAL |
| Idioma | `routes/cyber.idioma.tsx` | `IdiomaScreen` | Layout quase igual; encoding de caracteres especiais precisa revisao. | Baixa | Screenshot e ajuste strings. | PARCIAL |
| Objetivo/anexos | `routes/cyber.objeto.tsx` | `ObjetoScreen` | Funcional, mas estados de anexo/menu/erros ainda nao provados. | Alta | Testes widget para anexo, erro, contador e continuar. | PARCIAL |
| Preparacao | `SimPreparationExperience.tsx` | `SimPreparationExperience` Flutter | Widget existe, mas animacao/tamanhos/stages nao comparados visualmente. | Media | Capturar Web/Flutter e ajustar. | PARCIAL |
| Aula header | `LessonMainScreen.tsx` | `AulaTopBar` | Corrigido: header Flutter nao mostra mais botao de duvida; mantem menu, progresso, label, audio e revisao condicional como Web. Ainda falta prova visual por screenshot. | Alta | Capturar screenshot Web/Flutter para aprovar visual. | IGUAL FUNCIONALMENTE |
| Explicacao/typewriter | `LessonMainScreen.tsx` | `AulaLabScreen` | Existe; precisa alinhar card e gating. | Alta | Comparar screenshot e teste. | PARCIAL |
| Pergunta | `LessonMainScreen.tsx` | `AulaLabScreen` | Web usa secao sem card; Flutter usa card separado. | Media | Ajustar estrutura visual. | PARCIAL |
| A/B/C | `LessonMainScreen.tsx` | `AnswerButton` | Corrigido: Flutter usa `A`, `B`, `C` sem ponto e mantem acao real. Ainda falta prova visual de borda/sombra por screenshot. | Media | Capturar screenshot Web/Flutter para aprovar visual. | IGUAL FUNCIONALMENTE |
| Sinais 1/2/3 | `SinalBtn` Web | `_SinalRow` Flutter | Corrigido: tocar 1/2/3 envia o sinal imediatamente, sem botao intermediario. Ainda falta prova visual por screenshot. | Media | Capturar screenshot Web/Flutter para aprovar visual. | IGUAL FUNCIONALMENTE |
| Feedback | `FeedbackBox` Web | `_FeedbackBox` Flutter | Precisa confirmar glow/border/next inline. | Media | Screenshot/teste. | PARCIAL |
| Duvida | `DoubtInputSheet.tsx` | `_DoubtInputSheet`, `LabSession.submitDoubt` | Corrigido funcionalmente: duvida aparece apos resposta concluida, sheet tem texto, contador, anexo, camera, galeria, chip de foto, validacao compartilhada e envio real para `LessonDoubtController`/T02. Ainda falta screenshot comparativo protegido/autenticado para aprovar visualmente. | Alta | Capturar Web/Flutter autenticado para aprovar visual. | IGUAL FUNCIONALMENTE |
| Revisao | `AuxRoomScreens.tsx` | `ReviewRoomScreen` Flutter | Fluxo existe; visual nao aprovado. | Media | Screenshot/testes. | PARCIAL |
| Recuperacao | `AuxRoomScreens.tsx` | `RecoveryRoomScreen` Flutter | Fluxo existe; visual nao aprovado. | Media | Screenshot/testes. | PARCIAL |
| Amparo | `lesson-pipeline-runtime.ts`, `T02Service.ts`, `routes/pai.tsx` | `AmparoController`, `LessonAnswerProgressController`, `FatherPanel` | Mapeado: no Web nao ha sala visual separada de amparo no fluxo principal; amparo e modo T02/estado e aparece no Painel do Pai. Flutter tem controlador e status equivalente. | Baixa | Capturar Painel do Pai quando SimWeb rodar. | IGUAL FUNCIONALMENTE |
| Drawer/historico | `AulaDrawer.tsx` | `showAulaMenu` | Parcialmente corrigido: lista local multi-aula, lista cloud autenticada, dedupe cloud/local por `lessonLocalId`, busca, contador, paginacao 30+30, abrir aula local/cloud, renomear inline local/cloud, apagar local com tombstone, apagar cloud via endpoint, export/import/status e teste widget existem. Ainda falta import sync->cloud e screenshot autenticado. | Alta | Completar import sync->cloud e prova visual autenticada. | PARCIAL |
| Creditos | `routes/creditos.tsx` | `CreditsLabScreen` | Corrigido para estrutura Web: header, balance card, recharge card, packs 100/200/500 com loading e checkout. Ainda falta erro hosted/modal embedded visual. | Alta | Capturar screenshot e cobrir erro hosted/modal se aplicavel ao Flutter. | IGUAL FUNCIONALMENTE |
| Conclusao | `LessonDoneScreen` Web | `LessonDoneScreen` Flutter | Usa robo; precisa validar CTA/destino. | Baixa | Screenshot/teste. | PARCIAL |
| Loading | `LessonStateScreens.tsx` | Flutter loading states | Estados existem; nao aprovados visualmente. | Media | Testes + screenshot. | PARCIAL |
| Erro | `LessonStateScreens.tsx` | Flutter error states | Estados existem; textos/botoes nao validados. | Media | Testes + screenshot. | PARCIAL |
| Estado vazio | `LessonNoCurriculumScreen` | `LessonNoCurriculumScreen` Flutter | Corrigido: erro de aula sem curriculo renderiza card central com h1/body/CTA para objetivo. Ainda falta screenshot visual. | Media | Capturar screenshot Web/Flutter para aprovar visual. | IGUAL FUNCIONALMENTE |
| Responsivo tela pequena | CSS Web + Flutter layouts | Varios | Sem screenshot 320/390; risco de overflow por strings longas. | Alta | Rodar testes em 320x640 e 390x844. | NAO INICIADO |

## Diferencas Criticas Ja Encontradas

1. Drawer Flutter ainda nao prova import sync para nuvem e screenshot autenticado; cloud list/dedupe/open/rename/delete agora tem teste widget.
2. Ainda faltam screenshots reais Web/Flutter para aprovar visualmente portal, login, idioma, objetivo, preparacao, aula, drawer e creditos.
3. Duvida Flutter ja tem camera/galeria e chamada real de T02, mas ainda precisa screenshot comparativo autenticado para marcar `APROVADO`.
4. Amparo foi mapeado como comportamento/estado, nao como tela propria; falta apenas screenshot do Painel do Pai.
5. Comentarios com mojibake ainda podem existir, mas textos visiveis auditados nesta rodada foram corrigidos nos pontos alterados.

## Contrato De Paridade Do Drawer SimWeb

Fonte: `/root/sim-work/sim-web/src/cyber/AulaDrawer.tsx` no commit `d113cf4`.

| Area | Comportamento SimWeb | Prova de codigo | Status Flutter |
|---|---|---|---|
| Abertura/fechamento | Backdrop escuro, aside lateral esquerdo `88vw`, max `360px`, header `menu`, botao fechar. | `AulaDrawer` renderiza backdrop e `<aside role="dialog">`. | PARCIAL: Flutter tem drawer/menu, precisa screenshot comparativa. |
| Nova aula | `handleNovaAula` congela aula ativa, limpa onboarding/curriculo, fecha e navega para `/cyber/aula`. | `cyberLessons.freezeActive()`, `clearOnboarding()`, `clearCurriculo()`, `navigate({ to: "/cyber/aula" })`. | PARCIAL: precisa provar limpeza/rota equivalente. |
| Recarregar creditos | Aparece somente autenticado; navega para `/creditos` preservando `returnTo`. | Botao condicionado por `authState === "in"`. | PARCIAL: Flutter navega para creditos; ainda precisa preservar `returnTo` e screenshot autenticado. |
| Auth | Ao abrir, chama `supabase.auth.getSession()`, assina `onAuthStateChange`, define `checking/in/out`. | `useEffect` com `supabase.auth.getSession()` e subscription. | PARCIAL: Flutter usa sessão Supabase atual para chamadas cloud; nao assina realtime no drawer. |
| Lista nuvem | Usa `useSimLessonsList(open && authState === "in")`, filtra estados deletados, busca por tema/idioma/nivel/id. | `cloudList`, `filteredCloudList`, `matchesLessonSearch`. | IGUAL FUNCIONALMENTE: Flutter chama `listStudentStateSummaries`, filtra `deleted`, busca por tema/idioma/nivel/id e testa lista cloud. |
| Lista local | Usa `cyberLessons.listSummaries()`, remove duplicados ja presentes na nuvem por id/tema. | `localOnly = lessons.filter(...)`. | IGUAL FUNCIONALMENTE: Flutter lista locais, filtra tombstones e deduplica cloud/local por `lessonLocalId`. |
| Busca | Campo de busca filtra nuvem e local, mostra contador `shownRows/totalRows`. | `lessonSearch`, `drawer_search_placeholder`, contador. | IGUAL FUNCIONALMENTE para cloud+local por teste widget. |
| Paginacao | Mostra 30 linhas inicialmente e carrega mais 30 por clique. | `DRAWER_INITIAL_VISIBLE = 30`, `DRAWER_PAGE_SIZE = 30`, `drawer_load_more`. | IGUAL FUNCIONALMENTE usando `aulaDrawerInitialVisible`/`aulaDrawerPageSize`. |
| Abrir local | Tenta `cyberLessons.restoreToSession`; se falhar busca estado remoto por `lessonLocalId`, hidrata, ativa, navega, dispara evento. | `handleAbrir`, `getStudentStateByLesson`, `hydrateStudentLearningStateFromCloud`, `notifyActiveLessonChanged`. | IGUAL FUNCIONALMENTE para estado local; evento browser nao se aplica no Flutter. |
| Abrir nuvem | Usa snapshot ou busca remoto, hidrata, cacheia `lessonId`, ativa, navega e dispara evento. | `handleAbrirCloud`, `cacheLessonCloudId`. | IGUAL FUNCIONALMENTE: Flutter busca `getStudentStateByLesson`, grava no store local, ativa e abre `/cyber/aula`. |
| Renomear local | Botao `✎`, input inline, confirma com `✓` ou Enter, cancela com Escape. | `handleRenomearStart`, `handleRenomearConfirm`, `cyberLessons.rename`. | IGUAL FUNCIONALMENTE: Flutter tem `StudentStateStore.renameLesson`, input inline, `✓`, `✕` e teste widget. |
| Renomear nuvem | Botao `✎`, input inline, atualiza `StudentLearningStateService.rename` e agenda sync. | `handleRenomearCloudConfirm`, `StudentLearningSync.enqueuePatch`. | IGUAL FUNCIONALMENTE: Flutter renomeia snapshot local/remoto e persiste via `persistStudentState`. |
| Apagar local | Confirma, deleta local-first, opcionalmente nuvem por localId, refetch, mostra erro cloud. | `handleApagar`, `deleteLesson`, `drawer_delete_cloud_error`. | IGUAL FUNCIONALMENTE para local-first/tombstone. |
| Apagar nuvem | Confirma, `deleteLesson`, remove espelho local, refetch, erro claro. | `handleApagarCloud`, `removeLocalMirrorFor`. | IGUAL FUNCIONALMENTE: Flutter chama `deleteStudentStateByLesson`, tombstone local se houver e recarrega lista. |
| Exportar backup | Gera `sim-backup-YYYY-MM-DD.txt` com `exportCyberBackup()`. | `handleExport`. | PARCIAL: Flutter exporta para clipboard/dialog, nao arquivo identico. |
| Importar backup | File input `.json/.txt`, parse, importa local, se logado enfileira sync, drain, pull e refetch. | `handleImportFile`, `parseCyberBackup`, `StudentLearningSync.drain`. | PARCIAL: Flutter importa texto/clipboard; falta nuvem/sync como Web. |
| Exportar status | Gera `sim-status-YYYY-MM-DD.txt` via `fatherPanel.buildStatusReport`. | `handleExportStatus`. | PARCIAL: Flutter mostra/exporta status simples; precisa comparar conteudo. |
| Status compacto | Footer exibe avancados/total, concluidos ok, pendentes. | `status.avancados`, `status.total`, `status.concluidos`, `status.pendentes`. | PARCIAL: precisa comparar UI e fonte de dados. |
| Logout | Cancela queries, limpa query cache, `supabase.auth.signOut`, limpa onboarding/curriculo/creditos cache, congela aula e navega login. | `handleLogout`. | AUSENTE/PARCIAL no drawer Flutter. |
| Exclusao de conta | Link para `/conta/deletar` quando autenticado. | `<Link to="/conta/deletar">Solicitar exclusão da conta</Link>`. | AUSENTE. |

## Plano De Captura Visual

- Rodar SimWeb com `bun run dev --host 0.0.0.0` ou `npm run dev -- --host 0.0.0.0`.
- Capturar 390x844 e 480x900 para: portal, login, idioma, objetivo, preparacao, aula lendo, aula com A selecionada, feedback, duvida, drawer, creditos.
- Rodar Flutter widget/integration screenshots equivalentes se o ambiente suportar.
- Sem prints, esta matriz permanece `PARCIAL` e nao pode ser marcada como B.

Tentativas executadas em 2026-06-30:

- `npx bun install`: passou usando o `bun.lock` do SimWeb.
- `npx bun run dev --host 0.0.0.0 --port 4177`: falhou com Node `18.19.1`.
- Motivo 1: Vite requer Node `20.19+` ou `22.12+`; VM tem Node `18.19.1`.
- Motivo 2: a config `@lovable.dev/vite-tanstack-config` tentou `require()` de `lovable-tagger/dist/index.js` ESM e abortou com `ERR_REQUIRE_ESM`.
- Ajuste autorizado de ambiente, sem alterar comportamento do SimWeb: usei Node 22 temporario via `npx -p node@22` apenas no `PATH` do comando de dev server.
- Comando que subiu o SimWeb: `PATH="$(dirname $(npx -y -p node@22 which node)):$PATH" npx bun run dev --host 0.0.0.0 --port 4177`.
- Dev server respondeu em `http://127.0.0.1:4177/`.
- `npx -y playwright install chromium`: instalou Chromium/FFmpeg/headless shell no cache `/root/.cache/ms-playwright/` para captura.
- Capturas Playwright geradas:
  - Portal: `npx -y playwright screenshot --viewport-size=390,844 http://127.0.0.1:4177/ docs/interface-screenshots/simweb/portal-390x844.png`.
  - Login: `npx -y playwright screenshot --viewport-size=390,844 http://127.0.0.1:4177/login docs/interface-screenshots/simweb/login-390x844.png`.
  - Idioma: `npx -y playwright screenshot --viewport-size=390,844 http://127.0.0.1:4177/cyber/idioma docs/interface-screenshots/simweb/idioma-390x844.png`; sem sessao autenticada, a captura ficou em branco, entao idioma/objetivo/aula protegidos ainda dependem de sessao real ou especificacao por codigo.

## Status Atual

Nao estamos em B. Progresso desta rodada:

- `flutter analyze`: passou.
- `flutter test`: passou, 159 testes.
- `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production`: passou, APK gerado em `build/app/outputs/flutter-apk/app-release.apk`.
- APK: 55.141.412 bytes; SHA256 `91527e59939a067985a804914d566fc22eef6605895de082f6f46b726abc0a62`.
- Corrigidos: header da aula sem duvida extra, A/B/C sem ponto, sinais 1/2/3 com envio imediato, sheet de duvida com texto/camera/galeria e T02 real, creditos com estrutura Web, drawer local/cloud com lista/dedupe/busca/paginacao/abrir/renomear/apagar/export/import/status e mojibake visivel em pontos alterados.
- Capturado SimWeb real para portal e login; rota idioma sem sessao ficou em branco.

Ainda falta para B: captura visual real do SimWeb/Flutter em rotas autenticadas, import sync->cloud no drawer e aprovacao visual tela por tela.
