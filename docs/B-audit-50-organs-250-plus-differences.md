# Auditoria B - 50 orgaos / 250 diferencas SimWeb x SimApp

Escopo: auditoria estatica por orgaos, sem correcao de codigo. Fontes principais:

- SimWeb: `/root/sim-work/sim-web/src`
- SimApp Flutter: `/root/sim-mobile-fluter/lib`, `/root/sim-mobile-fluter/test`
- API: `/root/sim-work/sim-api/src`, `/root/sim-work/sim-api/test`

Observacao: as diferencas abaixo nao significam automaticamente bug. A classificacao separa o que precisa igualar, o que precisa equivalente mobile, o que e Web-only, o que e arquitetura correta e o que exige prova.

## Resumo por parte

| Parte Nº | Parte do SIM | Diferencas encontradas | Bateu minimo 5? |
|---:|---|---:|---|
| 1 | Login e autenticacao | 5 | SIM |
| 2 | Conta de teste/credito infinito | 5 | SIM |
| 3 | Creditos normais | 5 | SIM |
| 4 | Checkout/compra de creditos | 5 | SIM |
| 5 | Tela inicial/portal | 5 | SIM |
| 6 | Idioma | 5 | SIM |
| 7 | Objetivo do aluno | 5 | SIM |
| 8 | Anexos do objetivo | 5 | SIM |
| 9 | Processamento de anexos | 5 | SIM |
| 10 | Preparacao da aula | 5 | SIM |
| 11 | T00 payload | 5 | SIM |
| 12 | T00 streaming/SSE | 5 | SIM |
| 13 | Curriculo gerado | 5 | SIM |
| 14 | Ficha do aluno | 5 | SIM |
| 15 | Fast path primeira aula | 5 | SIM |
| 16 | T02 payload aula normal | 5 | SIM |
| 17 | T02 resposta/contrato | 5 | SIM |
| 18 | Validacao/retry T02 | 5 | SIM |
| 19 | Layers L1/L2/L3 | 5 | SIM |
| 20 | Resposta A/B/C | 5 | SIM |
| 21 | Sinalizadores 1/2/3 | 5 | SIM |
| 22 | Motor de decisao pedagogica | 5 | SIM |
| 23 | Feedback da aula | 5 | SIM |
| 24 | Conclusao da aula | 5 | SIM |
| 25 | Estado do aluno | 5 | SIM |
| 26 | Persistencia local | 5 | SIM |
| 27 | Sync/nuvem | 5 | SIM |
| 28 | Multi-dispositivo | 5 | SIM |
| 29 | Conflitos/tombstone | 5 | SIM |
| 30 | Cache de aula/T02 | 5 | SIM |
| 31 | Janela dopaminica | 5 | SIM |
| 32 | Imagem da aula | 5 | SIM |
| 33 | Imagem paga | 5 | SIM |
| 34 | Audio da aula | 5 | SIM |
| 35 | Bolha/indicador de audio | 5 | SIM |
| 36 | Duvida por texto | 5 | SIM |
| 37 | Duvida com foto | 5 | SIM |
| 38 | Revisao | 5 | SIM |
| 39 | Recuperacao | 5 | SIM |
| 40 | Amparo | 5 | SIM |
| 41 | Menu sanduiche/drawer | 5 | SIM |
| 42 | Historico local/cloud | 5 | SIM |
| 43 | Abrir/renomear/apagar aula | 5 | SIM |
| 44 | Backup exportar | 5 | SIM |
| 45 | Backup importar | 5 | SIM |
| 46 | Tela de aula/layout | 5 | SIM |
| 47 | Scroll da aula | 5 | SIM |
| 48 | Botoes/interacao visual | 5 | SIM |
| 49 | Erros/retry/logs | 5 | SIM |
| 50 | Legal/painel/configuracoes | 5 | SIM |

## Tabela principal

| Nº global | Parte Nº | Parte do SIM | Diferenca encontrada | SimWeb | SimApp Flutter/API | Classificacao inicial | Precisa acao? | Observacao |
|---:|---:|---|---|---|---|---|---|---|
| 1 | 1 | Login e autenticacao | Retorno pos-login usa URL `returnTo`; app usa navegacao por estado. | `routes/login.tsx` valida `safeReturnTo`. | `auth_session.dart`, `navigation_state.dart`. | ARQUITETURA_DIFERENTE_OK | NAO | Mobile nao deve copiar URL web literalmente. |
| 2 | 1 | Login e autenticacao | Web tem modo signin/signup no mesmo formulario; Flutter tem estado local de signup e tela propria. | `LoginScreen` React. | `features/auth/login_screen.dart`. | PRECISA_PROVA | PROVA | Precisa prova visual/autenticada. |
| 3 | 1 | Login e autenticacao | Web usa Supabase browser/localStorage; Flutter usa Supabase mobile session. | `integrations/supabase/client.ts`. | `supabase_flutter_session_provider.dart`. | ARQUITETURA_DIFERENTE_OK | NAO | Arquitetura correta por plataforma. |
| 4 | 1 | Login e autenticacao | API valida bearer JWT e pode rejeitar antes do fluxo; Web same-origin usa ServerFn/middleware. | `auth-middleware.ts`, `route-auth.ts`. | `src/auth/jwt-verifier.js`, `sim_http_transport.dart`. | RISCO_DE_REGRESSAO | SIM | Pode quebrar entrada na aula se token divergir. |
| 5 | 1 | Login e autenticacao | Web limpa React Query no logout; Flutter limpa sessao/app state por controller. | `AulaDrawer.tsx` `queryClient.clear`. | `LabSession.signOutReal`. | POSSIVEL_GAP_FUNCIONAL | SIM | Verificar caches locais apos logout. |
| 6 | 2 | Conta de teste/credito infinito | Web le credito por Supabase/server functions; API tem lista/regra de test credits. | `credits.functions.ts`. | `credits-store.js`. | ARQUITETURA_DIFERENTE_OK | NAO | Fonte diferente por separacao app/API. |
| 7 | 2 | Conta de teste/credito infinito | API retorna `testCreditMode`; Flutter precisa refletir como infinito na UI. | Web trata saldo da conta. | `credits_functions.dart`, `CreditsPill`. | PRECISA_PROVA | PROVA | Confirmar conta real no APK. |
| 8 | 2 | Conta de teste/credito infinito | Web pode depender de perfil/linha Supabase; API usa email/userId em store. | `user_credits`, `profiles`. | `credits-store.js`. | POSSIVEL_GAP_FUNCIONAL | SIM | Risco se email normalizado divergir. |
| 9 | 2 | Conta de teste/credito infinito | Web nao precisa token API adicional; Flutter precisa JWT aceito pela API. | ServerFn com auth context. | `/api/credits/me` protegido. | RISCO_DE_REGRESSAO | SIM | Auth quebra credito antes de T00. |
| 10 | 2 | Conta de teste/credito infinito | Flutter pode exibir cache antigo de credito enquanto API rejeita token. | Portal Web cache local. | `LabSession`/billing client. | PRECISA_IGUALAR | SIM | UI deve refletir estado real recebido. |
| 11 | 3 | Creditos normais | Web cobra por ServerFn `chargeLessonGeneration`; API app usa endpoints reserve/capture/refund. | `credits.functions.ts`. | `credits-controller.js`. | ARQUITETURA_DIFERENTE_OK | NAO | Contrato separado e aceitavel. |
| 12 | 3 | Creditos normais | Web mostra lifetime earned/spent; API snapshot exposto e mais simples. | `getMyCredits`. | `creditSnapshot`. | POSSIVEL_GAP_FUNCIONAL | SIM | Pode faltar informacao na tela. |
| 13 | 3 | Creditos normais | API tem reservas transacionais; Web usa RPC/DB para adicionar/cobrar. | Supabase RPC. | `credits.reserveCredit/captureCredit`. | ARQUITETURA_DIFERENTE_OK | NAO | Implementacao diferente. |
| 14 | 3 | Creditos normais | Erro de credito Web vira `INSUFFICIENT_CREDITS`; app pode receber erro HTTP/API diferente. | `credits.functions.ts`. | `sim_server_billing_clients.dart`. | PRECISA_IGUALAR | SIM | Mensagem aluno deve ser equivalente. |
| 15 | 3 | Creditos normais | Flutter precisa provar conta normal nao vira infinita. | Web DB por usuario. | API tests existentes. | PRECISA_PROVA | PROVA | Teste real/contrato deve cobrir. |
| 16 | 4 | Checkout/compra de creditos | Web tem Stripe Embedded Checkout; Flutter nao embute checkout nativo equivalente. | `StripeEmbeddedCheckout.tsx`. | Billing pages/controllers. | PRECISA_EQUIVALENTE_MOBILE | SIM | Precisa fluxo mobile seguro. |
| 17 | 4 | Checkout/compra de creditos | Web tambem tem hosted checkout; Flutter abre rota/tela externa. | `createCreditsCheckoutHosted`. | `openCreditsFromDrawer`. | PRECISA_PROVA | PROVA | Validar retorno ao app. |
| 18 | 4 | Checkout/compra de creditos | Web valida Stripe Price contra `SIM_PRICING`; Flutter nao deve confiar em UI. | `payments.functions.ts`. | `sim_pricing.dart`, API. | RISCO_DE_REGRESSAO | SIM | Validacao deve ficar backend. |
| 19 | 4 | Checkout/compra de creditos | Web tem webhook publico de pagamento; Flutter nao hospeda webhook. | `routes/api/public/payments/webhook.ts`. | App mobile sem webhook. | WEB_ONLY_NAO_APLICAVEL | NAO | Deve ficar servidor. |
| 20 | 4 | Checkout/compra de creditos | Banner de modo teste existe no Web; Flutter nao possui equivalente visual completo. | `PaymentTestModeBanner.tsx`. | Billing UI Flutter. | PRECISA_EQUIVALENTE_MOBILE | SIM | Importante para ambiente de teste. |
| 21 | 5 | Tela inicial/portal | Web usa DOM/CSS e background decor; Flutter usa widgets/custom painter. | `PortalScreen.tsx`. | `portal_flow.dart`. | PRECISA_PROVA | PROVA | Paridade visual depende screenshot. |
| 22 | 5 | Tela inicial/portal | Web cacheia credito no portal; Flutter recebe estado de sessao. | `readCachedCredits`. | `CreditsPill`, `LabSession`. | POSSIVEL_GAP_FUNCIONAL | SIM | Evitar numero velho no app. |
| 23 | 5 | Tela inicial/portal | Start Web navega URL; Flutter muda estado interno. | `navigate`. | `session.start`. | ARQUITETURA_DIFERENTE_OK | NAO | Correto por plataforma. |
| 24 | 5 | Tela inicial/portal | Web tem hover/focus de browser; Flutter touch-first. | CSS classes. | GestureDetector/buttons. | PRECISA_EQUIVALENTE_MOBILE | SIM | Mobile precisa resposta visual equivalente. |
| 25 | 5 | Tela inicial/portal | Layout Web responde a viewport/browser zoom; Flutter usa MediaQuery. | CSS responsive. | Flutter constraints. | PRECISA_PROVA | PROVA | Provar telas pequenas. |
| 26 | 6 | Idioma | Web rota propria `/cyber/idioma`; Flutter tela interna. | `routes/cyber.idioma.tsx`. | onboarding screens/shared widgets. | ARQUITETURA_DIFERENTE_OK | NAO | Sem URL no app. |
| 27 | 6 | Idioma | Web i18n pode rerenderizar por evento global; Flutter usa `sim_i18n.dart`. | `cyber/i18n.ts`. | `sim_i18n.dart`. | POSSIVEL_GAP_FUNCIONAL | SIM | Risco de string desatualizada. |
| 28 | 6 | Idioma | Web tem traducao UI server-side; Flutter e mais estatico. | `ui-translate.functions.ts`. | Sem equivalente completo. | PRECISA_EQUIVALENTE_MOBILE | SIM | Se Web traduz dinamicamente, app precisa estrategia. |
| 29 | 6 | Idioma | Web persiste idioma em onboarding/local state; Flutter em prefs/session. | `state-director`. | `EntryFormState`, `LabSession`. | ARQUITETURA_DIFERENTE_OK | NAO | Persistencia distinta aceitavel. |
| 30 | 6 | Idioma | Estilo de botoes idioma Web e Flutter nao e pixel-identico. | Componentes Web. | `LanguageButton`. | PRECISA_PROVA | PROVA | Screenshot obrigatorio. |
| 31 | 7 | Objetivo do aluno | Web formulario contem migracao/limpeza de attachments antigos; Flutter nao tem a mesma migracao. | `runAttachmentStorageMigration`. | onboarding Flutter. | POSSIVEL_GAP_FUNCIONAL | SIM | Pode afetar usuario antigo. |
| 32 | 7 | Objetivo do aluno | Web salva e segue por rota `/cyber/curriculo`; Flutter segue por session/onboarding. | `salvarESeguir`. | `LabSession` flow. | ARQUITETURA_DIFERENTE_OK | NAO | Caminho distinto. |
| 33 | 7 | Objetivo do aluno | Web trata paste de arquivos/texto; Flutter TextField tende a tratar texto. | `handlePaste`. | onboarding input. | PRECISA_EQUIVALENTE_MOBILE | SIM | Mobile paste/foto precisa equivalencia. |
| 34 | 7 | Objetivo do aluno | Web exige objetivo e mostra loading visivel; Flutter tem estados proprios. | `showObjectiveRequired`, `VisibleLoading`. | onboarding screens. | PRECISA_IGUALAR | SIM | Bloqueio do objetivo e regressao critica. |
| 35 | 7 | Objetivo do aluno | Web monta texto de anexos no objetivo; Flutter depende do client/API. | `buildAttachmentsText`. | attachment client. | PRECISA_PROVA | PROVA | Provar payload final. |
| 36 | 8 | Anexos do objetivo | Web usa `input type=file`; Flutter precisa picker/camera/galeria. | `processSelectedFile`. | `image_picker`, attachment screens. | PRECISA_EQUIVALENTE_MOBILE | SIM | Mobile nao deve exigir UX web. |
| 37 | 8 | Anexos do objetivo | Web guarda metadados `name/type/size/text`; Flutter pode guardar bytes/data diferente. | `Attachment` type. | Dart attachment models/client. | POSSIVEL_GAP_FUNCIONAL | SIM | Risco de payload diferente. |
| 38 | 8 | Anexos do objetivo | Web remove anexo por indice na lista; Flutter UI precisa acao equivalente. | `handleRemoveAttachment`. | onboarding widgets. | PRECISA_PROVA | PROVA | Validar botao remover. |
| 39 | 8 | Anexos do objetivo | Web aceita PDF/imagem conforme browser; Flutter depende permissao/plataforma. | file inputs. | mobile permissions/picker. | PRECISA_EQUIVALENTE_MOBILE | SIM | Teste em APK real. |
| 40 | 8 | Anexos do objetivo | Web mostra estado por anexo processado; Flutter pode simplificar. | cards/rows objetivo. | onboarding UI. | PRECISA_IGUALAR | SIM | Aluno precisa saber o que entrou. |
| 41 | 9 | Processamento de anexos | Web processa PDF com `pdfjs-dist`; Flutter envia para API. | `attachments.server.ts`. | `sim_server_attachment_client.dart`. | ARQUITETURA_DIFERENTE_OK | NAO | Correto: app nao processa pesado local. |
| 42 | 9 | Processamento de anexos | Web rejeita audio em attachments; Flutter precisa mesma restricao/mensagem. | `processAttachmentOnServer`. | attachment client/UI. | PRECISA_IGUALAR | SIM | Contrato de formatos deve bater. |
| 43 | 9 | Processamento de anexos | Web imagem usa vision no servidor Web; app usa API SIM. | `attachments.functions.ts`. | `/api/process-attachment`. | ARQUITETURA_DIFERENTE_OK | NAO | Backend separado. |
| 44 | 9 | Processamento de anexos | Web logs/erros ficam no server function; Flutter recebe HTTP status. | ServerFn throw. | API client errors. | PRECISA_IGUALAR | SIM | Mensagens de erro devem ser equivalentes. |
| 45 | 9 | Processamento de anexos | Web comprime/normaliza imagem em browser para duvida; objetivo pode usar server. | `compress-image.ts`. | Dart image handling. | PRECISA_PROVA | PROVA | Tamanho maximo precisa prova. |
| 46 | 10 | Preparacao da aula | Web usa `SimPreparationExperience` React; Flutter tem widget portado. | `SimPreparationExperience.tsx`. | `sim_preparation_experience.dart`. | PRECISA_PROVA | PROVA | Precisa screenshot. |
| 47 | 10 | Preparacao da aula | Web stage vem de `StudentExperienceRouteStage`; Flutter stage vem da sessao. | `stageToPrepStage`. | `LabSession`/preparation screens. | ARQUITETURA_DIFERENTE_OK | NAO | Mapeamento distinto. |
| 48 | 10 | Preparacao da aula | Web pode entrar via rota curriculo; Flutter por estado de app. | `/cyber/curriculo`. | navigation state. | ARQUITETURA_DIFERENTE_OK | NAO | Mobile sem URL. |
| 49 | 10 | Preparacao da aula | Web copy/loading usa rota/entry; Flutter usa runtime/session. | React route. | Dart session. | PRECISA_IGUALAR | SIM | Texto do aluno deve ser equivalente. |
| 50 | 10 | Preparacao da aula | Web prepara sem bloquear imagem/audio; Flutter precisa manter regra. | `prepareStudentExperienceEntry`. | `StudentExperienceEngine`. | RISCO_DE_REGRESSAO | SIM | Critico para entrada na sala. |
| 51 | 11 | T00 payload | Web monta bootstrap payload em TS; Flutter monta payload Dart/API. | `bootstrapPayload.ts`. | `bootstrap_payload.dart`. | PRECISA_PROVA | PROVA | Comparar JSON real. |
| 52 | 11 | T00 payload | Web inclui contexto de rota/onboarding direto; Flutter usa prefs/session. | `StudentExperienceT00Adapter.ts`. | `student_experience_t00_adapter.dart`. | ARQUITETURA_DIFERENTE_OK | NAO | Fonte diferente. |
| 53 | 11 | T00 payload | API exige `ficha.free_text` >= 10; Web antigo pode validar antes. | API `bootstrap-controller.js`. | Flutter objetivo input. | PRECISA_IGUALAR | SIM | Erro deve aparecer antes/claramente. |
| 54 | 11 | T00 payload | Web pode incluir attachments text no onboarding; Flutter depende de client. | objetivo/anexos. | attachment client. | POSSIVEL_GAP_FUNCIONAL | SIM | Risco de T00 sem material. |
| 55 | 11 | T00 payload | Web linguagem usa campos `language/stableLang/idioma`; API normaliza; Flutter precisa alinhar. | T00 controller. | Dart request. | RISCO_DE_REGRESSAO | SIM | Pode gerar aula no idioma errado. |
| 56 | 12 | T00 streaming/SSE | Web stream client roda no browser/server context; Flutter usa stream HTTP. | `bootstrapStreamClient.ts`. | `SimHttpTransport.postEventStream`. | ARQUITETURA_DIFERENTE_OK | NAO | Meio diferente. |
| 57 | 12 | T00 streaming/SSE | API envia heartbeat `: hb`; Flutter parser precisa ignorar. | `bootstrap-controller.js`. | T00 client/parser. | PRECISA_PROVA | PROVA | Provar stream real. |
| 58 | 12 | T00 streaming/SSE | Web resolve no primeiro parcial pelo adapter; Flutter deve resolver igual. | `startT00UntilFirstItem`. | Dart adapter. | PRECISA_IGUALAR | SIM | Critico fast path. |
| 59 | 12 | T00 streaming/SSE | API finaliza SSE; Web trata close browser; Flutter deve tratar cancelamento. | req `close`. | stream Dart. | POSSIVEL_GAP_FUNCIONAL | SIM | Risco travamento. |
| 60 | 12 | T00 streaming/SSE | Web logs eventos localmente; app precisa requestId/log para diagnostico. | console/eventos. | API/app logs. | PRECISA_PROVA | PROVA | Diagnostico real exigido. |
| 61 | 13 | Curriculo gerado | Web usa `CyberCurriculoItem`; Flutter usa `CurriculumItem`. | `state-director.ts`. | `student_experience_types.dart`. | ARQUITETURA_DIFERENTE_OK | NAO | Tipos distintos. |
| 62 | 13 | Curriculo gerado | Web dedupe/mapeia parcial via writer TS; Flutter writer Dart. | `partialCurriculumWriter.ts`. | `partial_curriculum_writer.dart`. | PRECISA_PROVA | PROVA | Provar equivalencia de campos. |
| 63 | 13 | Curriculo gerado | Web pode manter curriculo final em cyber state; Flutter espelha no StudentLearningState. | `clearCurriculo/cyberLessons`. | `StudentLearningState.curriculum`. | ARQUITETURA_DIFERENTE_OK | NAO | Arquitetura do app. |
| 64 | 13 | Curriculo gerado | API parseia T00 e emite itens; Flutter depende do formato SSE. | `t00-bootstrap-parser.ts`, API controller. | T00 adapter Dart. | RISCO_DE_REGRESSAO | SIM | Mudanca no parser quebra app. |
| 65 | 13 | Curriculo gerado | Web resumo/historico usa `totalItems`; Flutter calcula pelo state. | drawer summaries. | drawer local states. | POSSIVEL_GAP_FUNCIONAL | SIM | Dedupe/progresso pode divergir. |
| 66 | 14 | Ficha do aluno | Web mapeia profile em T00 profile writer; Flutter porta esse mapa. | `t00ProfileWriter.ts`. | `t00_profile_writer.dart`. | PRECISA_PROVA | PROVA | Conferir `guidance_for_T02`. |
| 67 | 14 | Ficha do aluno | API tambem mapeia `PROFILE` no servidor; Web tem mapper proprio. | API `bootstrap-controller.js`. | Flutter consome profile emitido. | ARQUITETURA_DIFERENTE_OK | NAO | Camada server centraliza. |
| 68 | 14 | Ficha do aluno | Web usa `StudentProfileService`; Flutter integra no state. | `StudentProfileService.ts`. | `StudentLearningState`. | ARQUITETURA_DIFERENTE_OK | NAO | Modelagem diferente. |
| 69 | 14 | Ficha do aluno | Campos `review_strategy/recovery_strategy` precisam sobreviver ao app. | Web profile mapper. | Dart state/profile. | PRECISA_IGUALAR | SIM | Afeta pedagogia. |
| 70 | 14 | Ficha do aluno | Web father panel le snapshot; Flutter status export mais simples. | `S14_FatherPanel`. | `buildDrawerStatusText`. | POSSIVEL_GAP_FUNCIONAL | SIM | Painel pode perder diagnostico. |
| 71 | 15 | Fast path primeira aula | Web chama T02 imediatamente apos primeiro item. | `StudentExperienceEngine.ts`. | Dart `StudentExperienceEngine`. | PRECISA_PROVA | PROVA | Teste e log real. |
| 72 | 15 | Fast path primeira aula | Web navega para aula enquanto T00 continua; Flutter deve nao aguardar final. | Web adapters. | `organism_vital_flow_test`. | RISCO_DE_REGRESSAO | SIM | Critico aluno entrar. |
| 73 | 15 | Fast path primeira aula | Web guarda material no live entry/cache; Flutter em current material/state. | `studentLiveEntryState.ts`. | `live_entry_state.dart`. | ARQUITETURA_DIFERENTE_OK | NAO | Estado diferente. |
| 74 | 15 | Fast path primeira aula | Web tem browser event/recover visible; Flutter usa listeners session. | `useLessonRuntimeEngine`. | `AulaLabScreen._onSessionChange`. | POSSIVEL_GAP_FUNCIONAL | SIM | Retomada pode divergir. |
| 75 | 15 | Fast path primeira aula | Web background continuity chama janela; Flutter usa worker/engine Dart. | `maintainBackgroundContinuity`. | `dopamine_ready_window_engine.dart`. | PRECISA_PROVA | PROVA | Provar B/C background. |
| 76 | 16 | T02 payload aula normal | Web `CompleteLessonParams` TS; Flutter `CompleteLessonParams` Dart. | `lesson-types.ts`. | `lesson_models.dart`. | PRECISA_PROVA | PROVA | Comparar campos reais. |
| 77 | 16 | T02 payload aula normal | Web envelope pedagogico pega profile strings; Flutter `_buildPedagogicalEnvelope`. | `StudentExperienceT02Adapter.ts`. | `student_experience_t02_adapter.dart`. | PRECISA_IGUALAR | SIM | Campos ricos precisam bater. |
| 78 | 16 | T02 payload aula normal | API `complete-lesson` valida resource owner; Web ServerFn nao usa mesmo owner file. | Web module caller. | API `resource-owners.js`. | ARQUITETURA_DIFERENTE_OK | NAO | Seguranca extra no app. |
| 79 | 16 | T02 payload aula normal | Web pode passar `mode` string; Flutter usa enum/strings. | `LessonMode`. | `LessonMode` Dart. | POSSIVEL_GAP_FUNCIONAL | SIM | Serializacao deve bater. |
| 80 | 16 | T02 payload aula normal | Web history e academic strings podem diferir do app. | helpers/runtime. | request builder Dart. | RISCO_DE_REGRESSAO | SIM | Afeta qualidade da aula. |
| 81 | 17 | T02 resposta/contrato | Web valida T02 contract em TS; API/Flutter parseiam contrato separado. | `validateT02Contract`. | `lesson_content_validator.dart`, API. | PRECISA_IGUALAR | SIM | Contrato deve ser unico. |
| 82 | 17 | T02 resposta/contrato | Web aceita visual_trigger detalhado; Flutter precisa preservar campos. | `visual-trigger.ts`. | `lesson_visual_models.dart`. | POSSIVEL_GAP_FUNCIONAL | SIM | Imagem pode falhar. |
| 83 | 17 | T02 resposta/contrato | Web `Conteudo` TS usa options A/B/C; Flutter usa Map enum. | `lesson-types.ts`. | `LessonContent`. | ARQUITETURA_DIFERENTE_OK | NAO | Tipo diferente, contrato igual. |
| 84 | 17 | T02 resposta/contrato | Web tolera JSON markdown; Flutter depende API limpar/normalizar. | `tolerantJsonParse`. | API client/model. | PRECISA_PROVA | PROVA | Provar resposta Gemini real. |
| 85 | 17 | T02 resposta/contrato | Web feedback/visual podem estar na mesma resposta; Flutter separa media. | lesson pipeline. | media services. | ARQUITETURA_DIFERENTE_OK | NAO | Separacao correta. |
| 86 | 18 | Validacao/retry T02 | Web tem `AI_OPERATION_ATTEMPT_LIMIT=3`; Flutter/API retry pode divergir. | `moduleCaller.functions.ts`. | API controllers/client. | PRECISA_IGUALAR | SIM | Politica de retry precisa definida. |
| 87 | 18 | Validacao/retry T02 | Web `runSharedAIOperation` dedupe; Flutter usa inflight/cache Dart/API. | Web module caller. | `lesson_material_cache`, pipeline. | PRECISA_PROVA | PROVA | Provar sem duplicar T02. |
| 88 | 18 | Validacao/retry T02 | Web retorna reason de validacao; Flutter pode exibir erro generico. | validators TS. | Flutter error card. | PRECISA_IGUALAR | SIM | Debug/aluno precisam erro claro. |
| 89 | 18 | Validacao/retry T02 | API retorna `code: T02_ERROR`; Web ServerFn pode throw Error. | API controller. | Flutter client. | ARQUITETURA_DIFERENTE_OK | NAO | Contrato HTTP separado. |
| 90 | 18 | Validacao/retry T02 | Web fallback Lovable existe; Flutter nao deve usar Lovable. | `lovable-ai-call.ts`. | API SIM. | WEB_ONLY_NAO_APLICAVEL | NAO | Diferenca intencional. |
| 91 | 19 | Layers L1/L2/L3 | Web layer numeric/string; Flutter usa `LessonLayer` enum. | helpers TS. | `classroom_models.dart`. | ARQUITETURA_DIFERENTE_OK | NAO | Melhor tipagem no Flutter. |
| 92 | 19 | Layers L1/L2/L3 | Web review layer embutido no PlannedItem; Flutter tambem, mas enum. | `PlannedItem`. | `PlannedItem` Dart. | PRECISA_PROVA | PROVA | Provar L2/L3 reais. |
| 93 | 19 | Layers L1/L2/L3 | Web mode `reforco/session`; Flutter enum serializa para API. | lesson runtime. | lesson models. | POSSIVEL_GAP_FUNCIONAL | SIM | Serializacao pode divergir. |
| 94 | 19 | Layers L1/L2/L3 | Web next slot calcula com helper TS; Flutter helper Dart duplicado. | `nextLessonSlot`. | Dart `nextLessonSlot`. | RISCO_DE_REGRESSAO | SIM | Drift logico possivel. |
| 95 | 19 | Layers L1/L2/L3 | Web camada visual no header/label; Flutter pode truncar label em 82px. | `headerLabel` span. | `AulaTopBar`. | PRECISA_EQUIVALENTE_MOBILE | SIM | UI mobile nao deve ocultar contexto. |
| 96 | 20 | Resposta A/B/C | Web usa buttons HTML disabled; Flutter usa GestureDetector/estado. | `QuestionBlock.tsx`. | aula widgets. | ARQUITETURA_DIFERENTE_OK | NAO | Plataforma diferente. |
| 97 | 20 | Resposta A/B/C | Web estilo selecionado usa CSS vars; Flutter usa `simDark`/BoxDecoration. | `QuestionBlock`. | `_AuxOptionTile`/AnswerButton. | PRECISA_PROVA | PROVA | Screenshot/tap real. |
| 98 | 20 | Resposta A/B/C | Web historico mostra ok/x dentro botao; Flutter historico pode render diferente. | answered block. | `_QuestionHistoryBlock`. | PRECISA_IGUALAR | SIM | Feedback visual deve ser claro. |
| 99 | 20 | Resposta A/B/C | Web trava pergunta respondida por `pointer-events-none`; Flutter `IgnorePointer`. | CSS. | `IgnorePointer`. | ARQUITETURA_DIFERENTE_OK | NAO | Equivalente. |
| 100 | 20 | Resposta A/B/C | Web hover/active scale; Flutter press/touch pode nao ter mesma microinteracao. | CSS active. | GestureDetector/PressScale. | PRECISA_EQUIVALENTE_MOBILE | SIM | Feedback de toque mobile. |
| 101 | 21 | Sinalizadores 1/2/3 | Web `SinalBtn` recebe numero direto; Flutter usa enum `DecisionSignal`. | components TS. | Dart enum. | ARQUITETURA_DIFERENTE_OK | NAO | Tipagem correta. |
| 102 | 21 | Sinalizadores 1/2/3 | Web indicadores aparecem com fade-in; Flutter sem fade explicito. | `animate-in fade-in`. | Row/Container. | PRECISA_EQUIVALENTE_MOBILE | SIM | Microinteracao diferente. |
| 103 | 21 | Sinalizadores 1/2/3 | Web usa layout border-left com gap CSS; Flutter usa Padding/Border. | AuxQuestionScreen. | `_AuxOptionTile`. | PRECISA_PROVA | PROVA | Posicao precisa captura. |
| 104 | 21 | Sinalizadores 1/2/3 | Web chama sinal e muda phase por hook; Flutter chama session/controller. | `onSignal`. | `session`/controller. | ARQUITETURA_DIFERENTE_OK | NAO | Orquestracao diferente. |
| 105 | 21 | Sinalizadores 1/2/3 | Web texto dos sinais vem i18n TS; Flutter vem `sim_i18n.dart`. | `t(...)`. | `t(...)` Dart. | PRECISA_IGUALAR | SIM | Textos devem bater. |
| 106 | 22 | Motor de decisao pedagogica | Web `learningDecisionEngine.ts`; Flutter `learning_decision_engine.dart`. | TS engine. | Dart engine. | PRECISA_PROVA | PROVA | Port precisa teste comparativo. |
| 107 | 22 | Motor de decisao pedagogica | Web executor processa attempt em store TS; Flutter executor em state service. | `studentLessonExecutor.ts`. | `student_lesson_executor.dart`. | ARQUITETURA_DIFERENTE_OK | NAO | Porta logica em outro estado. |
| 108 | 22 | Motor de decisao pedagogica | Web flags review/recovery em types TS; Flutter flags separadas. | `studentLearningState.types.ts`. | `student_learning_state.dart`. | RISCO_DE_REGRESSAO | SIM | Flags podem sair de sincronia. |
| 109 | 22 | Motor de decisao pedagogica | Flutter tem `MasteryTruthEngine` extra. | Web decision engine. | `mastery_truth_engine.dart`. | FLUTTER_MELHOR | NAO | Estrutura mais explicita no app. |
| 110 | 22 | Motor de decisao pedagogica | Web debug state existe; Flutter governadores internos. | `studentLearningState.debug.ts`. | `internal_organs_governor.dart`. | ARQUITETURA_DIFERENTE_OK | NAO | Diagnostico diferente. |
| 111 | 23 | Feedback da aula | Web `FeedbackBox` compartilha componentes; Flutter tem widgets proprios. | `components.tsx`. | feedback widgets/controllers. | PRECISA_PROVA | PROVA | Visual precisa screenshot. |
| 112 | 23 | Feedback da aula | Web feedback usa strings diretas/TS; Flutter pode usar chaves i18n. | `lessonAnswerFeedback.ts`. | `lesson_answer_feedback.dart`. | PRECISA_IGUALAR | SIM | Mensagem final deve bater. |
| 113 | 23 | Feedback da aula | Web botao avancar no feedback rola para visivel; Flutter rola por controller. | `completedAdvanceRef`. | `ScrollController`. | POSSIVEL_GAP_FUNCIONAL | SIM | Pode sumir abaixo da dobra. |
| 114 | 23 | Feedback da aula | Web feedback correto/erro com CSS vars; Flutter cores fixas. | `FeedbackBox`. | `_AuxFeedbackBox`. | PRECISA_EQUIVALENTE_MOBILE | SIM | Visual deve ser equivalente. |
| 115 | 23 | Feedback da aula | Web historico guarda imagem no entry; Flutter corta imagem antiga. | `QuestionHistoryEntry`. | image cutoff last 4. | DECISAO_HUMANA_NECESSARIA | DECISAO | Decidir memoria vs paridade. |
| 116 | 24 | Conclusao da aula | Web usa estados done em aux/main; Flutter `LessonDoneScreen`. | `AuxRoomScreens.tsx`. | `LessonDoneScreen`. | PRECISA_PROVA | PROVA | Precisa captura final. |
| 117 | 24 | Conclusao da aula | Web final pode ser bloqueado por recovery gate; Flutter tem gate Dart. | `lessonRecoveryGate.ts`. | `lesson_recovery_gate.dart`. | PRECISA_PROVA | PROVA | Testar bloqueio real. |
| 118 | 24 | Conclusao da aula | Web navega para proxima/rota; Flutter chama session/support. | route navigation. | `session.openSupport`. | ARQUITETURA_DIFERENTE_OK | NAO | Mobile route diferente. |
| 119 | 24 | Conclusao da aula | Web status final no father panel; Flutter status text simplificado. | fatherPanel. | `buildDrawerStatusText`. | POSSIVEL_GAP_FUNCIONAL | SIM | Pode faltar prova para responsavel. |
| 120 | 24 | Conclusao da aula | Web mantem history e progresso em cyberLessons; Flutter no StudentLearningState. | cyber state. | state service. | ARQUITETURA_DIFERENTE_OK | NAO | Fonte diferente. |
| 121 | 25 | Estado do aluno | Web usa interface TS grande; Flutter usa classes Dart. | `studentLearningState.types.ts`. | `student_learning_state.dart`. | ARQUITETURA_DIFERENTE_OK | NAO | Tipagem diferente. |
| 122 | 25 | Estado do aluno | Web tem mirror utilities; Flutter tem store adapter/foundation. | `studentLearningState.mirror.ts`. | `student_state_store_adapter.dart`. | POSSIVEL_GAP_FUNCIONAL | SIM | Campos espelhados podem divergir. |
| 123 | 25 | Estado do aluno | Web snapshot cloud mantem hash/limite; API guarda JSON local. | cloud functions. | API `.data/student-states.json`. | ARQUITETURA_DIFERENTE_OK | NAO | Infra diferente. |
| 124 | 25 | Estado do aluno | Flutter tem governadores `student_learning_governor`; Web nao igual. | Web store. | governor Dart. | FLUTTER_MELHOR | NAO | Diagnostico organico extra. |
| 125 | 25 | Estado do aluno | Eventos do Web e Flutter podem ter nomes/campos distintos. | `StudentLearningEventType`. | `StudentLearningEvent`. | RISCO_DE_REGRESSAO | SIM | Afeta sync/import/export. |
| 126 | 26 | Persistencia local | Web usa localStorage/sessionStorage. | browser storage. | SharedPreferences/files. | ARQUITETURA_DIFERENTE_OK | NAO | Plataforma distinta. |
| 127 | 26 | Persistencia local | Web tem migracoes tecnicas no root/objetivo; Flutter nao igual. | `runTechnicalCacheMigration`. | SharedPrefs storage. | POSSIVEL_GAP_FUNCIONAL | SIM | Usuario antigo pode sofrer. |
| 128 | 26 | Persistencia local | Web `cyberLessons` guarda lessons; Flutter canonical store guarda states. | state-director. | `StudentStateStore`. | ARQUITETURA_DIFERENTE_OK | NAO | Modelo distinto. |
| 129 | 26 | Persistencia local | Flutter tem backup via arquivo tmp/clipboard; Web baixa arquivo. | drawer export. | `writeDrawerBackupFile`. | PRECISA_EQUIVALENTE_MOBILE | SIM | UX mobile ainda diferente. |
| 130 | 26 | Persistencia local | Web sessionStorage fresh lesson seed; Flutter usa session listeners/state. | `useLessonHydrationEngine`. | `AulaLabScreen`. | POSSIVEL_GAP_FUNCIONAL | SIM | Retomada apos kill app precisa prova. |
| 131 | 27 | Sync/nuvem | Web usa Supabase ServerFns/React Query. | `sim/cloud/lessons.functions.ts`. | API student-state endpoints. | ARQUITETURA_DIFERENTE_OK | NAO | Backend separado. |
| 132 | 27 | Sync/nuvem | Web tem `useSimRealtime`; Flutter nao tem realtime equivalente completo. | `useSimRealtime.ts`. | cloud services Dart. | POSSIVEL_GAP_FUNCIONAL | SIM | Atualizacao multi-dispositivo. |
| 133 | 27 | Sync/nuvem | Web invalida queries; Flutter atualiza listas manualmente. | React Query. | `_refreshCloudLessons`. | PRECISA_EQUIVALENTE_MOBILE | SIM | UX deve atualizar sem confusao. |
| 134 | 27 | Sync/nuvem | Web puxa cloud ao online/visible; Flutter lifecycle diferente. | `cloudPull.ts`, `useSimRealtime`. | `student_learning_sync.dart`. | PRECISA_PROVA | PROVA | Provar retomada. |
| 135 | 27 | Sync/nuvem | API app usa resource-owner security por lesson/media; Web nao tem mesmo arquivo. | `resource-owners.js`. | App/API. | FLUTTER_MELHOR | NAO | Seguranca adicional. |
| 136 | 28 | Multi-dispositivo | Web realtime propaga mudancas entre abas/dispositivos. | Supabase channel. | Flutter sem listener realtime comprovado. | POSSIVEL_GAP_FUNCIONAL | SIM | Pode nao atualizar sozinho. |
| 137 | 28 | Multi-dispositivo | Web browser visibility dispara pull; app mobile precisa app lifecycle. | `visibilitychange`. | Sem equivalente claro. | PRECISA_EQUIVALENTE_MOBILE | SIM | Implementar/provar lifecycle. |
| 138 | 28 | Multi-dispositivo | Web dedupe query cache; Flutter precisa dedupe cloud/local. | React Query. | drawer dedupe. | PRECISA_PROVA | PROVA | Provar aulas nao duplicam. |
| 139 | 28 | Multi-dispositivo | Web cloud id cache por metadata; Flutter guarda ids no store/API. | `studentLearningCloudMeta`. | cloud storage Dart. | ARQUITETURA_DIFERENTE_OK | NAO | Modelo distinto. |
| 140 | 28 | Multi-dispositivo | App pode ficar offline mobile; Web usa online event. | Browser events. | Sem connectivity prova. | POSSIVEL_GAP_FUNCIONAL | SIM | Offline queue precisa validacao. |
| 141 | 29 | Conflitos/tombstone | Web remove local mirror e tombstone no delete cloud. | `removeLocalMirrorFor`. | `deleteDrawerCloudLesson`. | PRECISA_PROVA | PROVA | Provar nao ressuscita. |
| 142 | 29 | Conflitos/tombstone | Web lista deleted local ids em cloud functions. | `listDeletedSimLessonLocalIds`. | API student-state delete. | POSSIVEL_GAP_FUNCIONAL | SIM | Contrato nao identico. |
| 143 | 29 | Conflitos/tombstone | Web delete local-first com refetch; Flutter delete local/cloud em session. | `deleteLesson`. | session delete methods. | ARQUITETURA_DIFERENTE_OK | NAO | Implementacao diferente. |
| 144 | 29 | Conflitos/tombstone | Web dedupe tambem por tema; Flutter dedupe principal por lessonLocalId. | AulaDrawer cloud/local. | `_cloudOnly` localIds. | POSSIVEL_GAP_FUNCIONAL | SIM | Pode duplicar aula com id diferente. |
| 145 | 29 | Conflitos/tombstone | API resource-owner impede acesso cruzado; Web Supabase RLS/ServerFn. | API security. | app cloud functions. | FLUTTER_MELHOR | NAO | Defesa extra na API. |
| 146 | 30 | Cache de aula/T02 | Web `lesson-material-cache.ts`; Flutter `lesson_material_cache.dart`. | TS cache. | Dart cache. | PRECISA_PROVA | PROVA | TTL/LRU precisam teste real. |
| 147 | 30 | Cache de aula/T02 | Web `textInflight`/shared operations; Flutter background semaphore/cache. | `lesson-pipeline-runtime.ts`. | `lesson_pipeline_runtime.dart`. | PRECISA_PROVA | PROVA | Sem T02 duplicado. |
| 148 | 30 | Cache de aula/T02 | Web cache pode notificar subscribers; Flutter usa event bus/state. | `subscribeLesson`. | `lesson_event_bus.dart`. | ARQUITETURA_DIFERENTE_OK | NAO | Notificacao diferente. |
| 149 | 30 | Cache de aula/T02 | Web `peekCachedLesson`; Flutter cache object. | runtime TS. | cache Dart. | POSSIVEL_GAP_FUNCIONAL | SIM | API de cache pode divergir. |
| 150 | 30 | Cache de aula/T02 | Limite 3/TTL 24h precisa prova no APK. | Web runtime/cache. | Dart cache tests. | PRECISA_PROVA | PROVA | Criterio critico. |
| 151 | 31 | Janela dopaminica | Web `ensureLessonWindow` coordena A/B/C; Flutter engine Dart. | `lesson-pipeline-runtime.ts`. | `dopamine_ready_window_engine.dart`. | PRECISA_PROVA | PROVA | Background real. |
| 152 | 31 | Janela dopaminica | Web background text chain/semaphore; Flutter `BackgroundTextSemaphore`. | runtime TS. | runtime Dart. | ARQUITETURA_DIFERENTE_OK | NAO | Port diferente. |
| 153 | 31 | Janela dopaminica | Web imagem nao bloqueia texto; Flutter precisa manter. | scheduleImage. | media services. | RISCO_DE_REGRESSAO | SIM | Pode travar aula. |
| 154 | 31 | Janela dopaminica | Web `markInitialLessonsReady`; Flutter equivalente pode divergir. | runtime TS. | runtime Dart. | POSSIVEL_GAP_FUNCIONAL | SIM | Estado inicial sensivel. |
| 155 | 31 | Janela dopaminica | Web garante idle por polling; Flutter usa futures/controllers. | `whenLessonIdle`. | Dart async. | PRECISA_PROVA | PROVA | Provar sem corrida. |
| 156 | 32 | Imagem da aula | Web renderiza imagem via browser `<img>`/data URL. | LessonMain/image pipeline. | `Image.memory`, `SvgPicture`, network. | ARQUITETURA_DIFERENTE_OK | NAO | Renderizacao por plataforma. |
| 157 | 32 | Imagem da aula | Web compressao canvas; Flutter pacote `image`. | `compress-image.ts`. | `image_data_url_compression.dart`. | PRECISA_PROVA | PROVA | Resultado/tamanho pode diferir. |
| 158 | 32 | Imagem da aula | Web visual router functions server/browser; Flutter visual router Dart/API. | `visual-router.functions.ts`. | `visual_router_n2/n3.dart`. | POSSIVEL_GAP_FUNCIONAL | SIM | Drift de prompts/visual. |
| 159 | 32 | Imagem da aula | Web erro imagem via `onImageError`; Flutter icone broken/texto. | `<img onError>`. | `LessonImagePanel`. | PRECISA_EQUIVALENTE_MOBILE | SIM | UX de erro deve bater. |
| 160 | 32 | Imagem da aula | Flutter suporta SVG string via package; Web SVG no browser. | `<img>`/SVG. | `SvgPicture.string`. | ARQUITETURA_DIFERENTE_OK | NAO | Correto, precisa prova. |
| 161 | 33 | Imagem paga | Web `PaidImageOfferCard`; Flutter painel integrado. | `PaidImageOfferCard`. | `LessonImagePanel`. | PRECISA_EQUIVALENTE_MOBILE | SIM | Layout diferente. |
| 162 | 33 | Imagem paga | API reserva/captura credito de media; Web usa ServerFn/credits. | `PaidImageService`. | API `image-controller.js`. | ARQUITETURA_DIFERENTE_OK | NAO | Backend separado. |
| 163 | 33 | Imagem paga | Web evento `sim:insufficient-credits`; Flutter chama compra por session. | Web paid offer. | Flutter `buyImageCredits`. | POSSIVEL_GAP_FUNCIONAL | SIM | Fluxo de compra pode divergir. |
| 164 | 33 | Imagem paga | API tem resource-owner/cache para imagem. | Web service. | `resource-owners.js`, image cache. | FLUTTER_MELHOR | NAO | Seguranca/cache extra. |
| 165 | 33 | Imagem paga | Texto de custo/saldo no Flutter pode nao bater com Web. | Web offer card. | `aula_img_cost/balance`. | PRECISA_IGUALAR | SIM | Aluno precisa entender custo. |
| 166 | 34 | Audio da aula | Web usa browser/audio core; Flutter usa adapter/TTS/mobile playback. | `audio.ts`. | `audio_core.dart`, `platform_audio_adapter.dart`. | PRECISA_EQUIVALENTE_MOBILE | SIM | Plataforma diferente. |
| 167 | 34 | Audio da aula | API gera TTS Gemini; Web route/ServerFn tinha outro caminho. | `generate-lesson-audio.ts`. | API `audio-controller.js`. | ARQUITETURA_DIFERENTE_OK | NAO | Servidor app separado. |
| 168 | 34 | Audio da aula | Preferencia Web em localStorage; Flutter SharedPreferences. | `audio-preference.ts`. | `audio_preference.dart`. | ARQUITETURA_DIFERENTE_OK | NAO | Persistencia por plataforma. |
| 169 | 34 | Audio da aula | Web pode usar Audio API; Flutter usa player/TTS. | Browser Audio. | platform adapter. | PRECISA_PROVA | PROVA | Provar APK toca/para. |
| 170 | 34 | Audio da aula | Erro audio Web pode cair silencioso; Flutter tem fallback local TTS em teste. | Web audio controller. | media tests. | FLUTTER_MELHOR | NAO | Fallback mobile e positivo. |
| 171 | 35 | Bolha/indicador de audio | Web `FixedBubble` React; Flutter widget equivalente. | `FixedBubble.tsx`. | `fixed_bubble.dart`. | PRECISA_PROVA | PROVA | Precisa screenshot. |
| 172 | 35 | Bolha/indicador de audio | Web posicionamento CSS fixed; Flutter overlay/widget position. | CSS fixed. | Stack/Flutter widget. | PRECISA_EQUIVALENTE_MOBILE | SIM | Posicao deve nao cobrir conteudo. |
| 173 | 35 | Bolha/indicador de audio | Web icones lucide; Flutter Material icons. | lucide. | Icons. | PRECISA_EQUIVALENTE_MOBILE | SIM | Visual diferente. |
| 174 | 35 | Bolha/indicador de audio | Web estado `falando`; Flutter usa audio controller/session. | prop. | session/audio state. | ARQUITETURA_DIFERENTE_OK | NAO | Fonte diferente. |
| 175 | 35 | Bolha/indicador de audio | Flutter precisa respeitar SafeArea; Web nao tem nav bar Android. | viewport. | SafeArea. | PRECISA_PROVA | PROVA | Provar em celular. |
| 176 | 36 | Duvida por texto | Web textarea limita 1200 chars e mostra contador. | `DoubtInputSheet.tsx`. | Flutter doubt input model/sheet. | PRECISA_IGUALAR | SIM | Limite/contador devem bater. |
| 177 | 36 | Duvida por texto | Web sheet shadcn bottom; Flutter modal bottom sheet. | `SheetContent side=bottom`. | `showModalBottomSheet`. | PRECISA_EQUIVALENTE_MOBILE | SIM | Visual/altura diferente. |
| 178 | 36 | Duvida por texto | Web erro vazio string fixa; Flutter constants Dart. | `emptyDoubtMessage`. | `doubt_input_sheet.dart`. | PRECISA_IGUALAR | SIM | Texto deve bater. |
| 179 | 36 | Duvida por texto | Web submit limpa estado local; Flutter limpa controller e fecha sheet. | `submit`. | `_showDoubtSheet`. | ARQUITETURA_DIFERENTE_OK | NAO | Fluxo aceitavel. |
| 180 | 36 | Duvida por texto | Web progress label TS; Flutter `doubtProgressLabel`. | `useLessonDoubtController`. | `lesson_doubt_controller.dart`. | PRECISA_PROVA | PROVA | Provar estados processando/erro. |
| 181 | 37 | Duvida com foto | Web usa `input capture=environment`; Flutter usa `image_picker`. | `cameraRef`. | `image_picker`. | PRECISA_EQUIVALENTE_MOBILE | SIM | Mobile deve abrir camera real. |
| 182 | 37 | Duvida com foto | Web galeria via hidden input; Flutter picker de galeria. | `galleryRef`. | picker. | PRECISA_EQUIVALENTE_MOBILE | SIM | UX diferente. |
| 183 | 37 | Duvida com foto | Web compressa antes de enviar; Flutter validacao/model deve comprimir equivalente. | `compressImageDataUrl`. | `DoubtInputDraft`, image utils. | PRECISA_PROVA | PROVA | Tamanho max 8MB. |
| 184 | 37 | Duvida com foto | Web payload inclui name/type/size/dataUrl; Flutter class semelhante. | `DoubtImageInput`. | `DoubtImagePayload`. | PRECISA_IGUALAR | SIM | Contrato deve bater. |
| 185 | 37 | Duvida com foto | Web Paperclip abre menu absoluto; Flutter sheet/menu mobile. | Paperclip menu. | bottom sheet controls. | PRECISA_EQUIVALENTE_MOBILE | SIM | Comportamento diferente. |
| 186 | 38 | Revisao | Web `ReviewRoomScreen` React; Flutter `ReviewRoomScreen`. | `AuxRoomScreens.tsx`. | `aux_room_screens.dart`. | PRECISA_PROVA | PROVA | Captura visual. |
| 187 | 38 | Revisao | Web choose card usa glass/gradiente; Flutter usa container/botoes solidos. | review choose. | Dart choose screen. | PRECISA_EQUIVALENTE_MOBILE | SIM | Visual diferente. |
| 188 | 38 | Revisao | Web count 5/10 direto; Flutter seta status preparing na session. | `onStart`. | `setReviewRoom`. | ARQUITETURA_DIFERENTE_OK | NAO | Orquestracao diferente. |
| 189 | 38 | Revisao | Web progress header CSS; Flutter SafeArea/header. | AuxQuestionScreen. | `_AuxQuestionScreen`. | PRECISA_EQUIVALENTE_MOBILE | SIM | Layout diferente. |
| 190 | 38 | Revisao | Web usa mesmo `SinalBtn`; Flutter `_SinalBtn` proprio. | components. | Dart widget. | PRECISA_PROVA | PROVA | Interacao real. |
| 191 | 39 | Recuperacao | Web `RecoveryRoomView` status intro/preparing/etc.; Flutter enum/class. | TS type. | `RecoveryRoomStatus`. | ARQUITETURA_DIFERENTE_OK | NAO | Tipagem diferente. |
| 192 | 39 | Recuperacao | Web recovery pode bloquear final; Flutter service/gate separado. | `RecoveryRoomService.ts`. | `recovery_room_service.dart`. | PRECISA_PROVA | PROVA | Provar bloqueio/desbloqueio. |
| 193 | 39 | Recuperacao | Web intro screen em React; Flutter screen propria. | AuxRoomScreens. | RecoveryRoomScreen. | PRECISA_EQUIVALENTE_MOBILE | SIM | Visual diferente. |
| 194 | 39 | Recuperacao | Web queue deriva de pending markers TS; Flutter service Dart. | `buildRecoveryQueue`. | `buildRecoveryQueue`. | RISCO_DE_REGRESSAO | SIM | Drift pode afetar recuperacao. |
| 195 | 39 | Recuperacao | Flutter tem restartRequired no model; Web type pode divergir. | RecoveryRoomView. | `RecoveryRoomView.restartRequired`. | POSSIVEL_GAP_FUNCIONAL | SIM | Estado extra precisa mapeamento. |
| 196 | 40 | Amparo | Web `SIM_AUX_ROOMS_ENABLED=false` mas tipos/servicos existem. | TS flags/services. | Dart aux/amparo controller. | DECISAO_HUMANA_NECESSARIA | DECISAO | Definir se amparo entra na paridade. |
| 197 | 40 | Amparo | Flutter tem `AmparoController`; Web aux rooms controller separado. | useAuxRoomsController. | `amparo_controller.dart`. | ARQUITETURA_DIFERENTE_OK | NAO | Orgao proprio no app. |
| 198 | 40 | Amparo | Payload T02 de amparo pode usar addon references diferentes. | `auxRoomT02Caller.ts`. | `aux_room_t02_caller.dart`. | PRECISA_PROVA | PROVA | Comparar payload. |
| 199 | 40 | Amparo | Web UI de amparo depende fluxo aux; Flutter tela aux propria. | AuxRoomScreens. | `AuxRoomCard`, aux screens. | PRECISA_EQUIVALENTE_MOBILE | SIM | Visual/fluxo deve ser decidido. |
| 200 | 40 | Amparo | Flags Web e Flutter podem nao estar sincronizadas. | TS constants. | Dart constants/config. | RISCO_DE_REGRESSAO | SIM | Pode aparecer/desaparecer indevidamente. |
| 201 | 41 | Menu sanduiche/drawer | Web drawer e HTML aside; Flutter dialog/Material. | `AulaDrawer.tsx`. | `showAulaMenu`. | PRECISA_PROVA | PROVA | Screenshot. |
| 202 | 41 | Menu sanduiche/drawer | Web botao export baixa arquivo; Flutter grava tmp e clipboard. | `handleExport`. | `_handleExportBackup`. | PRECISA_EQUIVALENTE_MOBILE | SIM | UX diferente. |
| 203 | 41 | Menu sanduiche/drawer | Web import por file input; Flutter import por colagem. | `handleImportFile`. | `_handleImportBackup`. | PRECISA_IGUALAR | SIM | Gap critico de backup. |
| 204 | 41 | Menu sanduiche/drawer | Web logout limpa QueryClient e localStorage credit cache; Flutter signOutReal. | `handleLogout`. | `_handleLogout`. | POSSIVEL_GAP_FUNCIONAL | SIM | Cache pos-logout. |
| 205 | 41 | Menu sanduiche/drawer | Web usa evento global ao abrir aula; Flutter fecha e muda estado. | `notifyActiveLessonChanged`. | session state. | ARQUITETURA_DIFERENTE_OK | NAO | Mobile sem CustomEvent. |
| 206 | 42 | Historico local/cloud | Web `cyberLessons.listSummaries`; Flutter `listLocalStates`. | state-director. | canonical store. | ARQUITETURA_DIFERENTE_OK | NAO | Fonte diferente. |
| 207 | 42 | Historico local/cloud | Web dedupe cloud/local por id e tema; Flutter por id local. | AulaDrawer. | drawer build. | POSSIVEL_GAP_FUNCIONAL | SIM | Duplicata possivel. |
| 208 | 42 | Historico local/cloud | Web mostra cloud loading por React Query; Flutter carrega manual. | `cloudLoading`. | `_cloudLoading`. | PRECISA_EQUIVALENTE_MOBILE | SIM | Estado visual deve bater. |
| 209 | 42 | Historico local/cloud | Web percentual cloud usa `state.concluidos`; Flutter row.tema/total. | cloud summaries. | StudentStateSummaryRow. | PRECISA_PROVA | PROVA | Percentual correto. |
| 210 | 42 | Historico local/cloud | Web `pullCloudLessons` apos import; Flutter refresh list pode nao puxar igual. | cloudPull. | import session. | POSSIVEL_GAP_FUNCIONAL | SIM | Import/sync. |
| 211 | 43 | Abrir/renomear/apagar aula | Web abrir local tenta fallback cloud; Flutter metodo session retorna bool. | `handleAbrir`. | `openDrawerLocalLesson`. | POSSIVEL_GAP_FUNCIONAL | SIM | Fallback precisa prova. |
| 212 | 43 | Abrir/renomear/apagar aula | Web renomear local atualiza cyberLessons; Flutter store rename. | `cyberLessons.rename`. | `store.renameLesson`. | ARQUITETURA_DIFERENTE_OK | NAO | Fonte distinta. |
| 213 | 43 | Abrir/renomear/apagar aula | Web renomear cloud enfileira sync; Flutter metodo encapsula. | `StudentLearningSync.enqueuePatch`. | `renameDrawerCloudLesson`. | PRECISA_PROVA | PROVA | Nuvem reflete. |
| 214 | 43 | Abrir/renomear/apagar aula | Web apagar cloud remove mirror local explicitamente; Flutter delete pode nao dedupe tema. | `removeLocalMirrorFor`. | `deleteDrawerCloudLesson`. | RISCO_DE_REGRESSAO | SIM | Aula pode voltar. |
| 215 | 43 | Abrir/renomear/apagar aula | Web confirma via `window.confirm`; Flutter AlertDialog. | browser confirm. | Flutter dialog. | PRECISA_EQUIVALENTE_MOBILE | SIM | Texto/acao mobile. |
| 216 | 44 | Backup exportar | Web exporta `Blob` `text/plain;charset=utf-8`. | `handleExport`. | Flutter escreve `File`. | PRECISA_EQUIVALENTE_MOBILE | SIM | Mobile precisa compartilhar/baixar. |
| 217 | 44 | Backup exportar | Web usa `exportCyberBackup()` do state-director; Flutter sintetiza envelope do state. | `exportCyberBackup`. | `buildDrawerBackupText`. | POSSIVEL_GAP_FUNCIONAL | SIM | Formato pode divergir. |
| 218 | 44 | Backup exportar | Web baixa direto na pasta Downloads; Flutter salva tmp e copia clipboard. | `<a download>`. | `writeDrawerBackupFile`, Clipboard. | PRECISA_IGUALAR | SIM | UX nao equivalente. |
| 219 | 44 | Backup exportar | Web arquivo contem lessons Web; Flutter converte StudentLearningState para lesson. | `parsed.lessons`. | `_cyberLessonFromState`. | PRECISA_PROVA | PROVA | Compatibilidade real. |
| 220 | 44 | Backup exportar | Web feedback nao mostra path; Flutter mostra path local. | `flash(t(...))`. | `_flash(...file.path)`. | PRECISA_EQUIVALENTE_MOBILE | SIM | Texto no celular precisa ajuste. |
| 221 | 45 | Backup importar | Web seleciona arquivo `.txt`; Flutter cola JSON/texto. | hidden file input. | AlertDialog TextField. | PRECISA_IGUALAR | SIM | Gap principal. |
| 222 | 45 | Backup importar | Web parseia com `parseCyberBackup`; Flutter parser proprio aceita envelope. | parser TS. | `importDrawerBackup`. | PRECISA_PROVA | PROVA | Testar Web->App e App->Web. |
| 223 | 45 | Backup importar | Web apos import enfileira sync e faz pull; Flutter importa e refresh. | `StudentLearningSync.drain`, pull. | session import/refresh. | POSSIVEL_GAP_FUNCIONAL | SIM | Nuvem pode nao igualar. |
| 224 | 45 | Backup importar | Web le `File.text()`; Flutter exige usuario abrir/copiar arquivo. | browser File API. | TextField paste. | PRECISA_EQUIVALENTE_MOBILE | SIM | Mobile precisa picker. |
| 225 | 45 | Backup importar | Web relata quantidade added/ok; Flutter flash generico. | `drawer_import_cloud_ok` args. | `_flash(t(...))`. | PRECISA_IGUALAR | SIM | Feedback deve informar resultado. |
| 226 | 46 | Tela de aula/layout | Web `main` + fixed header; Flutter Scaffold/Stack. | `LessonMainScreen`. | `AulaLabScreen`. | ARQUITETURA_DIFERENTE_OK | NAO | Plataforma. |
| 227 | 46 | Tela de aula/layout | Web conteudo max-w-2xl centralizado; Flutter ListView ocupa largura. | `ScrollFeed`. | ListView. | PRECISA_EQUIVALENTE_MOBILE | SIM | Tablet/desktop pode divergir. |
| 228 | 46 | Tela de aula/layout | Web header label sem maxWidth 82; Flutter pode truncar. | span header. | `AulaTopBar`. | PRECISA_IGUALAR | SIM | Nao ocultar marker/layer. |
| 229 | 46 | Tela de aula/layout | Web question block tem border top; Flutter usa cards/padding. | `QuestionBlock`. | `_QuestionHistoryBlock`. | PRECISA_PROVA | PROVA | Visual real. |
| 230 | 46 | Tela de aula/layout | Web imagem historico max-h-40; Flutter mantem ultimas 4. | `QuestionBlock answered`. | image cutoff. | DECISAO_HUMANA_NECESSARIA | DECISAO | Memoria vs paridade. |
| 231 | 47 | Scroll da aula | Web usa `ResizeObserver` para rolar quando conteudo cresce. | `ScrollFeed.tsx`. | Sem ResizeObserver. | POSSIVEL_GAP_FUNCIONAL | SIM | Typewriter pode crescer fora da tela. |
| 232 | 47 | Scroll da aula | Web scrolla para bottomRef com `requestAnimationFrame`; Flutter postFrame/ensureVisible. | `scrollToBottom`. | `_scrollToNewQuestion`. | ARQUITETURA_DIFERENTE_OK | NAO | Mecanismo diferente. |
| 233 | 47 | Scroll da aula | Web block nearest para indicadores/concluido; Flutter alignment 0.0. | `scrollDownTo`. | `ensureVisible(alignment:0.0)`. | PRECISA_EQUIVALENTE_MOBILE | SIM | Ponto final diferente. |
| 234 | 47 | Scroll da aula | Web possui `scroll-pt-28`; Flutter padding top fixo 112. | CSS. | ListView padding. | PRECISA_PROVA | PROVA | Header pode cobrir conteudo. |
| 235 | 47 | Scroll da aula | Web scroll container e viewport browser; Flutter ScrollController. | `overflow-y-auto`. | `ListView`. | PRECISA_PROVA | PROVA | Testar celular real. |
| 236 | 48 | Botoes/interacao visual | Web buttons HTML tem disabled/focus/aria. | `<button>`. | GestureDetector/containers. | PRECISA_EQUIVALENTE_MOBILE | SIM | Semantica mobile/acessibilidade. |
| 237 | 48 | Botoes/interacao visual | Web active scale CSS; Flutter nem sempre tem press animation. | `active:scale`. | Flutter widgets. | PRECISA_EQUIVALENTE_MOBILE | SIM | Microinteracao. |
| 238 | 48 | Botoes/interacao visual | Web hover states; Flutter touch states. | CSS hover. | no hover mobile. | WEB_ONLY_NAO_APLICAVEL | NAO | Hover nao aplica no celular. |
| 239 | 48 | Botoes/interacao visual | Web tooltips/titles em icones; Flutter tooltips parciais. | `title`, aria-label. | icons/widgets. | PRECISA_EQUIVALENTE_MOBILE | SIM | Acessibilidade. |
| 240 | 48 | Botoes/interacao visual | Web ripple nao existe; Flutter Material pode nao usar ripple em GestureDetector. | CSS. | GestureDetector. | PRECISA_PROVA | PROVA | Resposta ao toque. |
| 241 | 49 | Erros/retry/logs | API inclui requestId em erro; Web ServerFns/logs podem diferir. | Web errors. | `http-utils.js`. | FLUTTER_MELHOR | NAO | API app melhor diagnostico. |
| 242 | 49 | Erros/retry/logs | Web error boundary captura UI crash; Flutter usa tela/erro runtime. | `CyberErrorBoundary`. | no equivalent exact. | POSSIVEL_GAP_FUNCIONAL | SIM | Crash UI pode ser tratado diferente. |
| 243 | 49 | Erros/retry/logs | Web retry helper generico; Flutter/API retry separado. | `retry.ts`. | clients/controllers. | PRECISA_IGUALAR | SIM | Politica deve ser clara. |
| 244 | 49 | Erros/retry/logs | API security logs removem token; Flutter logs app precisam nao expor segredo. | `request-logger.js`. | app logs. | RISCO_DE_REGRESSAO | SIM | Segurança. |
| 245 | 49 | Erros/retry/logs | Web mostra mensagens especificas por live entry; Flutter pode mostrar erro generico. | `entryLoadingCopy`. | runtime error cards. | PRECISA_IGUALAR | SIM | Aluno precisa acao clara. |
| 246 | 50 | Legal/painel/configuracoes | Web tem rotas `/termos` e `/privacidade`; Flutter legal pages internas. | route files. | `legal_pages.dart`. | PRECISA_PROVA | PROVA | Conteudo precisa comparar. |
| 247 | 50 | Legal/painel/configuracoes | Web painel pai em `/pai`; Flutter father panel suporte. | `routes/pai.tsx`. | `father_panel.dart`. | POSSIVEL_GAP_FUNCIONAL | SIM | Dados podem ser menores. |
| 248 | 50 | Legal/painel/configuracoes | Web delete account e ServerFn; Flutter account deletion gateway. | `conta.deletar.tsx`. | `account_deletion.dart`. | PRECISA_PROVA | PROVA | Solicitação real. |
| 249 | 50 | Legal/painel/configuracoes | Web FontSizeControl; Flutter nao tem controle global equivalente. | `FontSizeControl.tsx`. | sem equivalente global. | PRECISA_EQUIVALENTE_MOBILE | SIM | Acessibilidade visual. |
| 250 | 50 | Legal/painel/configuracoes | Web tem SEO/meta/rotas legais; Flutter nao precisa SEO. | route pages. | app pages. | WEB_ONLY_NAO_APLICAVEL | NAO | Web-only correto. |

## Contagem por classificacao

| Classificacao | Quantidade |
|---|---:|
| PRECISA_IGUALAR | 28 |
| PRECISA_EQUIVALENTE_MOBILE | 39 |
| WEB_ONLY_NAO_APLICAVEL | 4 |
| ARQUITETURA_DIFERENTE_OK | 57 |
| FLUTTER_MELHOR | 7 |
| PRECISA_PROVA | 57 |
| DECISAO_HUMANA_NECESSARIA | 3 |
| RISCO_DE_REGRESSAO | 16 |
| POSSIVEL_GAP_FUNCIONAL | 39 |
| TOTAL | 250 |

## 20 diferencas mais criticas

1. Auth API/JWT pode bloquear `/api/credits/me`, T00 e T02 antes da aula.
2. Objetivo precisa avançar sem cair em erro e sem ficar preso.
3. T00 SSE precisa liberar no primeiro `t00_item_partial`.
4. T02 precisa receber payload rico equivalente ao Web.
5. Contrato T02 precisa ser validado igualmente entre Web/API/Flutter.
6. Fast path nao pode esperar T00 final, imagem ou audio.
7. Janela dopaminica B/C precisa rodar em background sem bloquear.
8. Cache/dedupe T02 precisa ser provado no APK real.
9. Credito infinito precisa vir do orgao correto e nao da UI.
10. Erro de credito/auth precisa ser claro para o aluno.
11. Sync/realtime multi-dispositivo ainda nao tem equivalencia completa comprovada.
12. Tombstone/delete cloud/local pode ressuscitar aula se dedupe divergir.
13. Backup Web exportado nao tem importacao natural por arquivo no Flutter.
14. Importacao Flutter por colagem nao e equivalente ao seletor de arquivo Web.
15. Scroll da aula pode posicionar pergunta/feedback diferente.
16. Indicadores 1/2/3 precisam ser provados visualmente e funcionalmente.
17. Duvia com foto precisa prova real de camera/galeria no APK.
18. Audio precisa prova de tocar/parar/fallback no APK.
19. Legal/delete account precisa prova funcional.
20. Captura visual autenticada tela por tela ainda e obrigatoria.

## Diferencas que podem quebrar o aluno entrar e estudar

- Auth/JWT/API token desalinhado.
- Credito infinito ou credito normal nao hidratado.
- Objetivo nao validado/navegado corretamente.
- T00 SSE nao processado.
- Primeiro item parcial nao salvo.
- T02 payload incompleto.
- T02 contrato invalido ou parser divergente.
- Aula nao abre sem imagem/audio.
- Scroll/feedback escondendo botoes.
- Estado local/cloud corrompendo retomada.
- Cache/dedupe causando T02 duplicado ou material velho.

## Diferencas Web-only/plataforma

- SEO/meta/rotas publicas.
- Hover/cursor de browser.
- Webhook hospedado no Web/app server.
- URL `returnTo` literal.
- Browser Blob/ObjectURL.
- File input HTML.
- localStorage/sessionStorage.
- React Query.

## Onde o Flutter esta melhor ou mais seguro

- Tipagem por enums/classes em varias areas pedagogicas.
- API com `requestId` em erro.
- API com resource-owner para lesson/media/doubt.
- Fallback/abstracao mobile de audio.
- Governadores/orgaos internos adicionais para saude do app.
- Separacao correta de prompts/segredos fora do Flutter.
- Fluxo mobile pode usar SafeArea e recursos nativos.

## Lista final: diferencas que precisam virar missao de correcao/prova

Prioridade 1:

- Auth real do APK production contra API.
- Credito infinito e credito normal.
- Objetivo -> T00 -> T02 -> aula.
- T00 SSE primeiro parcial.
- T02 payload/contrato.
- Scroll/indicadores/feedback da aula.

Prioridade 2:

- Backup importar por arquivo `.txt` no Flutter.
- Backup exportar com compartilhamento/download mobile real.
- Drawer cloud/local dedupe, abrir, renomear, apagar.
- Sync multi-dispositivo/realtime equivalente mobile.
- Camera/galeria em duvida.

Prioridade 3:

- Checkout mobile/retorno.
- Legal/delete account/painel pai.
- Font size/acessibilidade.
- Prova visual autenticada de telas principais.

## Criterio B desta auditoria

- Partes analisadas: 50.
- Partes com pelo menos 5 diferencas: 50.
- Total de diferencas: 250.
- Codigo de produto alterado: NAO.
- Commit/push: NAO.
