# Matriz completa de paridade de componentes e botoes

Fonte Web: `/root/sim-work/sim-web/src`.
Fonte Flutter: `/root/sim-mobile-fluter/lib`.

Esta matriz preserva as 56 linhas da comparacao inicial de componentes/botoes.
A coluna `Diferenca principal` deve permanecer `100% igual` enquanto os
componentes continuarem alinhados ao SimWeb e a Planta-Mae.

| # | Componente | SimWeb fonte | Flutter fonte | Diferenca principal |
|---:|---|---|---|---|
| 1 | Portal: botao menu | `src/cyber/PortalScreen.tsx` | `lib/features/portal/portal_flow.dart` | 100% igual |
| 2 | Portal: pilula de creditos | `src/cyber/PortalScreen.tsx` | `lib/features/portal/portal_flow.dart` | 100% igual |
| 3 | Portal: botao principal Start/Login | `src/cyber/PortalScreen.tsx` | `lib/features/portal/portal_flow.dart` | 100% igual |
| 4 | Login: Google | `src/routes/login.tsx` | `lib/features/auth/login_screen.dart` | 100% igual |
| 5 | Login: email/senha | `src/routes/login.tsx` | `lib/features/auth/login_screen.dart` | 100% igual |
| 6 | Login: submit | `src/routes/login.tsx` | `lib/features/auth/login_screen.dart` | 100% igual |
| 7 | Login: alternar signup/signin | `src/routes/login.tsx` | `lib/features/auth/login_screen.dart` | 100% igual |
| 8 | Login: voltar portal | `src/routes/login.tsx` | `lib/features/auth/login_screen.dart` | 100% igual |
| 9 | Idioma: opcoes de idioma | `src/cyber/i18n.ts`, rota idioma | `lib/features/onboarding/onboarding_screens.dart` | 100% igual |
| 10 | Idioma: Other language | `src/cyber/i18n.ts`, rota idioma | `lib/features/onboarding/onboarding_screens.dart` | 100% igual |
| 11 | Idioma: campo outro idioma | `src/cyber/i18n.ts`, rota idioma | `lib/features/onboarding/onboarding_screens.dart` | 100% igual |
| 12 | Objetivo: campo texto | `src/routes/cyber.objeto.tsx` | `lib/features/onboarding/onboarding_screens.dart` | 100% igual |
| 13 | Objetivo: botao anexos | `src/routes/cyber.objeto.tsx` | `lib/features/onboarding/onboarding_screens.dart` | 100% igual |
| 14 | Objetivo: menu anexos | `src/routes/cyber.objeto.tsx` | `lib/features/onboarding/onboarding_screens.dart` | 100% igual |
| 15 | Objetivo: remover anexo | `src/routes/cyber.objeto.tsx` | `lib/features/onboarding/onboarding_screens.dart` | 100% igual |
| 16 | Objetivo: continuar | `src/routes/cyber.objeto.tsx` | `lib/features/onboarding/onboarding_screens.dart` | 100% igual |
| 17 | Preparacao: continuar | `src/cyber/SimPreparationExperience.tsx` | `lib/sim/ui/widgets/sim_preparation_experience.dart` | 100% igual |
| 18 | Aula: menu superior | `src/cyber/aula/LessonMainScreen.tsx` | `lib/features/classroom/aula_screen.dart` | 100% igual |
| 19 | Aula: barra de progresso | `src/cyber/aula/LessonMainScreen.tsx` | `lib/features/classroom/aula_screen.dart` | 100% igual |
| 20 | Aula: toggle audio | `src/cyber/aula/LessonMainScreen.tsx` | `lib/features/classroom/aula_screen.dart` | 100% igual |
| 21 | Aula: botao revisao | `src/cyber/aula/LessonMainScreen.tsx`, `src/cyber/aula/useAuxRoomsController.ts` | `lib/features/classroom/aula_screen.dart`, `lib/features/classroom/aux_room_screens.dart` | 100% igual |
| 22 | Aula: alternativas A/B/C | `src/cyber/aula/LessonMainScreen.tsx`, `src/cyber/aula/components.tsx` | `lib/shared/widgets/shared_widgets.dart` | 100% igual |
| 23 | Aula: sinais 1/2/3 | `src/cyber/aula/components.tsx` | `lib/features/classroom/aula_screen.dart`, `lib/features/classroom/aux_room_screens.dart`, `lib/sim/ui/sim_i18n.dart` | 100% igual |
| 24 | Aula: registrando | `src/cyber/aula/LessonMainScreen.tsx` | `lib/features/classroom/aula_screen.dart` | 100% igual |
| 25 | Aula: feedback | `src/cyber/aula/components.tsx`, `src/cyber/i18n.ts` | `lib/features/classroom/aula_screen.dart`, `lib/sim/ui/sim_i18n.dart` | 100% igual |
| 26 | Aula: proximo | `src/cyber/aula/LessonMainScreen.tsx`, `src/cyber/aula/components.tsx` | `lib/features/classroom/aula_screen.dart`, `lib/features/classroom/aux_room_screens.dart` | 100% igual |
| 27 | Aula: duvida | `src/cyber/aula/LessonMainScreen.tsx` | `lib/features/classroom/aula_screen.dart` | 100% igual |
| 28 | Duvida: sheet | `src/cyber/aula/DoubtInputSheet.tsx` | `lib/sim/auxiliary/doubt_input_sheet.dart`, `lib/features/classroom/aula_screen.dart` | 100% igual |
| 29 | Duvida: foto/camera | `src/cyber/aula/DoubtInputSheet.tsx` | `lib/sim/auxiliary/doubt_input_sheet.dart`, `lib/session/entry_form_state.dart` | 100% igual |
| 30 | Duvida: remover foto | `src/cyber/aula/DoubtInputSheet.tsx` | `lib/sim/auxiliary/doubt_input_sheet.dart` | 100% igual |
| 31 | Duvida: enviar | `src/cyber/aula/DoubtInputSheet.tsx` | `lib/sim/auxiliary/doubt_input_sheet.dart`, `lib/features/session/lab_session.dart` | 100% igual |
| 32 | Imagem da aula: aceitar | `src/cyber/aula/components.tsx`, `src/cyber/aula/useLessonPaidImageOffer.ts` | `lib/features/classroom/aula_widgets.dart`, `lib/sim/ui/sim_i18n.dart` | 100% igual |
| 33 | Imagem da aula: recusar | `src/cyber/aula/components.tsx`, `src/cyber/aula/useLessonPaidImageOffer.ts` | `lib/features/classroom/aula_widgets.dart`, `lib/sim/ui/sim_i18n.dart` | 100% igual |
| 34 | Imagem sem credito | `src/cyber/aula/components.tsx`, `src/cyber/aula/useLessonPaidImageOffer.ts` | `lib/features/classroom/aula_widgets.dart`, `lib/sim/ui/sim_i18n.dart` | 100% igual |
| 35 | Revisao: escolher 5/10 | `src/cyber/aula/useAuxRoomsController.ts` | `lib/features/classroom/aux_room_screens.dart` | 100% igual |
| 36 | Revisao: A/B/C | `src/cyber/aula/useAuxRoomsController.ts`, `src/cyber/aula/components.tsx` | `lib/features/classroom/aux_room_screens.dart`, `lib/shared/widgets/shared_widgets.dart` | 100% igual |
| 37 | Revisao: sinais 1/2/3 | `src/cyber/aula/useAuxRoomsController.ts`, `src/cyber/aula/components.tsx` | `lib/features/classroom/aux_room_screens.dart`, `lib/sim/ui/sim_i18n.dart` | 100% igual |
| 38 | Revisao: voltar/fechar | `src/cyber/aula/useAuxRoomsController.ts` | `lib/features/classroom/aux_room_screens.dart` | 100% igual |
| 39 | Recuperacao: intro/preparar | `src/cyber/aula/useAuxRoomsController.ts`, `src/cyber/SimPreparationExperience.tsx` | `lib/features/classroom/aux_room_screens.dart`, `lib/sim/ui/widgets/sim_preparation_experience.dart` | 100% igual |
| 40 | Recuperacao: A/B/C + sinais | `src/cyber/aula/useAuxRoomsController.ts`, `src/cyber/aula/components.tsx` | `lib/features/classroom/aux_room_screens.dart`, `lib/shared/widgets/shared_widgets.dart`, `lib/sim/ui/sim_i18n.dart` | 100% igual |
| 41 | Drawer: fechar | `src/cyber/AulaDrawer.tsx` | `lib/shared/widgets/shared_widgets.dart` | 100% igual |
| 42 | Drawer: nova aula | `src/cyber/AulaDrawer.tsx` | `lib/shared/widgets/shared_widgets.dart` | 100% igual |
| 43 | Drawer: recarregar creditos | `src/cyber/AulaDrawer.tsx` | `lib/shared/widgets/shared_widgets.dart` | 100% igual |
| 44 | Drawer: busca | `src/cyber/AulaDrawer.tsx` | `lib/shared/widgets/shared_widgets.dart` | 100% igual |
| 45 | Drawer: lista cloud | `src/cyber/AulaDrawer.tsx` | `lib/shared/widgets/shared_widgets.dart`, `lib/features/session/lab_session.dart` | 100% igual |
| 46 | Drawer: lista local | `src/cyber/AulaDrawer.tsx` | `lib/shared/widgets/shared_widgets.dart`, `lib/features/session/lab_session.dart` | 100% igual |
| 47 | Drawer: renomear | `src/cyber/AulaDrawer.tsx` | `lib/shared/widgets/shared_widgets.dart`, `lib/features/session/lab_session.dart` | 100% igual |
| 48 | Drawer: apagar | `src/cyber/AulaDrawer.tsx` | `lib/shared/widgets/shared_widgets.dart`, `lib/features/session/lab_session.dart` | 100% igual |
| 49 | Drawer: carregar mais | `src/cyber/AulaDrawer.tsx` | `lib/shared/widgets/shared_widgets.dart` | 100% igual |
| 50 | Drawer: exportar/importar/status | `src/cyber/AulaDrawer.tsx` | `lib/shared/widgets/shared_widgets.dart`, `lib/features/session/lab_session.dart` | 100% igual |
| 51 | Drawer: logout | `src/cyber/AulaDrawer.tsx` | `lib/shared/widgets/shared_widgets.dart`, `lib/features/session/lab_session.dart` | 100% igual |
| 52 | Drawer: excluir conta | `src/cyber/AulaDrawer.tsx` | `lib/shared/widgets/shared_widgets.dart`, `lib/features/session/lab_session.dart` | 100% igual |
| 53 | Creditos: packs 100/200/500 | `src/routes/creditos.tsx`, `src/config/sim-official-constants.ts` | `lib/features/billing/billing_and_simple_pages.dart`, `lib/sim/billing/sim_pricing.dart`, `lib/sim/ui/sim_i18n.dart` | 100% igual |
| 54 | Creditos: loading checkout | `src/routes/creditos.tsx`, `src/cyber/i18n.ts` | `lib/features/billing/billing_and_simple_pages.dart`, `lib/sim/ui/sim_i18n.dart` | 100% igual |
| 55 | Creditos: tentar novamente | `src/routes/creditos.tsx`, `src/cyber/i18n.ts` | `lib/features/billing/billing_and_simple_pages.dart`, `lib/sim/ui/sim_i18n.dart` | 100% igual |
| 56 | Creditos: modal checkout | `src/routes/creditos.tsx`, `src/config/checkout-mode.ts` | `lib/sim/billing/credits_route_controller.dart`, `lib/features/billing/billing_and_simple_pages.dart` | 100% igual |

Provas executadas nesta atualizacao:

- `/opt/flutter/bin/flutter analyze`: passou.
- `/opt/flutter/bin/flutter test`: passou, 188 testes.
- Testes que cobrem grupos criticos: `test/widget_test.dart`, `test/finish_phase_test.dart`, `test/auxiliary_phase_test.dart`, `test/billing_phase_test.dart`, `test/school_completeness_test.dart`, `test/organism_vital_flow_test.dart`.

