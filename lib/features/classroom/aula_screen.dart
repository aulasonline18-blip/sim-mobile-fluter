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

class AulaLabScreen extends StatefulWidget {
  const AulaLabScreen({required this.session, super.key});

  final LabSession session;

  @override
  State<AulaLabScreen> createState() => _AulaLabScreenState();
}

class _AulaLabScreenState extends State<AulaLabScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _doubtController = TextEditingController();
  int _lastHistoryLen = 0;
  bool _lastHasContent = false;
  bool _doubtSheetOpen = false;
  String? _theoryDoneKey;
  AnswerLetter? _localAnswerSel;
  final bool _localExpanded = false;
  final GlobalKey _activeKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSessionChange);
  }

  void _onSessionChange() {
    final snap = widget.session.aulaSnapshot;
    final history = snap?.history ?? const <QuestionHistoryEntry>[];
    final hasContent = snap?.conteudo != null;
    if (history.length != _lastHistoryLen || hasContent != _lastHasContent) {
      _lastHistoryLen = history.length;
      _lastHasContent = hasContent;
      _scrollToNewQuestion(_activeKey);
    }
    if (mounted) setState(() {});
    final open = widget.session.doubtOpen;
    if (open && !_doubtSheetOpen) {
      _doubtSheetOpen = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDoubtSheet());
    }
  }

  void _showDoubtSheet() {
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DoubtInputSheet(
        controller: _doubtController,
        onSubmit: (text) {
          widget.session.toggleDoubt();
          _doubtController.clear();
        },
        onClose: () {
          widget.session.toggleDoubt();
          _doubtController.clear();
        },
      ),
    ).whenComplete(() {
      _doubtSheetOpen = false;
      if (widget.session.doubtOpen) widget.session.toggleDoubt();
    });
  }

  @override
  void dispose() {
    widget.session.removeListener(_onSessionChange);
    _scrollController.dispose();
    _doubtController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _scrollToNewQuestion(GlobalKey targetKey) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = targetKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final snapshot = session.aulaSnapshot;
    final phase = snapshot?.phase;
    final content = snapshot?.conteudo;
    final history = snapshot?.history ?? const <QuestionHistoryEntry>[];
    final viewModel = snapshot?.viewModel;
    final selected = phase?.letter;
    final isExpanded = phase?.type == ClassroomPhaseType.expandida;
    final isProcessing = phase?.type == ClassroomPhaseType.processando;
    final isCompleted = phase?.type == ClassroomPhaseType.concluido;
    final isEngineError = phase?.type == ClassroomPhaseType.erroEngine;
    final isDone = snapshot?.isDone ?? false;
    final wasCorrect = phase?.wasCorrect;
    final feedbackKey = phase?.message;
    final nextKey = viewModel?.nextLabel ?? '';
    final locked = viewModel?.locked ?? false;
    // Effective answer selection â€” uses local state when runtime has no position
    final effectiveSelected = content != null ? selected : _localAnswerSel;
    final effectiveExpanded = content != null ? isExpanded : _localExpanded;
    // Gate question display until typewriter finishes (visualTheoryReady).
    // _theoryDoneKey is set by SimTypewriter.onDone and cleared to null when a
    // new explanation arrives (SimTypewriter restarts itself via didUpdateWidget,
    // so _theoryDoneKey becomes stale automatically).
    final explanationKey = content?.explanation;
    final theoryReady = session.prefs == null
        ? content != null
        : explanationKey != null && _theoryDoneKey == explanationKey;

    if (isDone) {
      return LessonDoneScreen(session: session);
    }

    // Full-screen review/recovery room overlays
    if (session.reviewRoom != null) {
      return ReviewRoomScreen(session: session);
    }
    if (session.recoveryRoom != null) {
      return RecoveryRoomScreen(session: session);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 112, 16, 128),
              children: [
                // Past answered questions â€” dimmed, non-interactive
                // Sliding window: last 4 entries keep image, older entries show text only
                Builder(
                  builder: (context) {
                    final imageCutoff = (history.length - 4).clamp(
                      0,
                      history.length,
                    );
                    return Column(
                      children: [
                        for (var i = 0; i < history.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Opacity(
                              opacity: 0.6,
                              child: IgnorePointer(
                                child: _QuestionHistoryBlock(
                                  entry: history[i],
                                  showImage: i >= imageCutoff,
                                ),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),

                // Active content card
                if (session.aulaRuntimeLoading && content == null) ...[
                  const SizedBox(height: 8),
                  // AUL-3: Loading phase â€” glass-soft card matching LessonMainScreen.tsx
                  Container(
                    constraints: const BoxConstraints(minHeight: 280),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: simBorder),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F111827),
                          blurRadius: 16,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x1A21B2E9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                t('aula_theory').toUpperCase(),
                                style: TextStyle(
                                  fontFamily: kMono,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: simDark,
                                  letterSpacing: 2.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Builder(
                          builder: (_) {
                            final copy = loadingCopy(session.entryStatus);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  copy.$1,
                                  style: const TextStyle(
                                    color: simDark,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  copy.$2,
                                  style: const TextStyle(
                                    color: simMuted,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            height: 8,
                            color: const Color(0x14000000),
                            child: const _PulseBar(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => unawaited(session.openAulaRuntime()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0x0F000000),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: simBorder),
                            ),
                            child: Text(
                              t('aula_try_again_2'),
                              style: const TextStyle(
                                color: simDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Theory card â€” only when content is loaded
                if (content != null) ...[
                  SimCard(
                    key: _activeKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AUL-4: TEORIA section label
                        Row(
                          children: [
                            Text(
                              t('aula_theory'),
                              style: TextStyle(
                                fontFamily: kMono,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: simMuted,
                                letterSpacing: 1.2,
                              ),
                            ),
                            if (viewModel != null) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '· ${headerLabelText(viewModel.headerLabel)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: simMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (session.prefs == null)
                          Text(
                            content.explanation,
                            style: const TextStyle(
                              color: simDark,
                              fontSize: 15,
                              height: 1.45,
                            ),
                          )
                        else
                          SimTypewriter(
                            text: content.explanation,
                            style: const TextStyle(
                              color: simDark,
                              fontSize: 15,
                              height: 1.45,
                            ),
                            onTick: _scrollToBottom,
                            onDone: () {
                              setState(
                                () => _theoryDoneKey = content.explanation,
                              );
                              _scrollToBottom();
                            },
                          ),
                        // Doubt: processing â†’ progress bar
                        if (session.doubt.status == DoubtStatus.processing) ...[
                          const SizedBox(height: 12),
                          DoubtProgressBar(
                            progress: session.doubt.progress.toDouble(),
                            label: 'Analisando sua dúvida...',
                          ),
                        ],
                        // Doubt: explaining / error â†’ explanation card
                        if (session.doubt.status == DoubtStatus.explaining ||
                            session.doubt.status == DoubtStatus.error) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: simBorder),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x59111827),
                                  blurRadius: 30,
                                  spreadRadius: -24,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Explicação da sua dúvida',
                                  style: TextStyle(
                                    color: simDark,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                if (session.doubt.error != null)
                                  Text(
                                    session.doubt.error!,
                                    style: const TextStyle(
                                      color: simMuted,
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  )
                                else if (session.doubt.response != null)
                                  Text(
                                    session.doubt.response!.explanation,
                                    style: const TextStyle(
                                      color: simDark,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        LessonImagePanel(session: session),
                        const SizedBox(height: 8),
                        if (session.audioLoading) ...[
                          const StatusLine(
                            icon: Icons.volume_up_outlined,
                            text: 'Preparando audio da aula...',
                            loading: true,
                          ),
                        ] else if (session.audioError != null) ...[
                          StatusLine(
                            icon: Icons.volume_off_outlined,
                            text: session.audioError!,
                          ),
                        ] else if (session.audioEnabled) ...[
                          StatusLine(
                            icon: Icons.volume_up_outlined,
                            text: 'Audio da aula ligado',
                            onTap: session.toggleAudio,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                if (content == null) ...[
                  SimCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LessonImagePanel(session: session),
                        const SizedBox(height: 8),
                        if (session.audioLoading) ...[
                          const StatusLine(
                            icon: Icons.volume_up_outlined,
                            text: 'Preparando audio da aula...',
                            loading: true,
                          ),
                        ] else if (session.audioError != null) ...[
                          StatusLine(
                            icon: Icons.volume_off_outlined,
                            text: session.audioError!,
                          ),
                        ] else if (session.audioEnabled) ...[
                          StatusLine(
                            icon: Icons.volume_up_outlined,
                            text: 'Audio da aula ligado',
                            onTap: session.toggleAudio,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Challenge/question block â€” hidden while doubt sheet is open to avoid duplicate B. finders
                if (!session.doubtOpen && theoryReady && content != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Expanded(child: Divider(color: simBorder)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Text(
                            t('aula_challenge'),
                            style: TextStyle(
                              fontFamily: kMono,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: simMuted,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        const Expanded(child: Divider(color: simBorder)),
                      ],
                    ),
                  ),
                  SimCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content.question,
                          style: const TextStyle(
                            color: simDark,
                            fontSize: 15,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnswerButton(
                          label: 'A',
                          text: content.options[AnswerLetter.A] ?? '',
                          active: effectiveSelected == AnswerLetter.A,
                          enabled: !locked,
                          onTap: () => session.chooseAulaAnswer('A'),
                        ),
                        AnswerButton(
                          label: 'B',
                          text: content.options[AnswerLetter.B] ?? '',
                          active: effectiveSelected == AnswerLetter.B,
                          enabled: !locked,
                          onTap: () => session.chooseAulaAnswer('B'),
                        ),
                        AnswerButton(
                          label: 'C',
                          text: content.options[AnswerLetter.C] ?? '',
                          active: effectiveSelected == AnswerLetter.C,
                          enabled: !locked,
                          onTap: () => session.chooseAulaAnswer('C'),
                        ),

                        // Sinal 1/2/3 â€” appears after A/B/C selection
                        if (effectiveExpanded) ...[
                          const SizedBox(height: 14),
                          _SinalRow(onSignal: session.submitAulaSignal),
                        ],

                        if (isProcessing) ...[
                          const SizedBox(height: 14),
                          const StatusLine(
                            icon: Icons.auto_awesome_outlined,
                            text: 'Registrando...',
                            loading: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ], // end challenge block
                // FeedbackBox + Duvida button + Proximo
                if (isCompleted && feedbackKey != null) ...[
                  const SizedBox(height: 10),
                  // "Duvida" button (spec: concluido state, before FeedbackBox)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: session.doubt.status != DoubtStatus.processing
                          ? session.toggleDoubt
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: simBorder),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x47111827),
                              blurRadius: 20,
                              spreadRadius: -16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Text(
                          session.doubt.status == DoubtStatus.processing
                              ? 'Dúvida...'
                              : 'Dúvida',
                          style: TextStyle(
                            color:
                                session.doubt.status == DoubtStatus.processing
                                ? simMuted
                                : simDark,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _FeedbackBox(
                    isCorrect: wasCorrect ?? false,
                    message: feedbackText(feedbackKey),
                    nextLabel: nextBtnText(nextKey),
                    nextReady:
                        !locked &&
                        session.doubt.status != DoubtStatus.processing,
                    onNext: () => unawaited(session.advanceAula()),
                  ),
                ],
                if (isEngineError) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: simWarn),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('aula_gen_fail'),
                          style: const TextStyle(
                            color: simWarn,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (phase?.message != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            phase!.message!,
                            style: const TextStyle(
                              color: simMuted,
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => unawaited(session.openAulaRuntime()),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: simDark,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              t('aula_try_again_2'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AulaTopBar(
              session: session,
              showReviewButton: true,
              progress: viewModel?.progress.toDouble(),
              headerLabel: viewModel != null
                  ? headerLabelText(viewModel.headerLabel)
                  : null,
            ),
          ),
          // FixedBubble â€” fixed bottom-center overlay while audio plays
          if (session.audioEnabled && session.audioPlaying)
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Center(
                  child: IgnorePointer(child: const _FixedBubble()),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionHistoryBlock extends StatelessWidget {
  const _QuestionHistoryBlock({required this.entry, required this.showImage});

  final QuestionHistoryEntry entry;
  final bool showImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showImage && entry.imageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 120, maxHeight: 80),
              color: Colors.white,
              padding: const EdgeInsets.all(4),
              child: Image.network(
                entry.imageUrl!,
                fit: BoxFit.contain,
                cacheWidth: 240,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          entry.text,
          style: const TextStyle(
            color: simDark,
            fontSize: 18,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        for (final opt in entry.options) ...[
          Builder(
            builder: (context) {
              final chosen = opt.id == entry.chosenOptionId;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: chosen ? simDark : simBorder,
                    width: chosen ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: chosen
                            ? simDark
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        opt.id.name.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: chosen ? Colors.white : simDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        opt.text,
                        style: const TextStyle(color: simDark, fontSize: 15),
                      ),
                    ),
                    if (chosen) ...[
                      const SizedBox(width: 8),
                      Text(
                        entry.correct ? 'ok' : 'x',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: simDark,
                          letterSpacing: 0.18 * 11,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

// AUL-5: FeedbackBox with fade+slide-up animation on appear
class _FeedbackBox extends StatefulWidget {
  const _FeedbackBox({
    required this.isCorrect,
    required this.message,
    this.nextLabel,
    this.nextReady = true,
    this.onNext,
  });

  final bool isCorrect;
  final String message;
  final String? nextLabel;
  final bool nextReady;
  final VoidCallback? onNext;

  @override
  State<_FeedbackBox> createState() => _FeedbackBoxState();
}

class _FeedbackBoxState extends State<_FeedbackBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isCorrect ? simSuccess : simWarn;
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: simCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color),
            boxShadow: [
              BoxShadow(color: color, blurRadius: 0, spreadRadius: 1),
              BoxShadow(
                color: color.withAlpha(100),
                blurRadius: 40,
                spreadRadius: -10,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                widget.isCorrect
                    ? Icons.check_circle_outline
                    : Icons.cancel_outlined,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.message,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (widget.onNext != null) ...[
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: widget.nextReady ? widget.onNext : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: widget.nextReady ? simGradientPrimary : null,
                      color: widget.nextReady ? null : simLight,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: widget.nextReady ? simShadowGlow : null,
                    ),
                    child: Text(
                      '${widget.nextLabel ?? ''} >>',
                      style: TextStyle(
                        color: widget.nextReady ? simDark : simMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// AUL-8: Row of 3 equal signal buttons, mono-18 number, label-11 uppercase
class _SinalRow extends StatelessWidget {
  const _SinalRow({required this.onSignal});
  final void Function(int) onSignal;

  @override
  Widget build(BuildContext context) {
    final labels = [
      (1, t('aula_sig_certeza')),
      (2, t('aula_sig_revisar')),
      (3, t('aula_sig_nao_sei')),
    ];
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.only(left: 16),
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: simDark, width: 1)),
      ),
      child: Row(
        children: [
          for (int i = 0; i < labels.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: GestureDetector(
                onTap: () => onSignal(labels[i].$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x14111827),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: simDark),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${labels[i].$1}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: kMono,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: simDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        labels[i].$2.toUpperCase(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: simDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Loading pulse bar â€” animates w-1/2 pulse, matches loading card bar in LessonMainScreen.tsx
class _PulseBar extends StatefulWidget {
  const _PulseBar();
  @override
  State<_PulseBar> createState() => _PulseBarState();
}

class _PulseBarState extends State<_PulseBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (_, _) => Opacity(
        opacity: _opacity.value,
        child: FractionallySizedBox(
          widthFactor: 0.5,
          alignment: Alignment.centerLeft,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: simDark,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class _FixedBubble extends StatefulWidget {
  const _FixedBubble();

  @override
  State<_FixedBubble> createState() => _FixedBubbleState();
}

class _FixedBubbleState extends State<_FixedBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _scale = Tween<double>(begin: 1.0, end: 1.08).animate(curved);
    _opacity = Tween<double>(begin: 1.0, end: 0.85).animate(curved);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reducedMotion = MediaQuery.of(context).disableAnimations;
    Widget bubble({double scale = 1, double opacity = 1, double spread = 0}) {
      return Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: simDark, width: 1),
              boxShadow: [
                BoxShadow(
                  color: simDark.withAlpha(
                    (0.18 * (1 - spread / 12) * 255).round(),
                  ),
                  blurRadius: 12,
                  spreadRadius: spread,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (reducedMotion) return bubble();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => bubble(
        scale: _scale.value,
        opacity: _opacity.value,
        spread: (_controller.value * 12).round().toDouble(),
      ),
    );
  }
}

// Â§DS DoubtInputSheet â€” bottom-sheet modal matching DoubtInputSheet.tsx
class _DoubtInputSheet extends StatefulWidget {
  const _DoubtInputSheet({
    required this.controller,
    required this.onSubmit,
    required this.onClose,
  });

  final TextEditingController controller;
  final void Function(String text) onSubmit;
  final VoidCallback onClose;

  @override
  State<_DoubtInputSheet> createState() => _DoubtInputSheetState();
}

class _DoubtInputSheetState extends State<_DoubtInputSheet> {
  String? _error;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final textLength = widget.controller.text.length;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: simBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enviar dúvida',
                  style: TextStyle(
                    color: simDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Escreva sua dúvida sobre a explicação ou exercício.',
                  style: TextStyle(color: simMuted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: simBorder),
                  ),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Stack(
                    children: [
                      TextField(
                        controller: widget.controller,
                        minLines: 5,
                        maxLines: 5,
                        maxLength: 1200,
                        decoration: const InputDecoration(
                          hintText: 'Escreva sua dúvida aqui...',
                          border: InputBorder.none,
                          counterText: '',
                          contentPadding: EdgeInsets.only(bottom: 28),
                        ),
                        style: const TextStyle(
                          color: simDark,
                          fontSize: 16,
                          height: 1.35,
                        ),
                        onChanged: (_) => setState(() => _error = null),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Text(
                          '$textLength/1200',
                          style: const TextStyle(
                            color: simMuted,
                            fontSize: 12,
                            fontFamily: kMono,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(color: simDestructive, fontSize: 13),
                  ),
                ],
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () {
                      final clean = widget.controller.text.trim();
                      if (clean.isEmpty) {
                        setState(
                          () => _error = 'Escreva sua dúvida antes de enviar.',
                        );
                        return;
                      }
                      widget.onSubmit(clean);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: simDark,
                      side: const BorderSide(color: simBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Enviar dúvida',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
