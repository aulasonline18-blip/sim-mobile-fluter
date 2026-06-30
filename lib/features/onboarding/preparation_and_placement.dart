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

class PhaseBoundaryScreen extends StatefulWidget {
  const PhaseBoundaryScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<PhaseBoundaryScreen> createState() => _PhaseBoundaryScreenState();
}

class _PhaseBoundaryScreenState extends State<PhaseBoundaryScreen> {
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _launch());
  }

  void _launch() {
    if (_started) return;
    _started = true;
    unawaited(widget.session.launchExperience());
  }

  String _toSimStage(String status) => switch (status) {
    'pedido_recebido' => 'profile',
    't00_running' => 'curriculum',
    't02_running' => 'lesson',
    'placement' => 'placement',
    'primeira_aula_pronta' => 'done',
    'erro' => 'error',
    _ => 'generic',
  };

  @override
  Widget build(BuildContext context) {
    final status = widget.session.entryStatus;
    final error = widget.session.entryError;
    final isError = status == 'erro';
    final isCredits =
        error?.toLowerCase().contains('crédito') == true ||
        error?.toLowerCase().contains('credit') == true;
    final simStage = _toSimStage(status);
    final isReady = status == 'primeira_aula_pronta';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: isError
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    constraints: const BoxConstraints(maxWidth: 448),
                    decoration: glassDecoration(radius: 18),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Não consegui preparar agora.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: simDark,
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            error,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: simMuted,
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (isCredits)
                          PrimaryWideButton(
                            label: t('aula_buy_credits'),
                            onTap: () => widget.session.openCredits(),
                          )
                        else
                          PrimaryWideButton(
                            label: 'Tentar novamente',
                            onTap: () {
                              _started = false;
                              _launch();
                            },
                          ),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: () =>
                              widget.session.openSupport('/cyber/objeto'),
                          child: const Text(
                            'Trocar objetivo',
                            style: TextStyle(
                              color: simMuted,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  children: [
                    // invisible debug labels
                    Text(
                      widget.session.route,
                      style: const TextStyle(
                        color: Colors.transparent,
                        fontSize: 1,
                      ),
                    ),
                    Text(
                      'entry.status: $status',
                      style: const TextStyle(
                        color: Colors.transparent,
                        fontSize: 1,
                      ),
                    ),
                    Expanded(
                      child: widget.session.prefs == null
                          ? const SizedBox.shrink()
                          : SingleChildScrollView(
                              child: SimPreparationExperience(
                                stage: simStage,
                                ready: isReady,
                                onContinue: () {
                                  _started = false;
                                  _launch();
                                },
                              ),
                            ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class PlacementLabScreen extends StatefulWidget {
  const PlacementLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<PlacementLabScreen> createState() => _PlacementLabScreenState();
}

// NV-1..NV-4: Nivelamento 4-step sub-flow inside CyberStepShell
// step 1/4 = Choice, 2/4 = Intro, 3/4 = Question, 4/4 = Result
class _PlacementLabScreenState extends State<PlacementLabScreen> {
  // sub-step within placement: 1=choice, 2=intro, 3=question, 4=result
  int _subStep = 1;
  bool _preparing = false;

  void _goToIntro() => setState(() => _subStep = 2);
  void _goToQuestion() async {
    setState(() => _preparing = true);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) {
      setState(() {
        _subStep = 3;
        _preparing = false;
      });
    }
  }

  void _goToResult() => setState(() => _subStep = 4);

  @override
  Widget build(BuildContext context) {
    return CyberStepShell(step: _subStep, total: 4, child: _buildSubStep());
  }

  Widget _buildSubStep() {
    switch (_subStep) {
      case 1:
        return _PlacementChoice(
          onBeginning: widget.session.skipPlacement,
          onQuick: _goToIntro,
        );
      case 2:
        return _PlacementIntro(
          onStart: _preparing ? null : _goToQuestion,
          preparing: _preparing,
        );
      case 3:
        return _PlacementQuestion(session: widget.session, onDone: _goToResult);
      case 4:
        return _PlacementResult(
          session: widget.session,
          onContinue: widget.session.finishPlacement,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// NV-1: Choice screen
class _PlacementChoice extends StatelessWidget {
  const _PlacementChoice({required this.onBeginning, required this.onQuick});
  final VoidCallback onBeginning;
  final VoidCallback onQuick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('placement_choice_h1'),
          style: const TextStyle(
            color: simDark,
            fontSize: 28,
            height: 1.12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t('placement_choice_body'),
          style: const TextStyle(color: simMuted, fontSize: 17, height: 1.45),
        ),
        const SizedBox(height: 32),
        PrimaryWideButton(
          label: t('placement_start_beginning'),
          onTap: onBeginning,
        ),
        const SizedBox(height: 12),
        SecondaryWideButton(label: t('placement_take_quick'), onTap: onQuick),
      ],
    );
  }
}

// NV-2: Intro screen
class _PlacementIntro extends StatelessWidget {
  const _PlacementIntro({required this.onStart, required this.preparing});
  final VoidCallback? onStart;
  final bool preparing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('placement_intro_h1'),
          style: const TextStyle(
            color: simDark,
            fontSize: 28,
            height: 1.12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t('placement_intro_body'),
          style: const TextStyle(color: simMuted, fontSize: 17, height: 1.45),
        ),
        const SizedBox(height: 32),
        PrimaryWideButton(
          label: preparing ? t('placement_preparing') : t('placement_start'),
          onTap: onStart ?? () {},
        ),
      ],
    );
  }
}

// NV-3: Question screen
class _PlacementQuestion extends StatelessWidget {
  const _PlacementQuestion({required this.session, required this.onDone});
  final LabSession session;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('placement_question_of', {'n': '1', 'total': '1'}),
          style: TextStyle(
            fontFamily: kMono,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: simMuted,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Qual alternativa descreve melhor seu conhecimento atual?',
          style: TextStyle(
            color: simDark,
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        SecondaryWideButton(label: 'A. Domino bem', onTap: onDone),
        const SizedBox(height: 8),
        SecondaryWideButton(label: 'B. Sei uma parte', onTap: onDone),
        const SizedBox(height: 8),
        SecondaryWideButton(label: 'C. Preciso começar guiado', onTap: onDone),
      ],
    );
  }
}

// NV-4: Result screen
class _PlacementResult extends StatelessWidget {
  const _PlacementResult({required this.session, required this.onContinue});
  final LabSession session;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('placement_result_h1'),
          style: const TextStyle(
            color: simDark,
            fontSize: 28,
            height: 1.12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          t('placement_result_body'),
          style: const TextStyle(color: simMuted, fontSize: 17, height: 1.45),
        ),
        const SizedBox(height: 32),
        PrimaryWideButton(label: t('continue'), onTap: onContinue),
      ],
    );
  }
}

// Loading card copy â€” mirrors entryLoadingCopy() in LessonMainScreen.tsx
(String, String) loadingCopy(String status) => switch (status) {
  'pedido_recebido' => (
    'Recebi seu pedido.',
    'A sala já abriu. Estou começando a entender seu objetivo.',
  ),
  't00_running' => (
    'Entendendo seu objetivo...',
    'Estou montando seu perfil e procurando o primeiro tema.',
  ),
  'first_item_ready' => (
    'Primeiro tema encontrado.',
    'Já tenho o ponto inicial. Agora vou preparar a primeira explicação.',
  ),
  't02_running' || 't02_first_lesson_running' => (
    'Preparando sua primeira aula...',
    'O professor já recebeu o primeiro tema e está escrevendo a explicação.',
  ),
  'primeira_aula_pronta' || 'first_lesson_ready' => (
    'A primeira aula chegou.',
    'Estou abrindo o material.',
  ),
  'failed_t00' => (
    'Não consegui entender o objetivo.',
    'Tente novamente com uma descrição um pouco mais direta do que deseja estudar.',
  ),
  'failed_t02' => (
    'Não consegui preparar a aula.',
    'Tente novamente. Se persistir, o servidor pode estar temporariamente indisponível.',
  ),
  'blocked_credits' => (
    'Créditos insuficientes.',
    'Adicione créditos para gerar a próxima aula real.',
  ),
  _ => (
    t('preparing_lesson'),
    'A sala já abriu. Estou buscando a explicação do primeiro tema.',
  ),
};

String feedbackText(String key) => switch (key) {
  'aula_fb_correct' => 'Exato! Você domina este ponto.',
  'aula_fb_correct_rev' => 'Certo, mas vamos reforçar.',
  'aula_fb_dont_know' => 'Acertou no chute. Vamos revisar com cuidado.',
  'aula_fb_redo' => 'Não foi dessa vez. Vamos tentar de novo.',
  'aula_fb_review_none' => 'Ótimo! Revisão concluída.',
  'aula_fb_review_light' => 'Quase lá. Mais um reforço.',
  'aula_fb_review_heavy' => 'Precisa de mais prática neste ponto.',
  _ => key,
};

String nextBtnText(String key) => switch (key) {
  'aula_next' => 'Próximo',
  'aula_next_item' => 'Próximo tópico',
  'aula_consolidate' => 'Consolidar',
  'aula_layer_label_2' => 'Próxima camada',
  'aula_layer_label_3' => 'Camada final',
  _ => 'Avançar',
};

String headerLabelText(String key) {
  if (key.startsWith('aula_item_of:')) {
    final rest = key.substring('aula_item_of:'.length);
    final parts = rest.split(':');
    final fraction = parts.isNotEmpty ? parts[0] : '';
    final layerKey = parts.length > 1 ? parts[1] : '';
    final layer = switch (layerKey) {
      'aula_layer_1' => 'Camada 1',
      'aula_layer_2' => 'Camada 2',
      'aula_layer_3' => 'Camada 3',
      _ => layerKey,
    };
    return 'Item $fraction · $layer';
  }
  if (key.startsWith('aula_review_review:')) return 'Revisão';
  return key;
}
