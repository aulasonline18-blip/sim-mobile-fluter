# B1 - Image System Inventory

Data da auditoria: 2026-06-30.

Repositorios auditados:

- Flutter: `/root/sim-mobile-fluter`, branch `main`, commit `d224018` (`docs: record authenticated interface capture audit`).
- SimWeb: `/root/sim-work/sim-web`, branch `main`, commit `d113cf4` (`Lovable update`).
- API oficial do app: `/root/sim-work/sim-api`, branch `main`, commit `c4ddda0` (`test: prove sim api contracts`).

Escopo desta missao: inventario, classificacao e comparacao. Nao houve implementacao planejada nesta etapa.

## 1. Resumo executivo

O SimWeb possui um sistema de imagem vivo composto por:

- entrada de imagem/foto/anexo no objetivo, usada para extrair texto/contexto pedagogico antes da aula;
- contrato T02 `visual_trigger`, que nasce junto do texto da aula ou da resposta de duvida;
- regra S12 para decidir se ha imagem, se o caminho e software/SVG gratuito ou IA paga;
- roteador visual N2/N3 antes de cobrar imagem paga;
- templates matematicos SVG;
- oferta paga explicita antes de gerar Blueprint/IA;
- endpoint autenticado `/api/generate-lesson-image` com cobranca idempotente, refund em falha deterministica, rate limit e circuit breaker;
- cache tecnico de ate 3 aulas/24h, persistindo texto e removendo imagem no storage persistente;
- exibicao da imagem dentro da aula depois da explicacao e sem bloquear texto/pergunta;
- duvida com foto/camera/galeria e resposta T02 com visual gratuito opcional.

O Flutter possui partes importantes copiadas, mas a paridade ainda nao esta completa:

- `visual_trigger`, S12, sanitizacao de SVG, roteador N2, templates matematicos, contrato de API de imagem, oferta paga e duvida com foto existem.
- A tela atual de aula (`LessonImagePanel`) ainda nao usa o pipeline real: `requestLessonImage()` so muda estado para `ready` apos 180ms.
- O `LessonOrchestrator` Flutter nao propaga `visualTrigger` recebido do T02 para `LessonContent`, entao o caminho gratuito/pago pode nao ser acionado no fluxo vivo.
- O Flutter nao tem N3 server judge equivalente ao SimWeb.
- O servidor oficial do app (`/root/sim-work/sim-api`) tem `/api/generate-lesson-image`, mas nao reproduz o endpoint saudavel do SimWeb: gera direto com Gemini e reserva credito no servidor, sem oferta Web, sem N2/N3, sem Replicate/nano-banana-pro, sem idempotency SQL/circuit breaker equivalente.

## 2. Definicao da cidade A

Cidade A: nao havia prova fechada de tudo que o SimWeb possui no sistema de imagem, nem comparacao item a item contra o SimApp Flutter.

## 3. Definicao da cidade B1

Cidade B1: todo comportamento de imagem vivo do SimWeb foi identificado, classificado, provado por arquivo/linha, comparado com Flutter, e toda diferenca saudavel foi colocada na lista final para cidade C.

## 4. Inventario do Flutter atual

| ID Flutter | Arquivo | Funcao/classe | O que faz | Status | Precisa comparar com Web? |
|---|---|---|---|---|---|
| FL-IMG-001 | `lib/sim/media/lesson_visual_pipeline.dart:20` | `LessonVisualTrigger` | Modelo do `visual_trigger` T02, incluindo `needs_image`, `render_strategy`, `svg_payload`, `image_prompt`, `math_template`. | PARCIAL | Sim |
| FL-IMG-002 | `lib/sim/media/lesson_visual_pipeline.dart:94` | `LessonVisualPipeline.resolveVisual` | Decide SVG inline, math template, N2 e IA paga via `LessonImageClient`. | PARCIAL | Sim |
| FL-IMG-003 | `lib/sim/media/s12_visual_pipeline.dart:14` | `sanitizeAndEncodeSvg` | Sanitiza SVG e converte para data URL. | COMPLETO | Sim |
| FL-IMG-004 | `lib/sim/media/s12_visual_pipeline.dart:66` | `decideVisualGeneration` | Replica S12 basico: skip, SVG inline, gates de background/pago. | PARCIAL | Sim |
| FL-IMG-005 | `lib/sim/media/visual_router_n2.dart:229` | `classifyVisualByKeywords` | Roteador N2 deterministico por keywords. | PARCIAL | Sim |
| FL-IMG-006 | `lib/sim/media/math_templates/math_templates.dart:24` | `renderMathTemplate` | Renderiza `kinematics_vt`, `kinematics_st`, `linear_function`, `quadratic_function`, `unit_circle`. | COMPLETO/PARCIAL | Sim |
| FL-IMG-007 | `lib/sim/media/lesson_image_api_contract.dart:1` | `GenerateLessonImageRequest` | Normaliza prompt, chave e aspect ratio do endpoint de imagem. | COMPLETO | Sim |
| FL-IMG-008 | `lib/sim/external_ai/sim_server_ai_clients.dart:59` | `SimServerLessonImageClient` | Chama `/api/generate-lesson-image` no servidor proprio. | PARCIAL | Sim |
| FL-IMG-009 | `lib/sim/media/paid_image_service.dart:37` | `PaidImageService` | Oferta/aceite/consumo/falha de imagem paga e eventos no estado. | PARCIAL | Sim |
| FL-IMG-010 | `lib/sim/media/lesson_paid_image_offer.dart:24` | `LessonPaidImageOfferController` | UI/controller de oferta paga, saldo, aceitar, recusar e comprar creditos. | PARCIAL | Sim |
| FL-IMG-011 | `lib/sim/lesson/lesson_orchestrator.dart:29` | `prefetchCompleteLesson` | Busca texto, cacheia, agenda imagem sequencial. | PARCIAL | Sim |
| FL-IMG-012 | `lib/sim/lesson/lesson_orchestrator.dart:65` | `_fetchImage` | Tenta math template e S12 SVG gratuito; nao gera IA paga aqui. | PARCIAL/NAO CONECTADO | Sim |
| FL-IMG-013 | `lib/sim/lesson/lesson_orchestrator.dart:119` | `_fetchText` | Cria `LessonContent`, mas nao copia `material.visualTrigger`. | PARCIAL COM FALHA | Sim |
| FL-IMG-014 | `lib/sim/lesson/lesson_material_cache.dart:21` | `LessonMaterialCache` | Cache 3 aulas/24h, persiste sem imagem. | COMPLETO | Sim |
| FL-IMG-015 | `lib/sim/lesson/lesson_models.dart:70` | `CompleteLesson.imagem` | Campo de imagem pronta na aula. | COMPLETO | Sim |
| FL-IMG-016 | `lib/features/classroom/aula_widgets.dart:310` | `LessonImagePanel` | UI manual "Gerar imagem"; nao exibe URL real. | PARCIAL | Sim |
| FL-IMG-017 | `lib/features/session/lab_session.dart:960` | `requestLessonImage` | Mock local: espera 180ms e marca `imageStatus=ready`. | DOENCA/NAO COPIAR | Sim |
| FL-IMG-018 | `lib/features/classroom/aula_screen.dart:481` | uso de `LessonImagePanel` | Mostra painel de imagem na aula. | PARCIAL | Sim |
| FL-IMG-019 | `lib/features/classroom/aula_screen.dart:828` | `_QuestionHistoryBlock` | Exibe `Image.network(entry.imageUrl)` no historico, ultimas 4 mantem imagem. | PARCIAL | Sim |
| FL-IMG-020 | `lib/features/classroom/aula_screen.dart:1269` | `_DoubtInputSheetState` | Camera/galeria, data URL, validacao e chip de foto da duvida. | COMPLETO/PARCIAL | Sim |
| FL-IMG-021 | `lib/sim/auxiliary/doubt_input_sheet.dart:10` | `DoubtInputDraft.validate` | Texto/foto, MIME `image/*`, data URL e limite 8MB. | COMPLETO | Sim |
| FL-IMG-022 | `lib/sim/auxiliary/lesson_doubt_controller.dart:31` | `submitDoubt` | Envia texto e `DoubtImagePayload` para T02. | COMPLETO/PARCIAL | Sim |
| FL-IMG-023 | `lib/session/entry_form_state.dart:74` | `allowPaidImages` | Campo existe no estado de entrada. | PARCIAL | Sim |
| FL-IMG-024 | `lib/sim/state/internal_organs_governor.dart:935` | `requestPaidImage` | Fluxo interno de oferta, reserva, request, capture/refund. | PARCIAL/NAO CONECTADO A UI | Sim |
| FL-IMG-025 | `test/media_phase_test.dart:155` | testes de prompt/validacao/API/oferta | Cobre prompt, data URL, fetch pago, oferta e limites de contrato. | COMPLETO | Sim |

## 5. Termos buscados no SimWeb

Busca textual executada com `rg -i`, excluindo `node_modules`, `dist`, `build`, `bun.lock`, `package-lock.json`. Busca por nome de arquivo executada com `find`.

| Termo | Ocorrencias | Arquivos relevantes adicionados ao inventario | Descartes principais |
|---|---:|---|---|
| image | 824 | S12, pipeline, aula, endpoint, anexos, T02, cache, estado | docs/canonical/migrations quando sem comportamento vivo |
| imagem | 182 | aula, anexos, endpoint, pipeline | docs/migrations |
| visual | 364 | T02, S12, visual router, pipeline, estado | README/docs quando apenas descricao |
| media | 50 | `studentLessonMediaService`, cache, runtime | hooks/styles/pretest sem imagem |
| picture | 0 | nenhum | 0 resultados |
| photo | 39 | `DoubtInputSheet`, adendo duvida, anexos | prompt docs sem runtime direto |
| camera | 9 | `DoubtInputSheet`, `cyber.objeto` | nenhum relevante descartado |
| gallery | 4 | `DoubtInputSheet` | adendo como contrato |
| upload | 10 | drawer/import, objetivo/anexos, cloud queue | upload de backup nao imagem de aula |
| vision | 86 | anexos OCR/vision, T00 | usos gerais de "vision" fora de imagem |
| diagram | 56 | T02, T11, visual router, blueprint | docs gerais |
| diagrama | 14 | visual router, attachments | docs gerais |
| svg | 239 | S12, math templates, visual router, login SVG | UI icon/login SVG descartado como imagem de aula |
| canvas | 24 | `compress-image`, math shared | canvas de compressao, nao renderer de aula |
| chart | 15 | T02/T11, visual router | package/docs |
| graph | 107 | T02, visual router, runtime, math templates | form/routes gerais |
| grafico | 1 | visual router | nenhum |
| gráfico | 15 | T02, duvida, math templates | nenhum |
| plot | 36 | math templates | nenhum |
| axis | 34 | math templates, visual router | nenhum |
| eixo | 21 | math templates, visual router | docs |
| coordinate | 3 | visual router, T11 | nenhum |
| coordenada | 1 | visual router | nenhum |
| geometry | 20 | T02, visual router, blueprint | nenhum |
| geometria | 6 | visual router, runtime | docs |
| triangle | 1 | visual router | nenhum |
| triângulo | 1 | visual router | nenhum |
| angle | 23 | math templates, visual router | vite/wrangler descartados |
| ângulo | 8 | math templates, visual router | nenhum |
| circle | 41 | math templates, UI decorative | portal/prep decorative |
| círculo | 6 | math templates, visual router | nenhum |
| function graph | 1 | T11 | nenhum |
| math | 348 | math templates, T02, pipeline | mathjs/package/docs |
| matemática | 7 | visual router/T02 | docs |
| template | 130 | math templates, T02, bootstrap | UI templates nao imagem |
| renderer | 11 | math templates, visual router | server renderer geral |
| render | 160 | S12, pipeline, math templates | generic render React |
| draw | 86 | blueprint, compress, UI draw | labels/UI draw |
| desenhar | 1 | runtime | nenhum |
| illustration | 10 | blueprint, visual router | nenhum |
| ilustração | 7 | visual router, caption | caption legacy |
| paid | 150 | PaidImageService, offer hook, runtime, credit route | payments gerais |
| paid image | 0 | nenhum | 0 resultados |
| paid_image | 16 | PaidImageService/runtime/state | nenhum |
| image offer | 1 | PaidImageService | nenhum |
| offer | 167 | PaidImageService, offer card/hook/runtime | Stripe/payment offer geral |
| credits | 332 | creditos, endpoint, image charge | migrations/payments gerais |
| créditos | 66 | creditos, endpoint, UI | docs/migrations |
| cost | 106 | PaidImageService, endpoint, constants | stripe/migrations gerais |
| custo | 55 | T11, pipeline, endpoint | docs/styles |
| cache | 319 | lesson-material-cache, runtime, media cache | query/cache geral |
| prefetch | 27 | runtime, material controller, ready window | docs |
| dedupe | 7 | store/vite | sem logica especifica de imagem no Web alem de inflight/cache |
| fallback | 154 | S12, N3, endpoint, T02 | fallbacks gerais de auth/UI |
| error | 1038 | endpoint, controllers, error UI | erros gerais nao imagem |
| erro | 1294 | endpoint, UI, controllers | erros gerais nao imagem |
| T02 | 410 | T02 prompt, ModuleCaller, runtime | docs gerais |
| complete-lesson | 17 | route `/api/complete-lesson` | route tree |
| lesson image | 0 | nenhum | 0 resultados |
| aula imagem | 0 | nenhum | 0 resultados |
| visual prompt | 0 | nenhum | 0 resultados |
| prompt visual | 2 | moduleCaller | nenhum |
| visual_router | 4 | runtime | nenhum |
| visual pipeline | 0 | nenhum | 0 resultados |
| image controller | 0 | nenhum no SimWeb | 0 resultados |
| image service | 0 | nenhum no SimWeb | 0 resultados |
| image cache | 0 | nenhum textual | 0 resultados |

## 6. Arquivos candidatos encontrados por nome

| Arquivo | Classificacao |
|---|---|
| `modules/tutor/T11_visual_economy_law.txt` | Relevante, saudavel, prompt/lei visual. |
| `src/core/S12_VisualPipeline.ts` | Relevante, saudavel, decisao principal. |
| `src/cyber/LessonVisualPipeline.ts` | Relevante, saudavel, API client/compressao/math visual. |
| `src/cyber/PaidImageService.ts` | Relevante, saudavel, oferta paga. |
| `src/cyber/aula/useLessonPaidImageOffer.ts` | Relevante, saudavel, UI/controller de oferta. |
| `src/cyber/lesson-material-cache.ts` | Relevante, saudavel, cache/dedupe. |
| `src/lib/compress-image.ts` | Relevante, saudavel, compressao client-side. |
| `src/lib/gemini-image.functions.ts` | Legado/doenca: serverFn antiga exportada por compatibilidade; endpoint vivo usa `src/routes/api/generate-lesson-image.ts`. |
| `src/lib/visual-router.functions.ts` | Relevante, saudavel, N2/N3. |
| `src/lib/visual-trigger.ts` | Legado/compatibilidade: fachada antiga de extracao; S12 atual usa `visual_trigger` estruturado. |
| `src/routes/api/generate-lesson-image.ts` | Relevante, saudavel, endpoint vivo de IA paga. |
| `src/sim/lesson/studentLessonMediaService.ts` | Relevante, saudavel, eventos de media/audio/imagem no estado. |

## 7. Arquivos relevantes

- `modules/tutor/T00_bootstrap_realtime.txt`
- `modules/tutor/T02_content.txt`
- `modules/tutor/T02_content.v3.txt`
- `modules/tutor/T11_visual_economy_law.txt`
- `modules/tutor/adendos/ADENDO_DOUBT.txt`
- `src/core/S12_VisualPipeline.ts`
- `src/cyber/LessonVisualPipeline.ts`
- `src/cyber/PaidImageService.ts`
- `src/cyber/aula/DoubtInputSheet.tsx`
- `src/cyber/aula/LessonMainScreen.tsx`
- `src/cyber/aula/components.tsx`
- `src/cyber/aula/useLessonDoubtController.ts`
- `src/cyber/aula/useLessonMaterialController.ts`
- `src/cyber/aula/useLessonPaidImageOffer.ts`
- `src/cyber/lesson-material-cache.ts`
- `src/cyber/lesson-orchestrator.ts`
- `src/cyber/lesson-orchestrator.impl.ts`
- `src/cyber/lesson-pipeline-runtime.ts`
- `src/cyber/math-templates/*`
- `src/lib/attachments.functions.ts`
- `src/lib/attachments.server.ts`
- `src/lib/compress-image.ts`
- `src/lib/moduleCaller.functions.ts`
- `src/lib/visual-router.functions.ts`
- `src/routes/api/generate-lesson-image.ts`
- `src/routes/cyber.objeto.tsx`
- `src/sim/lesson/studentLessonMaterialService.ts`
- `src/sim/state/doubtT02Caller.ts`

## 8. Arquivos descartados

| Grupo | Motivo |
|---|---|
| `canonical/*`, `SIM_PROJECT_LAWS.md`, READMEs | Documentacao/indice; usados como contexto, nao fluxo vivo. |
| `supabase/migrations/*` | Historico/esquema/credito; a logica viva auditada esta nas chamadas RPC do endpoint e controllers. |
| `src/components/ui/*`, `src/styles.css`, `src/routes/login.tsx` | SVG/render/UI generico; nao participa do sistema de imagem da aula. |
| `src/cyber/PortalScreen.tsx`, `SimPreparationExperience.tsx` | Visual decorativo/robo/logo; nao imagem pedagogica de aula. |
| `src/lib/gemini-caption.functions.ts` | Caption/OCR auxiliar, nao fluxo vivo principal de imagem de aula. |
| `src/lib/gemini-image.functions.ts` | Legado/compatibilidade; endpoint vivo e `src/routes/api/generate-lesson-image.ts`. |
| `src/lib/visual-trigger.ts` | Compatibilidade com contrato antigo textual; contrato saudavel atual e `visual_trigger` estruturado de T02/S12. |
| `src/routes/creditos.tsx`, `payments/*`, `stripe/*` | Relevante para creditos gerais, mas nao decisao/render/cache de imagem. |
| `src/server.ts`, `src/start.ts`, `vite.config.ts`, `wrangler.jsonc` | Infra/build, nao comportamento de imagem. |

## 9. Fluxo completo da imagem no SimWeb

1. Intencao de imagem nasce no T02, guiada por T00/perfil, item atual, layer, adendos e `visual_policy`.
2. T02 retorna `visual_trigger` sempre completo em modo normal/revisao/recuperacao e tambem em duvida reduzida.
3. S12 (`decideVisualGeneration`) decide skip, SVG inline gratuito, ou prompt para IA paga.
4. `scheduleImage` roda apos o texto estar disponivel; texto da aula nao espera imagem.
5. Se houver `svg_payload` valido, entrega SVG inline imediatamente.
6. Se houver `math_template`, tenta template matematico deterministico.
7. Se ainda restar caminho pago, N2 classifica por keywords antes de cobrar.
8. Se N2 for `svg` ou `ambiguous`, N3 chama IA barata para julgar/gerar SVG.
9. Se N2/N3 indicarem IA, o Web cria oferta paga; nao cobra automaticamente.
10. UI mostra `PaidImageOfferCard`; aluno aceita, recusa, compra creditos ou continua sem imagem.
11. Ao aceitar, `acceptPaidImageOffer` chama `/api/generate-lesson-image`.
12. Endpoint autentica, rate-limita, valida payload, calcula idempotency key, debita via RPC, chama Replicate/Lovable gateway, marca sucesso ou refund/pendencia.
13. Resultado vira data URL, e o cliente ainda pode comprimir imagem.
14. Cache guarda ate 3 aulas/24h em memoria e persiste texto sem imagem no localStorage.
15. `subscribeLesson` notifica a tela; `LessonMainScreen` exibe `<img>` dentro do bloco da teoria.
16. Erros/falhas de imagem geram logs/eventos e nao bloqueiam a aula.
17. Em duvida, aluno pode enviar foto; T02 analisa imagem e pode devolver visual gratuito. IA paga em duvida e pulada sem confirmacao explicita.

## 10. Inventario de comportamentos Web

| ID | Comportamento SimWeb | Fonte Web | Categoria | Saude | Deve copiar? | Flutter | Status Flutter | Acao futura |
|---|---|---|---|---|---|---|---|---|
| IMG-WEB-001 | T00 aceita entrada com imagem/foto/PDF/audio/misto e descreve legibilidade/diagramas. | `modules/tutor/T00_bootstrap_realtime.txt:3`, `:23`, `:61` | prompt/contrato T00 | Saudavel | Sim | anexos existem | PARCIAL | Garantir paridade de T00/attachment no app. |
| IMG-WEB-002 | Objetivo aceita documento, camera, imagem, colagem de imagem, ate 3 anexos/10MB. | `src/routes/cyber.objeto.tsx:79`, `:259`, `:351`, `:389`, `:481` | componente visual/upload | Saudavel | Sim | `onboarding_screens`, `EntryFormState` | PARCIAL | Comparar estados e servidor de anexos. |
| IMG-WEB-003 | Anexo imagem/PDF vira texto pedagogico por OCR/vision, truncado a 8000 chars. | `src/lib/attachments.server.ts:10`, `:50`, `:102`, `:128`, `:139` | backend/API/vision | Saudavel | Sim | `SimServerAttachmentClient` existe | PARCIAL | Confirmar contrato exato app API. |
| IMG-WEB-004 | T02 deve decidir se imagem e pedagogicamente util. | `modules/tutor/T02_content.v3.txt:27`, `:186` | prompt/contrato T02 | Saudavel | Sim | prompt API proprio existe | PARCIAL | Conferir prompt oficial no server. |
| IMG-WEB-005 | T02 sempre retorna `visual_trigger` com campos base. | `modules/tutor/T02_content.v3.txt:205`, `:206`, `:214`, `:318` | prompt/contrato T02 | Saudavel | Sim | `LessonVisualTrigger`, `LessonContent.visualTrigger` | PARCIAL | Conectar retorno T02 ao `LessonContent`. |
| IMG-WEB-006 | T02 pode incluir `math_template` apenas para graficos/diagramas deterministicos. | `modules/tutor/T02_content.v3.txt:217`, `:227` | prompt/contrato T02 | Saudavel | Sim | math templates existem | PARCIAL | Provar fluxo vivo. |
| IMG-WEB-007 | T11 obriga economia visual: sem imagem quando texto ensina melhor. | `modules/tutor/T11_visual_economy_law.txt:10`, `:14`, `:70` | decisao de imagem | Saudavel | Sim | S12 existe | PARCIAL | Alinhar prompt/API. |
| IMG-WEB-008 | T11 prefere software/SVG para diagramas/graficos/tabelas/fluxos. | `modules/tutor/T11_visual_economy_law.txt:17`, `:21`, `:23` | imagem por software | Saudavel | Sim | N2/math/S12 existem | PARCIAL | Falta N3 e conexao viva. |
| IMG-WEB-009 | T11 reserva IA paga para anatomia/organico/foto/realismo. | `modules/tutor/T11_visual_economy_law.txt:31`, `:34`, `:61` | imagem por IA externa | Saudavel | Sim | N2 AI hints existem | PARCIAL | Servidor app diverge. |
| IMG-WEB-010 | Validador T02 rejeita campos visuais invalidos. | `src/lib/moduleCaller.functions.ts:574`, `:580`, `:589`, `:596`, `:604` | prompt/contrato T02 | Saudavel | Sim | parser/modelos existem | PARCIAL | Validar no app/API. |
| IMG-WEB-011 | S12 sanitiza SVG contra script/on*/javascript/foreignObject e limite 100KB. | `src/core/S12_VisualPipeline.ts:67`, `:75`, `:83` | fallback/seguranca | Saudavel | Sim | `s12_visual_pipeline.dart` | COMPLETO | Manter. |
| IMG-WEB-012 | S12 entrega SVG inline gratis quando `render_strategy=software` e `svg_payload` valido. | `src/core/S12_VisualPipeline.ts:113`, `:117`, `:119` | imagem por software | Saudavel | Sim | S12 Flutter | COMPLETO/PARCIAL | Provar fluxo vivo. |
| IMG-WEB-013 | S12 bloqueia IA paga em background e quando `allowPaidImages` nao permite. | `src/core/S12_VisualPipeline.ts:138`, `:141` | imagem paga/creditos | Saudavel | Sim | S12 Flutter | PARCIAL | Web atual usa oferta livre por aula; app precisa alinhar. |
| IMG-WEB-014 | `scheduleImage` roda depois do texto e nao bloqueia a aula. | `src/cyber/lesson-pipeline-runtime.ts:16`, `:378`, `:647`, `:733`, `:743` | fallback/erro/cache | Saudavel | Sim | `LessonOrchestrator` Flutter | PARCIAL | Conectar imagem real a UI. |
| IMG-WEB-015 | Math templates renderizam SVG deterministico antes de cobrar IA. | `src/cyber/lesson-pipeline-runtime.ts:414`, `:421`, `:425`; `src/cyber/math-templates/index.ts` | imagem por software | Saudavel | Sim | math templates Flutter | PARCIAL | Provar via testes/fluxo. |
| IMG-WEB-016 | N2 roda sempre antes de oferta paga para evitar cobrar por diagrama. | `src/lib/visual-router.functions.ts:13`, `:273`; `src/cyber/lesson-pipeline-runtime.ts:465`, `:473` | decisao de imagem | Saudavel | Sim | `visual_router_n2.dart` | PARCIAL | Falta N3 e conexao viva. |
| IMG-WEB-017 | N3 usa IA barata para julgar/gerar SVG quando N2 e ambiguo/svg. | `src/lib/visual-router.functions.ts:361`, `:390`, `:447`; runtime `:491` | imagem por software/IA externa | Saudavel | Sim | ausente | AUSENTE | Implementar/adaptar no app/API ou decidir substituto. |
| IMG-WEB-018 | Oferta paga e criada antes de cobrar, custo 10 creditos. | `src/cyber/PaidImageService.ts:3`, `:51`, `:53`; `src/cyber/aula/components.tsx:99` | imagem paga/creditos | Saudavel | Sim | controllers/servicos existem | PARCIAL | Conectar UI real. |
| IMG-WEB-019 | Recusar imagem paga nao bloqueia futuras, mas pula aquela oferta. | `src/cyber/PaidImageService.ts:56`, `:59`; runtime `:455` | autorizacao aluno | Saudavel | Sim | `declinePaidImage` existe | PARCIAL | Conectar a aula. |
| IMG-WEB-020 | Aceite consome oferta, roda fila sequencial de imagem, cacheia e notifica. | `src/cyber/lesson-pipeline-runtime.ts:552`, `:562`, `:565`, `:567` | imagem paga/cache | Saudavel | Sim | `PaidImageService.consume` existe | PARCIAL | Integrar com UI/API. |
| IMG-WEB-021 | Endpoint `/api/generate-lesson-image` autentica, rate-limita e valida payload. | `src/routes/api/generate-lesson-image.ts:35`, `:61`, `:125`, `:130`, `:156` | backend/API | Saudavel | Sim | API proprio tem endpoint | PARCIAL/DIVERGENTE | Alinhar servidor app. |
| IMG-WEB-022 | Endpoint debita imagem por RPC idempotente e estorna em falhas deterministicas. | `src/routes/api/generate-lesson-image.ts:168`, `:176`, `:198`, `:252`, `:318` | creditos/custo | Saudavel | Sim | API proprio usa ledger em memoria | PARCIAL/DIVERGENTE | Levar logica robusta ao app API. |
| IMG-WEB-023 | Endpoint usa provider Replicate/Lovable `google/nano-banana-pro`, timeout, retry e circuit breaker. | `src/routes/api/generate-lesson-image.ts:6`, `:11`, `:83`, `:210`, `:215` | backend/API/fallback | Saudavel | Sim | API proprio usa Gemini media direto | AUSENTE/DIVERGENTE | Decidir backend oficial. |
| IMG-WEB-024 | Cliente comprime data URL em canvas antes de cache/exibicao. | `src/cyber/LessonVisualPipeline.ts:54`, `:56`; `src/lib/compress-image.ts:1`, `:11` | cache/exibicao | Saudavel | Sim | ausente para aula; duvida nao comprime | AUSENTE/PARCIAL | Copiar compressao se mantiver data URL. |
| IMG-WEB-025 | Cache tecnico guarda 3 aulas por 24h e persiste sem imagem. | `src/cyber/lesson-material-cache.ts:3`, `:55`, `:60`, `:95` | cache/prefetch/dedupe | Saudavel | Sim | `LessonMaterialCache` | COMPLETO | Manter. |
| IMG-WEB-026 | Tela assina imagem/oferta por chave e marca started/ready no estado. | `src/cyber/aula/useLessonMaterialController.ts:149`, `:158`, `:163`, `:168`, `:173` | exibição na aula | Saudavel | Sim | UI Flutter parcial | AUSENTE/PARCIAL | Conectar subscribe/bus/UI. |
| IMG-WEB-027 | Aula exibe oferta paga, barra de duvida, imagem de duvida e imagem da aula no bloco de teoria. | `src/cyber/aula/LessonMainScreen.tsx:390`, `:400`, `:423`, `:435` | exibição na aula | Saudavel | Sim | `LessonImagePanel`, duvida | PARCIAL | Trocar mock por imagem real. |
| IMG-WEB-028 | `onImageError` nao bloqueia aula. | `src/cyber/aula/LessonMainScreen.tsx:445`; runtime logs `IMG_API_ERR` | fallback/erro | Saudavel | Sim | erro visual nao conectado | AUSENTE/PARCIAL | Implementar estado de erro nao bloqueante. |
| IMG-WEB-029 | Duvida aceita texto ou foto, camera/galeria, compressao, 1200 chars, 8MB. | `src/cyber/aula/DoubtInputSheet.tsx:47`, `:55`, `:57`, `:87`, `:120`, `:163` | imagem em duvida | Saudavel | Sim | `_DoubtInputSheet`, `DoubtInputDraft` | COMPLETO/PARCIAL | Visual e compressao divergem. |
| IMG-WEB-030 | Duvida envia imagem para T02 Vision e valida 8MB/MIME. | `src/sim/state/doubtT02Caller.ts:83`, `:86`, `:99`, `:109` | imagem em duvida/backend | Saudavel | Sim | `LessonDoubtController` | PARCIAL | Confirmar inline image no app API. |
| IMG-WEB-031 | Duvida so renderiza visual gratuito; IA paga de duvida e pulada sem confirmacao. | `src/sim/state/doubtT02Caller.ts:126`, `:129`, `:140` | imagem em duvida/fallback | Saudavel | Sim | parcial | PARCIAL | Copiar politica. |
| IMG-WEB-032 | Revisao/recuperacao usam T02/adendos e herdam `visual_trigger` normal. | `modules/tutor/T02_content.v3.txt:50`, `:54`; `src/lib/moduleCaller.functions.ts:499` | imagem em revisao/recuperacao | Saudavel | Sim | aux rooms existem | PARCIAL | Provar imagem em aux rooms. |
| IMG-WEB-033 | `src/lib/gemini-image.functions.ts` ainda existe como serverFn antiga. | `src/core/S12_VisualPipeline.ts:28`; `src/lib/gemini-image.functions.ts:32` | legado/doenca | Legado | Nao | nao copiar | NAO DEVE COPIAR | Usar endpoint vivo. |
| IMG-WEB-034 | API app gera imagem direta com Gemini e cobra no servidor sem oferta/N2/N3 Web. | `/root/sim-work/sim-api/src/media/image-controller.js:3` | backend/API | Doenca para paridade Web | Nao como esta | Flutter chama API propria | EXISTE NO LUGAR ERRADO | Alinhar com Web saudavel ou documentar decisao. |
| IMG-WEB-035 | `requestLessonImage` Flutter e mock visual. | Flutter `lib/features/session/lab_session.dart:960` | legado/doenca Flutter | Doenca Flutter | Nao | existe | NAO DEVE FICAR | Remover/substituir por pipeline real. |

## 11. Classificacao saude/doenca/legado

Saudavel e deve orientar Flutter:

- `visual_trigger` completo no T02.
- S12 com SVG inline seguro e gates de custo.
- Math templates SVG.
- N2/N3 antes de cobrar.
- Oferta paga explicita antes de debito.
- Endpoint autenticado/idempotente/rate-limited/circuit-breaker.
- Cache de 3 aulas/24h com persistencia sem imagem.
- Exibicao nao bloqueante na aula.
- Duvida com foto/camera/galeria e visual gratuito opcional.
- Anexos de objetivo por OCR/vision para enriquecer perfil.

Doenca/nao copiar:

- Mock Flutter `requestLessonImage()` que so marca `ready`.
- Geracao direta de imagem no app API sem oferta/N2/N3, se a meta for paridade do Web.
- Cobranca de imagem sem autorizacao visual do aluno.
- Qualquer bloqueio da aula enquanto imagem carrega.

Legado:

- `src/lib/gemini-image.functions.ts` no SimWeb.
- `src/lib/visual-trigger.ts` como compatibilidade textual antiga.

## 12. Comparacao Web x Flutter

| Comportamento saudavel Web | Status Flutter |
|---|---|
| T00/anexo imagem/PDF alimenta perfil | PARCIAL |
| `visual_trigger` T02 completo | PARCIAL, modelo existe, fluxo T02->LessonContent falha no orchestrator |
| S12 SVG inline seguro | COMPLETO/PARCIAL |
| Math templates | COMPLETO/PARCIAL |
| N2 keywords | PARCIAL |
| N3 judge/gerador SVG barato | AUSENTE |
| Oferta paga antes de cobrar | PARCIAL |
| Aceitar/recusar/comprar creditos | PARCIAL |
| Endpoint robusto do Web | AUSENTE/DIVERGENTE no app API |
| Cache tecnico 3/24h sem imagem persistida | COMPLETO |
| Imagem chega por pub/sub e aparece na teoria | AUSENTE/PARCIAL |
| Imagem nao bloqueia aula | PARCIAL |
| Duvida com foto | COMPLETO/PARCIAL |
| Visual gratuito em duvida | PARCIAL |
| Revisao/recuperacao com visual_trigger | PARCIAL |

Contagem:

- Total de comportamentos saudaveis Web: 32.
- Ja completos no Flutter: 3.
- Parciais: 22.
- Ausentes: 4.
- Nao conectados/no lugar errado: 3.
- Nao copiar: 3 itens doenca/legado.
- Bloqueados por decisao humana: 1, escolher se API oficial deve copiar endpoint Web exatamente ou manter arquitetura propria com comportamento equivalente.

## 13. Lista do que ja esta completo no Flutter

- Sanitizacao basica de SVG contra XSS.
- Cache de material com limite/TTL e persistencia sem imagem.
- Validacao basica de duvida com foto: MIME `image/*`, `data:image/*`, 8MB.

## 14. Lista do que esta parcial

- Modelo `visual_trigger`.
- Pipeline visual.
- S12.
- N2.
- Math templates em fluxo vivo.
- Oferta paga e controller de oferta.
- `PaidImageService`.
- Endpoint client `/api/generate-lesson-image`.
- UI de imagem na aula.
- Duvida com imagem.
- Anexos do objetivo.
- Revisao/recuperacao com visual.
- Eventos internos de credito/imagem.

## 15. Lista do que esta ausente

- N3 server judge/gerador SVG barato.
- Endpoint app equivalente ao Web com idempotency SQL, refund robusto, Replicate/Lovable gateway, retry e circuit breaker.
- Compressao de imagem da aula antes de cache/exibicao.
- Pub/sub real ligando imagem pronta ao painel de aula Flutter.

## 16. Lista do que existe mas nao esta conectado

- `LessonVisualPipeline` existe, mas a UI `LessonImagePanel` nao o usa.
- `LessonOrchestrator._fetchImage` existe, mas `_fetchText` nao copia `visualTrigger` do material T02 para `LessonContent`.
- `PaidImageService`/`internal_organs_governor.requestPaidImage` existem, mas nao estao provados no fluxo visual vivo da aula.

## 17. Lista do que nao deve ser copiado

- `src/lib/gemini-image.functions.ts` como caminho antigo.
- `src/lib/visual-trigger.ts` como contrato principal antigo.
- Mock Flutter `LabSession.requestLessonImage`.
- Geracao/cobranca direta sem oferta do aluno.
- Imagem bloqueando texto, pergunta ou navegacao.

## 18. Lista final para cidade C

1. Conectar o retorno T02 `visual_trigger` no Flutter em `LessonOrchestrator._fetchText`.
2. Substituir `LessonImagePanel`/`requestLessonImage` mock por exibicao de `CompleteLesson.imagem`/pipeline real.
3. Implementar ou adaptar N3 no app/API para cobrir `routeVisualServerFn`.
4. Alinhar `/root/sim-work/sim-api/src/media/image-controller.js` ao endpoint saudavel do SimWeb ou registrar decisao arquitetural equivalente.
5. Garantir oferta paga visual antes de qualquer chamada cara no Flutter.
6. Conectar aceite/recusa/comprar creditos da oferta paga na tela da aula.
7. Implementar compressao de imagem de aula se data URL continuar sendo armazenado/exibido.
8. Adicionar estado de erro visual nao bloqueante na UI Flutter.
9. Provar math templates no fluxo vivo Flutter com testes.
10. Provar N2/N3 e fallback para IA paga com testes.
11. Provar que background/prefetch nao cobra imagem paga sem acao do aluno.
12. Provar duvida com foto + visual gratuito opcional no Flutter contra Web.
13. Provar revisao/recuperacao herdam `visual_trigger`.
14. Revisar prompt oficial do app API para garantir T02 visual contract identico ao Web.

## 19. Prova de cobertura

Termos buscados: `image`, `imagem`, `visual`, `media`, `picture`, `photo`, `camera`, `gallery`, `upload`, `vision`, `diagram`, `diagrama`, `svg`, `canvas`, `chart`, `graph`, `grafico`, `gráfico`, `plot`, `axis`, `eixo`, `coordinate`, `coordenada`, `geometry`, `geometria`, `triangle`, `triângulo`, `angle`, `ângulo`, `circle`, `círculo`, `function graph`, `math`, `matemática`, `template`, `renderer`, `render`, `draw`, `desenhar`, `illustration`, `ilustração`, `paid`, `paid image`, `paid_image`, `image offer`, `offer`, `credits`, `créditos`, `cost`, `custo`, `cache`, `prefetch`, `dedupe`, `fallback`, `error`, `erro`, `T02`, `complete-lesson`, `lesson image`, `aula imagem`, `visual prompt`, `prompt visual`, `visual_router`, `visual pipeline`, `image controller`, `image service`, `image cache`.

Termos com 0 resultados registrados: `picture`, `paid image`, `lesson image`, `aula imagem`, `visual prompt`, `visual pipeline`, `image controller`, `image service`, `image cache`.

Arquivos analisados: todos os arquivos listados nas secoes 6 e 7, mais API propria em `/root/sim-work/sim-api/src/media/image-controller.js`, `src/app/router.js`, `src/credits/credits-store.js`, `src/t02/complete-lesson-controller.js`, `src/doubt/doubt-controller.js`.

Arquivos descartados: classificados na secao 8.

Fluxos rastreados:

- objetivo/anexo -> OCR/vision -> `attachments_text` -> perfil/T00/T02;
- T00/T02/adendos -> `visual_trigger`;
- T02 -> S12 -> SVG inline/math template/N2/N3/oferta paga;
- oferta paga -> aceite -> endpoint -> credito -> provider -> cache -> `subscribeLesson` -> aula;
- erro/fallback de imagem -> aula continua;
- duvida texto/foto -> T02 vision -> explicacao -> visual gratuito opcional;
- revisao/recuperacao -> T02 normal/adendos -> `visual_trigger`.

Imports/chamadas rastreadas:

- `LessonMainScreen` recebe `paidOffer`, `imagem`, `doubtImageUrl`.
- `useLessonMaterialController` assina `subscribeLesson` e `subscribePaidImageOffer`.
- `studentLessonMaterialService` chama `ensureVisualForReadyLesson`.
- `lesson-pipeline-runtime` chama S12, math templates, N2/N3, `offerPaidImage` e `fetchPaidLessonImage`.
- `fetchPaidLessonImage` chama `/api/generate-lesson-image`.
- `generate-lesson-image` chama RPCs de credito e provider externo.
- `useLessonDoubtController` chama `callT02ForDoubt` e `renderDoubtSoftwareVisual`.

Comportamentos encontrados: `IMG-WEB-001` a `IMG-WEB-035`.

Comportamentos saudaveis: `IMG-WEB-001` a `IMG-WEB-032`.

Doenca/legado: `IMG-WEB-033`, `IMG-WEB-034`, `IMG-WEB-035`.

Itens comparados com Flutter: todos os comportamentos saudaveis Web nas secoes 10 e 12.

Itens sem pendencia de classificacao: todos os candidatos por nome, os arquivos relevantes, os descartes por grupo, os endpoints Web/API e os fluxos UI/backend foram classificados como saudavel, parcial, ausente, legado ou doenca.

## 20. Veredito final: Estamos em B1?

SIM, estamos em B1 para inventario e comparacao do sistema de imagem.

Motivo: todos os termos obrigatorios foram buscados, os arquivos candidatos foram classificados, o fluxo principal e os fluxos laterais foram rastreados, os comportamentos receberam IDs, os saudaveis foram comparados com Flutter, e a lista fechada da cidade C esta definida.

Importante: estar em B1 nao significa que a paridade esteja pronta. O resultado de B1 e que a lista de trabalho para a cidade C ficou fechada.
