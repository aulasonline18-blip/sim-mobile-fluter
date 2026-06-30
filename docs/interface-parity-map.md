# Interface Parity Map - SimWeb para SimApp Flutter

Base da auditoria: 2026-06-30.

- SimWeb: `/root/sim-work/sim-web`, branch `main`, commit `d113cf4` (`Lovable update`).
- SimApp Flutter: `/root/sim-mobile-fluter`, branch `main`, commit `d8b2362` (`test: prove sim vital onboarding flow`).
- Fonte primária desta missão: código real do SimWeb. Prints reais ainda precisam ser capturados com o SimWeb rodando.

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
| Drawer/historico | `src/cyber/AulaDrawer.tsx` | Sheet lateral estilo ChatGPT; nova aula, lista local/nuvem, busca, renomear, apagar, backup import/export, logout, status/painel. | `shared_widgets.dart` (`showAulaMenu`) e `portal_flow.dart` drawer | FALHA/PARCIAL. Flutter drawer atual e bem mais simples; nao ha prova de busca, renomear, apagar, import/export, lista nuvem/local e status compactos como Web. | Drawer aberto, busca, renomear, apagar, cloud/local. |
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
| Duvida | `DoubtInputSheet.tsx` | `_DoubtInputSheet` | Parcialmente corrigido: duvida aparece apos resposta concluida e abre sheet de texto com contador/envio. Ainda falta suporte visual/funcional de foto/camera/galeria como Web. | Alta | Conectar imagem da duvida ou documentar decisao humana para remover/adiar. | PARCIAL |
| Revisao | `AuxRoomScreens.tsx` | `ReviewRoomScreen` Flutter | Fluxo existe; visual nao aprovado. | Media | Screenshot/testes. | PARCIAL |
| Recuperacao | `AuxRoomScreens.tsx` | `RecoveryRoomScreen` Flutter | Fluxo existe; visual nao aprovado. | Media | Screenshot/testes. | PARCIAL |
| Amparo | Aux/Web services | Flutter amparo controller | Tela concreta nao mapeada. | Media | Mapear gatilho/tela e testar. | NAO INICIADO |
| Drawer/historico | `AulaDrawer.tsx` | `showAulaMenu` | Parcialmente corrigido: busca/historico/footer existem e export/import/status agora tem acao real via store/clipboard/dialog. Ainda falta paridade completa com cloud/local, renomear/apagar e screenshots. | Alta | Completar lista cloud/local e acoes de renomear/apagar iguais ao Web. | PARCIAL |
| Creditos | `routes/creditos.tsx` | `CreditsLabScreen` | Corrigido para estrutura Web: header, balance card, recharge card, packs 100/200/500 com loading e checkout. Ainda falta erro hosted/modal embedded visual. | Alta | Capturar screenshot e cobrir erro hosted/modal se aplicavel ao Flutter. | IGUAL FUNCIONALMENTE |
| Conclusao | `LessonDoneScreen` Web | `LessonDoneScreen` Flutter | Usa robo; precisa validar CTA/destino. | Baixa | Screenshot/teste. | PARCIAL |
| Loading | `LessonStateScreens.tsx` | Flutter loading states | Estados existem; nao aprovados visualmente. | Media | Testes + screenshot. | PARCIAL |
| Erro | `LessonStateScreens.tsx` | Flutter error states | Estados existem; textos/botoes nao validados. | Media | Testes + screenshot. | PARCIAL |
| Estado vazio | `LessonNoCurriculumScreen` | `LessonNoCurriculumScreen` Flutter | Corrigido: erro de aula sem curriculo renderiza card central com h1/body/CTA para objetivo. Ainda falta screenshot visual. | Media | Capturar screenshot Web/Flutter para aprovar visual. | IGUAL FUNCIONALMENTE |
| Responsivo tela pequena | CSS Web + Flutter layouts | Varios | Sem screenshot 320/390; risco de overflow por strings longas. | Alta | Rodar testes em 320x640 e 390x844. | NAO INICIADO |

## Diferencas Criticas Ja Encontradas

1. Duvida Flutter ainda nao tem foto/camera/galeria como `DoubtInputSheet.tsx` do Web.
2. Drawer Flutter ainda nao prova paridade total com cloud/local, renomear, apagar e lista paginada do Web.
3. Ainda faltam screenshots reais Web/Flutter para aprovar visualmente portal, login, idioma, objetivo, preparacao, aula, drawer e creditos.
4. Amparo ainda esta inconclusivo nesta matriz.
5. Comentarios com mojibake ainda podem existir, mas textos visiveis auditados nesta rodada foram corrigidos nos pontos alterados.

## Plano De Captura Visual

- Rodar SimWeb com `bun run dev --host 0.0.0.0` ou `npm run dev -- --host 0.0.0.0`.
- Capturar 390x844 e 480x900 para: portal, login, idioma, objetivo, preparacao, aula lendo, aula com A selecionada, feedback, duvida, drawer, creditos.
- Rodar Flutter widget/integration screenshots equivalentes se o ambiente suportar.
- Sem prints, esta matriz permanece `PARCIAL` e nao pode ser marcada como B.

Tentativa executada em 2026-06-30:

- `npx bun install`: passou usando o `bun.lock` do SimWeb.
- `npx bun run dev --host 0.0.0.0 --port 4177`: falhou.
- Motivo 1: Vite requer Node `20.19+` ou `22.12+`; VM tem Node `18.19.1`.
- Motivo 2: a config `@lovable.dev/vite-tanstack-config` tentou `require()` de `lovable-tagger/dist/index.js` ESM e abortou com `ERR_REQUIRE_ESM`.
- Resultado: screenshots reais do SimWeb ainda nao foram capturados nesta VM. A referencia desta rodada ficou baseada no codigo real do SimWeb.

## Status Atual

Nao estamos em B. Progresso desta rodada:

- `flutter analyze`: passou.
- `flutter test`: passou, 155 testes.
- `flutter build apk --release --dart-define=FLUTTER_APP_MODE=production`: passou, APK gerado.
- Corrigidos: header da aula sem duvida extra, A/B/C sem ponto, sinais 1/2/3 com envio imediato, sheet de duvida textual, creditos com estrutura Web, drawer export/import/status com acao real e mojibake visivel em pontos alterados.

Ainda falta para B: captura visual real do SimWeb/Flutter, duvida com imagem, drawer completo cloud/local/renomear/apagar, amparo mapeado e aprovacao visual tela por tela.
