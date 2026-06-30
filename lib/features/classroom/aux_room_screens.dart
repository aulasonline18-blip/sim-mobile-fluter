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

class LessonDoneScreen extends StatelessWidget {
  const LessonDoneScreen({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: SingleChildScrollView(
            child: SimPreparationExperience(
              stage: 'done',
              ready: true,
              onContinue: () => session.openSupport('/cyber/objeto'),
            ),
          ),
        ),
      ),
    );
  }
}

class AuxRoomCard extends StatelessWidget {
  const AuxRoomCard({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SimCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: simDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(color: simMuted, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// Â§AUX _AuxQuestionScreen
// Full-screen aux question: header (back btn + 3px progress bar + mono label),
// glass theory card, question h2, A/B/C option buttons with signal row on selection,
// FeedbackBox with â–¶ next button in result state.
class _AuxQuestionScreen extends StatelessWidget {
  const _AuxQuestionScreen({
    required this.mode,
    required this.conteudo,
    required this.selected,
    required this.status,
    required this.headerLabel,
    required this.onSelect,
    required this.onSignal,
    required this.onNext,
    this.progressWidth,
    this.resultCorrect,
    this.resultMsg,
    this.onBack,
    this.onAudio,
  });

  final String mode;
  final AuxRoomContent conteudo;
  final AnswerLetter? selected;
  final String status; // 'answering' | 'result'
  final String headerLabel;
  final double? progressWidth;
  final bool? resultCorrect;
  final String? resultMsg;
  final VoidCallback? onBack;
  final VoidCallback? onAudio;
  final void Function(AnswerLetter) onSelect;
  final void Function(DecisionSignal) onSignal;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final isResult = status == 'result';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  if (onBack != null)
                    GestureDetector(
                      onTap: onBack,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: simBorder),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: simDark,
                          size: 20,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 40),
                  const SizedBox(width: 8),
                  if (progressWidth != null)
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          height: 3,
                          color: const Color(0x0F111827),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: (progressWidth! / 100).clamp(
                                0.0,
                                1.0,
                              ),
                              child: Container(
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFFFFFFF),
                                      Color(0xFFF3F4F6),
                                    ],
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    const Expanded(child: SizedBox()),
                  const SizedBox(width: 12),
                  Text(
                    headerLabel.toUpperCase(),
                    style: TextStyle(
                      fontFamily: kMono,
                      fontSize: 11,
                      color: simMuted,
                      letterSpacing: 0.18 * 11,
                    ),
                  ),
                  if (onAudio != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: onAudio,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: simBorder),
                        ),
                        child: const Icon(
                          Icons.volume_up,
                          color: simDark,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Scrollable body
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Glass theory card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: simBorder),
                      ),
                      child: Text(
                        conteudo.explanation,
                        style: const TextStyle(
                          color: simDark,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (conteudo.question.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Text(
                        conteudo.question,
                        style: const TextStyle(
                          color: simDark,
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    // A/B/C options
                    for (final opt in [
                      AnswerLetter.A,
                      AnswerLetter.B,
                      AnswerLetter.C,
                    ]) ...[
                      _AuxOptionTile(
                        letter: opt,
                        text: conteudo.options[opt] ?? '',
                        selected: selected == opt,
                        locked: isResult,
                        onSelect: () => onSelect(opt),
                        onSignal: onSignal,
                        showSignals: selected == opt && !isResult,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (isResult) ...[
                      const SizedBox(height: 4),
                      _AuxFeedbackBox(
                        correct: resultCorrect ?? false,
                        message: resultMsg ?? '',
                        onNext: onNext,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinalBtn extends StatelessWidget {
  const _SinalBtn({required this.n, required this.label, required this.onTap});
  final int n;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
            color: const Color(0x1421B2E9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: simDark),
          ),
          child: Text(
            '$n. $label',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: kMono,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: simDark,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuxOptionTile extends StatelessWidget {
  const _AuxOptionTile({
    required this.letter,
    required this.text,
    required this.selected,
    required this.locked,
    required this.onSelect,
    required this.onSignal,
    required this.showSignals,
  });

  final AnswerLetter letter;
  final String text;
  final bool selected;
  final bool locked;
  final VoidCallback onSelect;
  final void Function(DecisionSignal) onSignal;
  final bool showSignals;

  @override
  Widget build(BuildContext context) {
    final letterStr = letter.name; // 'A', 'B', 'C'
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: locked ? null : onSelect,
          child: Opacity(
            opacity: locked && !selected ? 0.6 : 1.0,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? simDark : simBorder,
                  width: selected ? 1.5 : 1.0,
                ),
                boxShadow: selected
                    ? [
                        const BoxShadow(
                          color: Color(0x14111827),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected ? simDark : const Color(0x0D111827),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      letterStr,
                      style: TextStyle(
                        fontFamily: kMono,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: selected ? Colors.white : simDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(color: simDark, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showSignals) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              padding: const EdgeInsets.only(left: 12),
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: simDark, width: 2)),
              ),
              child: Row(
                children: [
                  _SinalBtn(
                    n: 1,
                    label: t('aula_sig_certeza'),
                    onTap: () => onSignal(DecisionSignal.one),
                  ),
                  const SizedBox(width: 8),
                  _SinalBtn(
                    n: 2,
                    label: t('aula_sig_revisar'),
                    onTap: () => onSignal(DecisionSignal.two),
                  ),
                  const SizedBox(width: 8),
                  _SinalBtn(
                    n: 3,
                    label: t('aula_sig_nao_sei'),
                    onTap: () => onSignal(DecisionSignal.three),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AuxFeedbackBox extends StatelessWidget {
  const _AuxFeedbackBox({
    required this.correct,
    required this.message,
    required this.onNext,
  });

  final bool correct;
  final String message;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final color = correct ? const Color(0xFF374151) : simDark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: correct ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: correct ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 14, height: 1.4),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onNext,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: simDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'â–¶',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Â§REVROOM ReviewRoomScreen
class ReviewRoomScreen extends StatelessWidget {
  const ReviewRoomScreen({required this.session, super.key});
  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final review = session.reviewRoom!;
    final status = review.status;

    if (status == ReviewRoomStatus.choose) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: simBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t('aux_review_ask_count'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: simDark,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final count in [5, 10]) ...[
                          GestureDetector(
                            onTap: () => session.setReviewRoom(
                              review.copyWith(
                                status: ReviewRoomStatus.preparing,
                                count: count,
                              ),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 28,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: simDark,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '$count',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          if (count == 5) const SizedBox(width: 12),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: session.closeReviewRoom,
                      child: Text(
                        t('aux_review_fail_back'),
                        style: const TextStyle(color: simMuted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (status == ReviewRoomStatus.preparing ||
        status == ReviewRoomStatus.ready) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SimPreparationExperience(
              stage: 'review',
              ready: status == ReviewRoomStatus.ready,
              onContinue: () => session.setReviewRoom(
                review.copyWith(status: ReviewRoomStatus.answering),
              ),
            ),
          ),
        ),
      );
    }

    if (status == ReviewRoomStatus.failed) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: simBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t('aula_gen_fail'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (review.errMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        review.errMsg!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: simMuted, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: session.closeReviewRoom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: simDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t('aux_review_fail_back'),
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
            ),
          ),
        ),
      );
    }

    if (status == ReviewRoomStatus.done) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SimPreparationExperience(
              stage: 'reviewDone',
              ready: true,
              onContinue: session.closeReviewRoom,
            ),
          ),
        ),
      );
    }

    if (review.conteudo == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SimPreparationExperience(
              stage: 'review',
              ready: false,
              onContinue: () {},
            ),
          ),
        ),
      );
    }

    final progressWidth = review.count > 0
        ? (review.idx / review.count) * 100.0
        : 0.0;
    return _AuxQuestionScreen(
      mode: 'review',
      conteudo: review.conteudo!,
      selected: review.letra,
      status: status.name,
      headerLabel:
          '${t('aux_review_button')} ${review.idx + 1}/${review.count}',
      progressWidth: progressWidth,
      resultCorrect: review.resultCorrect,
      resultMsg: review.resultMsg,
      onBack: session.closeReviewRoom,
      onAudio: () => unawaited(
        session.speakAuxRoomContent(
          review.conteudo!,
          source: 'review:${review.idx}',
        ),
      ),
      onSelect: (letter) =>
          session.setReviewRoom(review.copyWith(letra: letter)),
      onSignal: (signal) {
        final correct = review.letra == review.conteudo!.correctAnswer;
        session.setReviewRoom(
          review.copyWith(
            sinal: signal,
            status: ReviewRoomStatus.result,
            resultCorrect: correct,
            resultMsg: correct ? t('aula_fb_correct') : t('aula_fb_redo'),
          ),
        );
      },
      onNext: () {
        final nextIdx = review.idx + 1;
        if (nextIdx >= review.count) {
          session.setReviewRoom(review.copyWith(status: ReviewRoomStatus.done));
        } else {
          session.setReviewRoom(
            ReviewRoomView(
              status: ReviewRoomStatus.preparing,
              count: review.count,
              queue: review.queue,
              idx: nextIdx,
            ),
          );
        }
      },
    );
  }
}

// Â§RECROOM RecoveryRoomScreen
class RecoveryRoomScreen extends StatelessWidget {
  const RecoveryRoomScreen({required this.session, super.key});
  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final recovery = session.recoveryRoom!;
    final status = recovery.status;

    if (status == RecoveryRoomStatus.failed) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(32),
                constraints: const BoxConstraints(maxWidth: 420),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: simBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t('aula_gen_fail'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (recovery.errMsg != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        recovery.errMsg!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: simMuted, fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: session.closeRecoveryRoom,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: simDark,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          t('aux_recovery_finish_cta'),
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
            ),
          ),
        ),
      );
    }

    if (status == RecoveryRoomStatus.intro ||
        status == RecoveryRoomStatus.preparing) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SimPreparationExperience(
              stage: 'recovery',
              ready: recovery.conteudo != null,
              onContinue: () => session.setRecoveryRoom(
                recovery.copyWith(status: RecoveryRoomStatus.answering),
              ),
            ),
          ),
        ),
      );
    }

    if (status == RecoveryRoomStatus.done) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SimPreparationExperience(
              stage: 'recoveryDone',
              ready: true,
              onContinue: session.closeRecoveryRoom,
            ),
          ),
        ),
      );
    }

    if (recovery.conteudo == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: SimPreparationExperience(
              stage: 'recovery',
              ready: false,
              onContinue: () {},
            ),
          ),
        ),
      );
    }

    return _AuxQuestionScreen(
      mode: 'recovery',
      conteudo: recovery.conteudo!,
      selected: recovery.letra,
      status: status == RecoveryRoomStatus.result ? 'result' : 'answering',
      headerLabel: t('aux_recovery_preparing_title'),
      resultCorrect: recovery.resultCorrect,
      resultMsg: recovery.resultMsg,
      onAudio: () => unawaited(
        session.speakAuxRoomContent(
          recovery.conteudo!,
          source: 'recovery:${recovery.idx}',
        ),
      ),
      onSelect: (letter) =>
          session.setRecoveryRoom(recovery.copyWith(letra: letter)),
      onSignal: (signal) {
        final correct = recovery.letra == recovery.conteudo!.correctAnswer;
        session.setRecoveryRoom(
          recovery.copyWith(
            sinal: signal,
            status: RecoveryRoomStatus.result,
            resultCorrect: correct,
            resultMsg: correct ? t('aula_fb_correct') : t('aula_fb_redo'),
          ),
        );
      },
      onNext: () {
        final nextIdx = recovery.idx + 1;
        if (nextIdx >= recovery.queue.length) {
          session.setRecoveryRoom(
            recovery.copyWith(status: RecoveryRoomStatus.done),
          );
        } else {
          session.setRecoveryRoom(
            RecoveryRoomView(
              status: RecoveryRoomStatus.preparing,
              queue: recovery.queue,
              idx: nextIdx,
            ),
          );
        }
      },
    );
  }
}

// AUL-1: Fixed header â€” menu btn + 3px progress bar + header label chip +
// audio toggle + RevisÃ£o button (mono, uppercase, BookOpenCheck icon).
// Matches LessonMainScreen.tsx header exactly.
