// ignore_for_file: unused_import, unnecessary_import
import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../sim/billing/sim_server_billing_clients.dart';
import '../../sim/cloud/sim_server_cloud_functions.dart';
import '../../sim/cloud/supabase_flutter_session_provider.dart';
import '../../sim/cloud/supabase_student_state_cloud_storage.dart';
import '../../sim/config/sim_environment.dart';
import '../../sim/external_ai/sim_ai_server_config.dart';
import '../../sim/external_ai/sim_server_ai_clients.dart';
import '../../sim/external_ai/sim_server_attachment_client.dart';
import '../../sim/classroom/classroom_models.dart';
import '../../sim/classroom/lesson_runtime_engine.dart';
import '../../sim/classroom/lesson_main_view_model.dart';
import '../../sim/experience/student_experience_types.dart';
import '../../sim/organism/sim_organism.dart';
import '../../sim/organism/sim_organism_provider.dart';
import '../../session/auth_session.dart';
import '../../session/entry_form_state.dart';
import '../../session/lesson_ui_state.dart';
import '../../session/navigation_state.dart';
import '../../sim/lesson/lesson_models.dart';
import '../../sim/media/audio_core.dart';
import '../../sim/media/audio_preference.dart';
import '../../sim/media/lesson_audio_controller.dart';
import '../../sim/media/student_lesson_media_service.dart';
import '../../sim/state/shared_prefs_state_storage.dart';
import '../../sim/state/student_learning_state.dart';
import '../../sim/state/student_state_store.dart';
import '../../sim/ui/sim_i18n.dart';
import '../../sim/ui/widgets/cyber_step_shell.dart';
import '../../sim/ui/widgets/sim_preparation_experience.dart';
import '../../sim/ui/widgets/sim_typewriter.dart';
import '../../sim/auxiliary/aux_room_models.dart';
import '../../sim/ui/widgets/doubt_progress_bar.dart';

import '../../core/utils/sim_constants.dart';
import '../session/lab_session.dart';
import '../portal/portal_flow.dart';
import '../auth/login_screen.dart';
import '../onboarding/onboarding_screens.dart';
import '../onboarding/preparation_and_placement.dart';
import '../classroom/aula_screen.dart';
import '../classroom/aux_room_screens.dart';
import '../classroom/aula_widgets.dart';
import '../billing/billing_and_simple_pages.dart';
import '../../shared/widgets/shared_widgets.dart';
class SimFrame extends StatelessWidget {
  const SimFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: simDark,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: child,
        ),
      ),
    );
  }
}

class PortalScreen extends StatelessWidget {
  const PortalScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final displayBalance = session.authed ? session.credits : 0;
    return Scaffold(
      body: Stack(
        children: [
          const BackgroundDecor(),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        session.authed
                            ? RoundIconButton(
                                icon: Icons.menu,
                                tooltip: 'Open lessons menu',
                                onTap: () => _showLabDrawer(context),
                              )
                            : const SizedBox(width: 48, height: 48),
                        CreditsPill(
                          value: displayBalance,
                          onTap: session.openCredits,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    PortalHeroCard(session: session),
                    const SizedBox(height: 16),
                    const Text(
                      'SIM v1  â€¢  Cyber-Premium',
                      style: TextStyle(
                        color: simMuted,
                        fontSize: 12,
                        fontFamily: kMono,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    HelpCard(session: session),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: pillDecoration(),
                        child: const Text(
                          '1/5',
                          style: TextStyle(
                            color: simMuted,
                            fontSize: 12,
                            fontFamily: kMono,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLabDrawer(BuildContext context) {
    showSimDrawer(
      context,
      session: session,
      body: (ctx) => _PortalDrawerBody(session: session, ctx: ctx),
    );
  }
}

class _PortalDrawerBody extends StatelessWidget {
  const _PortalDrawerBody({required this.session, required this.ctx});

  final LabSession session;
  final BuildContext ctx;

  @override
  Widget build(BuildContext context) {
    void close() => Navigator.of(ctx).pop();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MenuLine(
          label: 'Abrir aula',
          onTap: () {
            close();
            session.openSupport('/cyber/aula');
          },
        ),
        MenuLine(
          label: t('recarregar_creditos'),
          onTap: () {
            close();
            session.openCredits();
          },
        ),
        MenuLine(
          label: 'Painel do Pai',
          onTap: () {
            close();
            session.openSupport('/pai');
          },
        ),
        MenuLine(
          label: 'Privacidade',
          onTap: () {
            close();
            session.openSupport('/privacidade');
          },
        ),
        MenuLine(
          label: 'Termos',
          onTap: () {
            close();
            session.openSupport('/termos');
          },
        ),
        MenuLine(
          label: 'Solicitar exclusÃ£o da conta',
          onTap: () {
            close();
            session.openSupport('/conta/deletar');
          },
        ),
      ],
    );
  }
}

class PortalHeroCard extends StatelessWidget {
  const PortalHeroCard({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
      decoration: glassDecoration(radius: 28),
      child: Column(
        children: [
          SizedBox(
            width: 132,
            height: 132,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 152,
                  height: 152,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: simDark.withAlpha(31)),
                  ),
                ),
                Container(
                  width: 132,
                  height: 132,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: simBorder),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33111827),
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/monkey-logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Â§3.3(b) tÃ­tulo SIM
          const Text(
            'SIM',
            style: TextStyle(
              color: simDark,
              fontSize: 68,
              height: 1,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.36, // -0.02em de 68px
            ),
          ),
          // Â§3.3(c) tagline
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 32,
                child: Divider(color: simMid, thickness: 1),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  t('portal_tagline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: simDark,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const SizedBox(
                width: 32,
                child: Divider(color: simMid, thickness: 1),
              ),
            ],
          ),
          // Â§3.3(d) parÃ¡grafo institucional
          const SizedBox(height: 24),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 34 * 9.5),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${t('portal_statement_p1')} '),
                  TextSpan(
                    text: t('portal_statement_real_learning'),
                    style: const TextStyle(
                      color: simDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: t('portal_statement_p2')),
                  TextSpan(text: '${t('portal_statement_p3')} '),
                  TextSpan(
                    text: t('portal_statement_real_progress'),
                    style: const TextStyle(
                      color: simDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: '.'),
                ],
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: simMuted,
                fontSize: 15.5,
                height: 1.55,
              ),
            ),
          ),
          // Â§3.3(e) botÃ£o principal
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: DecoratedBox(
              decoration: primaryButtonDecoration(radius: 16),
              child: TextButton(
                onPressed: session.start,
                style: TextButton.styleFrom(
                  foregroundColor: simDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Mini cÃ­rculo branco 36Ã—36 com Ã­cone Play
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: simBorder),
                      ),
                      child: const Icon(
                        Icons.play_arrow,
                        size: 16,
                        color: simDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        session.authed
                            ? t('portal_btn_start')
                            : t('portal_btn_signin'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: simDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HelpCard extends StatelessWidget {
  const HelpCard({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: glassDecoration(radius: 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: simLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: simBorder),
                ),
                child: const Icon(
                  Icons.favorite_border,
                  color: simDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t('portal_help_title'),
                      style: const TextStyle(
                        color: simDark,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t('portal_help_body'),
                      style: const TextStyle(
                        color: simMuted,
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 12,
            children: [
              ContactButton(
                asset: 'assets/whatsapp-logo.png',
                label: 'Contact us on WhatsApp',
                onTap: () => session.openExternalDoor(
                  'https://wa.me/message/RLCYEXAYFUIIA1',
                ),
              ),
              ContactButton(
                asset: 'assets/messenger-logo.png',
                label: 'Contact us on Messenger',
                onTap: () =>
                    session.openExternalDoor('https://m.me/61557707493807'),
              ),
            ],
          ),
          if (session.externalDoorOpened != null) ...[
            const SizedBox(height: 10),
            Text(
              'Porta externa: ${session.externalDoorOpened}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: simMuted,
                fontSize: 11,
                fontFamily: kMono,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ContactButton extends StatelessWidget {
  const ContactButton({
    required this.asset,
    required this.label,
    required this.onTap,
    super.key,
  });

  final String asset;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: simBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33243447),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(<double>[
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0.2126,
              0.7152,
              0.0722,
              0,
              0,
              0,
              0,
              0,
              1,
              0,
            ]),
            child: Image.asset(asset, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }
}




