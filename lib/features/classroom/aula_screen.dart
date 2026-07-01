// ignore_for_file: unused_import, unnecessary_import
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../sim/classroom/classroom_text_scale.dart';
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
import '../../sim/auxiliary/doubt_input_sheet.dart';
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

class _AulaLabScreenState extends State<AulaLabScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _doubtController = TextEditingController();
  int _lastHistoryLen = 0;
  bool _lastHasContent = false;
  bool _doubtSheetOpen = false;
  String? _theoryDoneKey;
  AnswerLetter? _localAnswerSel;
  final bool _localExpanded = false;
  final GlobalKey _contentKey = GlobalKey();
  final GlobalKey _questionKey = GlobalKey();
  final GlobalKey _signalKey = GlobalKey();
  final GlobalKey _feedbackKey = GlobalKey();
  final GlobalKey _errorKey = GlobalKey();
  String? _lastScrollSignature;
  String? _lastMediaPositionSignature;
  int _fontScaleLevel = ClassroomTextScale.defaultLevel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.session.addListener(_onSessionChange);
    unawaited(_loadFontScaleLevel());
  }

  Future<void> _loadFontScaleLevel() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _fontScaleLevel = ClassroomTextScale.normalize(
        prefs.getInt(ClassroomTextScale.prefsKey) ??
            ClassroomTextScale.defaultLevel,
      );
    });
  }

  Future<void> _cycleFontScaleLevel() async {
    final next = ClassroomTextScale.next(_fontScaleLevel);
    setState(() => _fontScaleLevel = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(ClassroomTextScale.prefsKey, next);
    _scrollForSnapshot(widget.session.aulaSnapshot);
  }

  void _onSessionChange() {
    final snap = widget.session.aulaSnapshot;
    final history = snap?.history ?? const <QuestionHistoryEntry>[];
    final hasContent = snap?.conteudo != null;
    final phase = snap?.phase;
    final mediaPositionSignature = [
      snap?.itemMarker,
      snap?.viewModel?.headerLabel,
    ].join('|');
    if (_lastMediaPositionSignature == null) {
      _lastMediaPositionSignature = mediaPositionSignature;
    } else if (mediaPositionSignature != _lastMediaPositionSignature) {
      _lastMediaPositionSignature = mediaPositionSignature;
      widget.session.stopActiveAudio(notify: false);
    }
    final scrollSignature = [
      history.length,
      hasContent,
      phase?.type.name,
      phase?.letter?.name,
      phase?.message,
    ].join('|');
    if (history.length != _lastHistoryLen ||
        hasContent != _lastHasContent ||
        scrollSignature != _lastScrollSignature) {
      _lastHistoryLen = history.length;
      _lastHasContent = hasContent;
      _lastScrollSignature = scrollSignature;
      _scrollForSnapshot(snap);
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
        busy: widget.session.doubt.status == DoubtStatus.processing,
        onSubmit: (draft) {
          if (widget.session.doubtOpen) widget.session.toggleDoubt();
          Navigator.of(context).pop();
          unawaited(widget.session.submitDoubt(draft));
          _doubtController.clear();
        },
        onClose: () {
          if (widget.session.doubtOpen) widget.session.toggleDoubt();
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
    WidgetsBinding.instance.removeObserver(this);
    widget.session.removeListener(_onSessionChange);
    widget.session.stopActiveAudio(notify: false);
    _scrollController.dispose();
    _doubtController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      widget.session.stopActiveAudio();
    }
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

  void _scrollToTarget(
    GlobalKey targetKey, {
    double alignment = 0.1,
    bool fallbackToBottom = true,
  }) {
    void ensure() {
      if (!mounted) return;
      final ctx = targetKey.currentContext;
      if (ctx == null) {
        if (fallbackToBottom && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
          );
        }
        return;
      }
      Scrollable.ensureVisible(
        ctx,
        alignment: alignment,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ensure();
      Future<void>.delayed(const Duration(milliseconds: 90), ensure);
      Future<void>.delayed(const Duration(milliseconds: 220), ensure);
    });
  }

  void _scrollForSnapshot(LessonRuntimeSnapshot? snapshot) {
    final phase = snapshot?.phase;
    if (phase?.type == ClassroomPhaseType.concluido) {
      _scrollToTarget(_feedbackKey, alignment: 0.72);
      return;
    }
    if (phase?.type == ClassroomPhaseType.erroEngine) {
      _scrollToTarget(_errorKey, alignment: 0.72);
      return;
    }
    if (phase?.type == ClassroomPhaseType.expandida ||
        phase?.type == ClassroomPhaseType.processando) {
      _scrollToTarget(_signalKey, alignment: 0.72);
      return;
    }
    if (snapshot?.conteudo != null) {
      _scrollToTarget(_questionKey, alignment: 0.12);
    }
  }

  void _onLessonImageSettled() {
    _scrollForSnapshot(widget.session.aulaSnapshot);
  }

  bool _hasLessonImagePanel() {
    final imageData = widget.session.aulaSnapshot?.imagem;
    final hasImage = imageData != null && imageData.trim().isNotEmpty;
    return hasImage ||
        widget.session.imageError != null ||
        widget.session.hasLessonPaidImageOffer ||
        (widget.session.aulaRuntimeLoading && imageData == null);
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
    final textScale = ClassroomTextScale.scaleFor(_fontScaleLevel);
    Widget answerWithSignals(AnswerLetter letter, String label) {
      final isActive = effectiveSelected == letter;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnswerButton(
            label: label,
            text: content?.options[letter] ?? '',
            active: isActive,
            enabled: !locked,
            onTap: () => session.chooseAulaAnswer(label),
          ),
          if (effectiveExpanded && isActive) ...[
            const SizedBox(height: 4),
            KeyedSubtree(
              key: _signalKey,
              child: _SinalRow(onSignal: session.submitAulaSignal),
            ),
            const SizedBox(height: 10),
          ],
        ],
      );
    }

    if (isDone) {
      return LessonDoneScreen(session: session);
    }

    if (session.aulaRuntimeError?.contains('sem curriculo') == true ||
        session.aulaRuntimeError?.contains('sem currículo') == true) {
      return LessonNoCurriculumScreen(session: session);
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
      body: MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: Stack(
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
                          Semantics(
                            button: true,
                            excludeSemantics: true,
                            label: 'Tentar novamente preparar aula',
                            child: GestureDetector(
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
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Theory card â€” only when content is loaded
                  if (content != null) ...[
                    SimCard(
                      key: _contentKey,
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
                          if (session.doubt.status ==
                              DoubtStatus.processing) ...[
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
                          if (_hasLessonImagePanel()) ...[
                            const SizedBox(height: 14),
                            LessonImagePanel(
                              session: session,
                              onImageSettled: _onLessonImageSettled,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  if (content == null) ...[
                    SimCard(
                      key: _questionKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_hasLessonImagePanel()) ...[
                            LessonImagePanel(
                              session: session,
                              onImageSettled: _onLessonImageSettled,
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
                          answerWithSignals(AnswerLetter.A, 'A'),
                          answerWithSignals(AnswerLetter.B, 'B'),
                          answerWithSignals(AnswerLetter.C, 'C'),

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
                      child: Semantics(
                        button: true,
                        enabled: session.doubt.status != DoubtStatus.processing,
                        excludeSemantics: true,
                        label: 'Abrir dúvida da aula',
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
                                    session.doubt.status ==
                                        DoubtStatus.processing
                                    ? simMuted
                                    : simDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    KeyedSubtree(
                      key: _feedbackKey,
                      child: _FeedbackBox(
                        isCorrect: wasCorrect ?? false,
                        message: feedbackText(feedbackKey),
                        nextLabel: nextBtnText(nextKey),
                        nextReady:
                            session.doubt.status != DoubtStatus.processing,
                        onNext: () => unawaited(session.advanceAula()),
                      ),
                    ),
                  ],
                  if (isEngineError) ...[
                    const SizedBox(height: 12),
                    Container(
                      key: _errorKey,
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
                          Semantics(
                            button: true,
                            excludeSemantics: true,
                            label: 'Tentar novamente preparar aula',
                            child: GestureDetector(
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
                textScale: textScale,
              ),
            ),
            Positioned(
              right: 16,
              bottom: 24,
              child: SafeArea(
                top: false,
                child: _FontScaleButton(
                  level: _fontScaleLevel,
                  onTap: () => unawaited(_cycleFontScaleLevel()),
                ),
              ),
            ),
            // FixedBubble â€” fixed bottom-center overlay while audio plays
            if (session.audioEnabled && session.audioPlaying)
              Positioned(
                bottom: 82,
                left: 0,
                right: 0,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: const IgnorePointer(child: _FixedBubble()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class LessonNoCurriculumScreen extends StatelessWidget {
  const LessonNoCurriculumScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(32),
              decoration: glassDecoration(radius: 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t('aula_no_curr_h1'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: simDark,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t('aula_no_curr_body'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: simMuted,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 22),
                  PrimaryWideButton(
                    label: t('aula_back_curr'),
                    onTap: () => session.openSupport('/cyber/objeto'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FontScaleButton extends StatelessWidget {
  const _FontScaleButton({required this.level, required this.onTap});

  final int level;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Tamanho da letra: nível $level de 5',
      child: GestureDetector(
        key: const Key('aula-font-scale-button'),
        onTap: onTap,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: simBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.text_fields, color: simDark, size: 18),
              const SizedBox(height: 1),
              Text(
                '$level/5',
                key: const Key('aula-font-scale-level'),
                style: const TextStyle(
                  color: simDark,
                  fontFamily: kMono,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
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
              child: LessonMediaImageView(data: entry.imageUrl!, compact: true),
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
                Semantics(
                  button: true,
                  enabled: widget.nextReady,
                  excludeSemantics: true,
                  label: 'Avançar aula',
                  child: GestureDetector(
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
              child: Semantics(
                button: true,
                excludeSemantics: true,
                label: 'Sinal ${labels[i].$1}: ${labels[i].$2}',
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            labels[i].$2.toUpperCase(),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: simDark,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
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

    final child = reducedMotion
        ? bubble()
        : AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => bubble(
              scale: _scale.value,
              opacity: _opacity.value,
              spread: (_controller.value * 12).round().toDouble(),
            ),
          );
    return Semantics(
      label: 'Áudio da aula tocando',
      liveRegion: true,
      child: child,
    );
  }
}

// Â§DS DoubtInputSheet â€” bottom-sheet modal matching DoubtInputSheet.tsx
class _DoubtInputSheet extends StatefulWidget {
  const _DoubtInputSheet({
    required this.controller,
    required this.busy,
    required this.onSubmit,
    required this.onClose,
  });

  final TextEditingController controller;
  final bool busy;
  final void Function(DoubtInputDraft input) onSubmit;
  final VoidCallback onClose;

  @override
  State<_DoubtInputSheet> createState() => _DoubtInputSheetState();
}

class _DoubtInputSheetState extends State<_DoubtInputSheet> {
  final ImagePicker _picker = ImagePicker();
  DoubtImagePayload? _image;
  bool _menuOpen = false;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _error = null;
      _menuOpen = false;
    });
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final mime = picked.mimeType ?? 'image/jpeg';
      final payload = DoubtImagePayload(
        name: picked.name.isEmpty ? 'foto-da-duvida.jpg' : picked.name,
        type: mime,
        size: bytes.length,
        dataUrl: 'data:$mime;base64,${base64Encode(bytes)}',
      );
      final validation = DoubtInputDraft(image: payload).validate();
      if (validation != null && validation != emptyDoubtMessage) {
        setState(() => _error = validation);
        return;
      }
      setState(() => _image = payload);
    } catch (_) {
      setState(() => _error = imageOnlyMessage);
    }
  }

  void _submit() {
    final draft = DoubtInputDraft(text: widget.controller.text, image: _image);
    final validation = draft.validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    widget.onSubmit(draft);
    setState(() {
      _image = null;
      _error = null;
      _menuOpen = false;
    });
  }

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
                  'Escreva sua dúvida ou envie uma foto do exercício, resolução, fórmula, gráfico ou tabela.',
                  style: TextStyle(color: simMuted, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 14),
                if (_image != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: simBorder),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Foto: ${_image!.name}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: simDark,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _image = null),
                          child: const Text(
                            'Remover',
                            style: TextStyle(
                              color: simDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
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
                        left: 0,
                        bottom: 0,
                        child: GestureDetector(
                          onTap: widget.busy
                              ? null
                              : () => setState(() => _menuOpen = !_menuOpen),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.attach_file,
                              color: simDark,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      if (_menuOpen)
                        Positioned(
                          left: 0,
                          bottom: 38,
                          child: Container(
                            width: 210,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: simBorder),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x26000000),
                                  blurRadius: 12,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _DoubtImageMenuLine(
                                  label: 'Tirar foto',
                                  onTap: () =>
                                      unawaited(_pickImage(ImageSource.camera)),
                                ),
                                _DoubtImageMenuLine(
                                  label: 'Escolher imagem',
                                  onTap: () => unawaited(
                                    _pickImage(ImageSource.gallery),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                    onPressed: widget.busy ? null : _submit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: simDark,
                      side: const BorderSide(color: simBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      widget.busy ? 'Enviando...' : 'Enviar dúvida',
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

class _DoubtImageMenuLine extends StatelessWidget {
  const _DoubtImageMenuLine({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Text(
          label,
          style: const TextStyle(
            color: simDark,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
