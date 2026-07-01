// ignore_for_file: unused_import, unnecessary_import
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../sim/billing/sim_pricing.dart';
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

class AulaTopBar extends StatelessWidget {
  const AulaTopBar({
    required this.session,
    this.showReviewButton = false,
    this.progress,
    this.headerLabel,
    this.textScale = 1,
    super.key,
  });

  final LabSession session;
  final bool showReviewButton;
  final double? progress;
  final String? headerLabel;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final fill = ((progress ?? 0) / 100).clamp(0.0, 1.0);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            border: const Border(
              bottom: BorderSide(color: simBorder, width: 1),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Row(
                children: [
                  _HamburgerBtn(
                    onTap: () =>
                        showAulaMenu(context, session, textScale: textScale),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              height: 3,
                              color: const Color(0x0F111827),
                              alignment: Alignment.centerLeft,
                              child: TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: fill),
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeOut,
                                builder: (context, value, child) {
                                  return FractionallySizedBox(
                                    widthFactor: value,
                                    alignment: Alignment.centerLeft,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: simGradientPrimary,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Color(0x2E111827),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 220),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: simBorder),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1F000000),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              (headerLabel ?? (session.stableLang ?? 'SIM'))
                                  .toUpperCase(),
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: kMono,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: simDark,
                                letterSpacing: 0.14 * 10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HeaderIconCard(
                    icon: session.audioEnabled
                        ? Icons.volume_up
                        : Icons.volume_off_outlined,
                    color: session.audioEnabled ? simDark : simMuted,
                    semanticLabel: session.audioEnabled
                        ? 'Desligar áudio da aula'
                        : 'Ligar áudio da aula',
                    onTap: session.toggleAudio,
                  ),
                  if (showReviewButton) ...[
                    const SizedBox(width: 6),
                    Semantics(
                      button: true,
                      excludeSemantics: true,
                      label: 'Abrir revisão',
                      child: GestureDetector(
                        onTap: session.openReviewRoom,
                        child: Container(
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            gradient: simGradientPrimary,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: simDark),
                            boxShadow: simShadowGlow,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.menu_book_outlined,
                                color: simDark,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                t('aux_review_button').toUpperCase(),
                                style: TextStyle(
                                  fontFamily: kMono,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: simDark,
                                  letterSpacing: 0.16 * 11,
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
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIconCard extends StatelessWidget {
  const _HeaderIconCard({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: simBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: color, size: 16),
        ),
      ),
    );
  }
}

class _HamburgerBtn extends StatelessWidget {
  const _HamburgerBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      excludeSemantics: true,
      label: 'Abrir menu da aula',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: simBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 4),
                Container(
                  width: 18,
                  height: 3,
                  decoration: BoxDecoration(
                    color: simDark,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF111827).withValues(alpha: 0.15),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
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

class LessonImagePanel extends StatelessWidget {
  const LessonImagePanel({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final imageData = session.aulaSnapshot?.imagem;
    final loading = session.aulaRuntimeLoading && imageData == null;
    final ready = imageData != null && imageData.trim().isNotEmpty;
    final error = session.imageError;
    final offer = session.hasLessonPaidImageOffer && !loading && !ready;
    final imageCost = simPricing.imageCostCredits;
    final hasImageCredits = session.isUnlimited || session.credits >= imageCost;
    if (!loading && !ready && !offer && error == null) {
      return const SizedBox.shrink();
    }
    return Container(
      height: offer
          ? 228
          : ready
          ? 168
          : 96,
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: simLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: simBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: simDark,
                      ),
                    )
                  : ready
                  ? _LessonImageView(data: imageData)
                  : Icon(Icons.broken_image_outlined, size: 34, color: simDark),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            loading
                ? 'Gerando imagem da aula...'
                : ready
                ? 'Imagem da aula pronta'
                : offer
                ? t('aula_img_desc')
                : error ?? 'Imagem da aula indisponível',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: simDark,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (offer) ...[
            const SizedBox(height: 8),
            Text(
              '${t('aula_img_cost', {'n': imageCost})}'
              '${session.isUnlimited ? '' : t('aula_img_balance', {'n': session.credits})}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: simMuted,
                fontSize: 12,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (!hasImageCredits) ...[
                  Expanded(
                    child: FilledButton(
                      onPressed: session.lessonImageOfferLoading
                          ? null
                          : session.buyImageCredits,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: simDark,
                        side: const BorderSide(color: simBorder),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      child: Text(t('aula_buy_credits')),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: session.lessonImageOfferLoading
                        ? null
                        : session.declineLessonPaidImage,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: simDark,
                      side: const BorderSide(color: simBorder),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    child: Text(
                      hasImageCredits
                          ? t('aula_skip')
                          : t('aula_continue_no_img'),
                    ),
                  ),
                ),
                if (hasImageCredits) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: session.lessonImageOfferLoading
                          ? null
                          : session.acceptLessonPaidImage,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: simDark,
                        side: const BorderSide(color: simBorder),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      child: session.lessonImageOfferLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: simDark,
                              ),
                            )
                          : Text(t('aula_view_img', {'n': imageCost})),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _LessonImageView extends StatelessWidget {
  const _LessonImageView({required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final trimmed = data.trim();
    if (trimmed.startsWith('data:image/svg+xml')) {
      final svg = _decodeSvgDataUrl(trimmed);
      if (svg != null) {
        return SvgPicture.string(svg, fit: BoxFit.contain);
      }
    }
    if (trimmed.startsWith('data:image/')) {
      final comma = trimmed.indexOf(',');
      if (comma > 0 && trimmed.substring(0, comma).contains(';base64')) {
        try {
          return Image.memory(
            base64Decode(trimmed.substring(comma + 1)),
            fit: BoxFit.contain,
            gaplessPlayback: true,
          );
        } catch (_) {}
      }
    }
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return Image.network(
        trimmed,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.broken_image_outlined, size: 46, color: simDark),
      );
    }
    return const Icon(Icons.broken_image_outlined, size: 46, color: simDark);
  }

  String? _decodeSvgDataUrl(String raw) {
    final comma = raw.indexOf(',');
    if (comma <= 0) return null;
    final header = raw.substring(0, comma);
    final payload = raw.substring(comma + 1);
    try {
      if (header.contains(';base64')) {
        return utf8.decode(base64Decode(payload));
      }
      return Uri.decodeComponent(payload);
    } catch (_) {
      return null;
    }
  }
}

class StatusLine extends StatelessWidget {
  const StatusLine({
    required this.icon,
    required this.text,
    this.loading = false,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final String text;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      children: [
        if (loading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: simDark),
          )
        else
          Icon(icon, size: 16, color: simMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: simMuted, fontSize: 13, height: 1.35),
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return GestureDetector(onTap: onTap, child: row);
  }
}
