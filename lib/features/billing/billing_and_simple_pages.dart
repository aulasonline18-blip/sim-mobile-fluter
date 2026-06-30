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

class CreditsLabScreen extends StatelessWidget {
  const CreditsLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SimCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cr\u00e9ditos',
                  style: TextStyle(
                    color: simDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Saldo atual: ${session.credits}',
                  style: const TextStyle(color: simMuted, fontSize: 15),
                ),
                const SizedBox(height: 18),
                CreditPackButton(
                  title: '100 cr\u00e9ditos',
                  subtitle: t('pay_pack_lessons_100'),
                  onTap: session.openCheckoutReturn,
                ),
                CreditPackButton(
                  title: '200 cr\u00e9ditos',
                  subtitle: t('pay_pack_lessons_200'),
                  onTap: session.openCheckoutReturn,
                ),
                CreditPackButton(
                  title: '500 cr\u00e9ditos',
                  subtitle: t('pay_pack_lessons_500'),
                  onTap: session.openCheckoutReturn,
                ),
                const SizedBox(height: 16),
                PrimaryWideButton(
                  label: 'Voltar para aula',
                  onTap: () => session.openSupport('/cyber/aula'),
                ),
                const SizedBox(height: 10),
                SecondaryWideButton(label: 'Portal', onTap: session.goPortal),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreditPackButton extends StatelessWidget {
  const CreditPackButton({
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: simDark,
          side: const BorderSide(color: simBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.all(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.credit_card, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(color: simMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CheckoutReturnScreen extends StatelessWidget {
  const CheckoutReturnScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return SimpleLabPage(
      title: 'Retorno do pagamento',
      body:
          'O pagamento volta para o SIM, valida a sess\u00e3o do checkout e devolve o aluno para a aula ou para tentar novamente.',
      primary: 'Continuar aula',
      onPrimary: () => session.openSupport('/cyber/aula'),
      session: session,
      secondary: 'Tentar de novo',
      onSecondary: session.openCredits,
    );
  }
}

class FatherLabScreen extends StatelessWidget {
  const FatherLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return SimpleLabPage(
      title: 'Painel do Pai',
      body:
          'Resumo vivo: idioma ${session.stableLang ?? '-'}, objetivo ${session.freeText.isEmpty ? '-' : session.freeText}, item ${session.currentAulaItemNumber}, camada ${session.currentAulaLayer.value}.',
      primary: 'Voltar',
      onPrimary: () => session.openSupport('/cyber/aula'),
      session: session,
    );
  }
}

class LegalLabScreen extends StatelessWidget {
  const LegalLabScreen({required this.session, required this.title, super.key});

  final LabSession session;
  final String title;

  @override
  Widget build(BuildContext context) {
    return SimpleLabPage(
      title: title,
      body: title == 'Privacidade'
          ? 'P\u00e1gina de privacidade preservada como ambiente de apoio do SIM.'
          : 'P\u00e1gina de termos preservada como ambiente de apoio do SIM.',
      primary: 'Voltar',
      onPrimary: () => session.openSupport('/cyber/aula'),
      session: session,
    );
  }
}

class DeleteAccountLabScreen extends StatelessWidget {
  const DeleteAccountLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SimCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solicitar exclus\u00e3o da conta',
                  style: TextStyle(
                    color: simDark,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Digite DELETAR para registrar a solicita\u00e7\u00e3o de exclus\u00e3o. A execu\u00e7\u00e3o real acontece no servidor, sem chave secreta dentro do app.',
                  style: TextStyle(color: simMuted, fontSize: 15, height: 1.45),
                ),
                const SizedBox(height: 16),
                SimInput(
                  hint: 'DELETAR',
                  onChanged: session.setDeleteConfirmation,
                ),
                if (session.accountDeletionMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    session.accountDeletionMessage!,
                    style: const TextStyle(
                      color: simDark,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                PrimaryWideButton(
                  label: 'Solicitar exclus\u00e3o da conta',
                  onTap: session.requestAccountDeletion,
                ),
                const SizedBox(height: 10),
                SecondaryWideButton(
                  label: 'Voltar',
                  onTap: () => session.openSupport('/cyber/aula'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SimpleLabPage extends StatelessWidget {
  const SimpleLabPage({
    required this.title,
    required this.body,
    required this.primary,
    required this.onPrimary,
    required this.session,
    this.secondary,
    this.onSecondary,
    super.key,
  });

  final String title;
  final String body;
  final String primary;
  final VoidCallback onPrimary;
  final LabSession session;
  final String? secondary;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SimCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: simDark,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    style: const TextStyle(
                      color: simMuted,
                      fontSize: 15,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryWideButton(label: primary, onTap: onPrimary),
                  const SizedBox(height: 10),
                  if (secondary != null && onSecondary != null) ...[
                    SecondaryWideButton(label: secondary!, onTap: onSecondary!),
                    const SizedBox(height: 10),
                  ],
                  SecondaryWideButton(label: 'Portal', onTap: session.goPortal),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
