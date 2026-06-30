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
import '../../features/session/lab_session.dart';
import '../../features/portal/portal_flow.dart';
import '../../features/auth/login_screen.dart';
import '../../features/onboarding/onboarding_screens.dart';
import '../../features/onboarding/preparation_and_placement.dart';
import '../../features/classroom/aula_screen.dart';
import '../../features/classroom/aux_room_screens.dart';
import '../../features/classroom/aula_widgets.dart';
import '../../features/billing/billing_and_simple_pages.dart';
class PrimaryWideButton extends StatelessWidget {
  const PrimaryWideButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: primaryButtonDecoration(radius: 14),
        child: TextButton(
          onPressed: onTap,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: simDark,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryWideButton extends StatelessWidget {
  const SecondaryWideButton({
    required this.label,
    required this.onTap,
    super.key,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: simDark,
          side: const BorderSide(color: simBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class AnswerButton extends StatelessWidget {
  const AnswerButton({
    required this.label,
    required this.text,
    required this.active,
    required this.onTap,
    this.enabled = true,
    super.key,
  });

  final String label;
  final String text;
  final bool active;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _PressScale(
        enabled: enabled,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.6,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: simCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: active ? simDark : simBorder,
                  width: active ? 1.5 : 1,
                ),
                boxShadow: simShadowGlow,
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: active ? simGradientPrimary : null,
                      color: active ? null : const Color(0x0DFFFFFF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: active ? simDark : const Color(0x0F111827),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: const TextStyle(
                        fontFamily: kMono,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: simDark,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(
                        color: simDark,
                        fontSize: 16,
                        height: 1.35,
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
}

class _PressScale extends StatefulWidget {
  const _PressScale({required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.enabled
          ? (_) => setState(() => _pressed = true)
          : null,
      onPointerUp: widget.enabled
          ? (_) => setState(() => _pressed = false)
          : null,
      onPointerCancel: widget.enabled
          ? (_) => setState(() => _pressed = false)
          : null,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.99 : 1,
        child: widget.child,
      ),
    );
  }
}

void showAulaMenu(BuildContext context, LabSession session) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'menu',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      final sw = MediaQuery.of(ctx).size.width;
      final drawerW = (sw * 0.88).clamp(0.0, 360.0);
      return Align(
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: anim1,
          builder: (_, child) => Transform.translate(
            offset: Offset(-drawerW * (1 - anim1.value), 0),
            child: child,
          ),
          child: Material(
            color: const Color(0xFFF0F0F0),
            child: SizedBox(
              width: drawerW,
              height: double.infinity,
              child: SafeArea(
                child: _AulaDrawerContent(
                  session: session,
                  onClose: () => Navigator.of(ctx).pop(),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) => child,
  );
}

class _AulaDrawerContent extends StatefulWidget {
  const _AulaDrawerContent({required this.session, required this.onClose});
  final LabSession session;
  final VoidCallback onClose;
  @override
  State<_AulaDrawerContent> createState() => _AulaDrawerContentState();
}

class _AulaDrawerContentState extends State<_AulaDrawerContent> {
  final TextEditingController _searchCtrl = TextEditingController();
  String? _feedback;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _flash(String msg) {
    setState(() => _feedback = msg);
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) setState(() => _feedback = null);
    });
  }

  void _handleNovaAula() {
    widget.onClose();
    widget.session.goPortal();
  }

  Future<void> _handleLogout() async {
    widget.onClose();
    await widget.session.signOutReal();
  }

  @override
  Widget build(BuildContext context) {
    const panelBg = Color(0xFFF0F0F0);
    const footerBg = Color(0xFFE7E7E7);
    const border = Color(0xFFD4D4D4);
    const text = Color(0xFF1A1A1A);
    const muted = Color(0xFF5A5A5A);

    final session = widget.session;
    final lessonId = session.lessonLocalId;
    final state = lessonId != null
        ? session.canonicalStore?.readState(lessonId)
        : null;
    final total = state?.curriculum?.totalItems ?? 0;
    final advances = state?.progress?.itemIdx ?? 0;
    final pct = total > 0 ? ((advances / total) * 100).round() : 0;
    final lessonName = state?.curriculum?.topic ?? lessonId ?? '';

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: panelBg,
            border: const Border(bottom: BorderSide(color: border, width: 1)),
          ),
          child: Row(
            children: [
              Text(
                t('menu').toUpperCase(),
                style: TextStyle(
                  fontFamily: kMono,
                  fontSize: 11,
                  letterSpacing: 0.22 * 11,
                  color: muted,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onClose,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'âœ•',
                    style: TextStyle(
                      color: text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Top: Nova Aula + Recarregar
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: border, width: 1)),
          ),
          child: Column(
            children: [
              // Nova Aula button (gradient-like: dark bg)
              GestureDetector(
                onTap: _handleNovaAula,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: simDark,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2E111827),
                        blurRadius: 12,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'ï¼‹',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        t('nova_aula'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Recarregar crÃ©ditos
              GestureDetector(
                onTap: () {
                  widget.onClose();
                  session.openCredits();
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      const Text('âš¡', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          t('recarregar_creditos'),
                          style: const TextStyle(
                            color: text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        'TOP UP',
                        style: TextStyle(
                          fontFamily: kMono,
                          fontSize: 10,
                          color: muted,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Middle: History / lesson list
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('historico').toUpperCase(),
                  style: TextStyle(
                    fontFamily: kMono,
                    fontSize: 10,
                    letterSpacing: 0.22 * 10,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 8),
                if (lessonName.isEmpty)
                  Text(
                    t('historico_vazio'),
                    style: const TextStyle(color: muted, fontSize: 12),
                  )
                else ...[
                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(color: text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: t('drawer_search_placeholder'),
                        hintStyle: const TextStyle(color: muted, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Current lesson item
                  if (_matchSearch(lessonName))
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lessonName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '$pct% Â· $advances/$total',
                                  style: TextStyle(
                                    fontFamily: kMono,
                                    fontSize: 10,
                                    color: muted,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),

        // Footer
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: footerBg,
            border: Border(top: BorderSide(color: border, width: 1)),
          ),
          child: Column(
            children: [
              // Status line
              if (total > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        t('drawer_progress'),
                        style: TextStyle(
                          fontFamily: kMono,
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$advances/$total',
                        style: TextStyle(
                          fontFamily: kMono,
                          fontSize: 11,
                          color: text,
                        ),
                      ),
                    ],
                  ),
                ),
              // Export / Import / Status
              Row(
                children: [
                  _DrawerFooterBtn(
                    label: 'â¤“ ${t("exportar")}',
                    onTap: () => _flash('Em breve'),
                  ),
                  const SizedBox(width: 6),
                  _DrawerFooterBtn(
                    label: 'â¤’ ${t("importar")}',
                    onTap: () => _flash('Em breve'),
                  ),
                  const SizedBox(width: 6),
                  _DrawerFooterBtn(
                    label: 'â“˜ ${t("status")}',
                    onTap: () => _flash('Em breve'),
                  ),
                ],
              ),
              if (_feedback != null) ...[
                const SizedBox(height: 6),
                Text(
                  _feedback!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: simDark, fontSize: 11),
                ),
              ],
              const SizedBox(height: 8),
              // Logout button
              GestureDetector(
                onTap: _handleLogout,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, size: 16, color: text),
                      const SizedBox(width: 8),
                      Text(
                        t('logout'),
                        style: const TextStyle(
                          color: text,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () {
                  widget.onClose();
                  session.openSupport('/conta/deletar');
                },
                child: Text(
                  'Solicitar exclusÃ£o da conta',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                    decorationColor: muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _matchSearch(String name) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q);
  }
}

class _DrawerFooterBtn extends StatelessWidget {
  const _DrawerFooterBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD4D4D4)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// DR-1..DR-6: Left-side panel drawer (88vw max 360, bg #F0F0F0)
void showSimDrawer(
  BuildContext context, {
  required LabSession session,
  required Widget Function(BuildContext ctx) body,
}) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'menu',
    barrierColor: Colors.black.withValues(alpha: 0.35),
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (ctx, anim1, anim2) {
      final sw = MediaQuery.of(ctx).size.width;
      final drawerW = (sw * 0.88).clamp(0.0, 360.0);
      return Align(
        alignment: Alignment.centerLeft,
        child: AnimatedBuilder(
          animation: anim1,
          builder: (_, child) => Transform.translate(
            offset: Offset(-drawerW * (1 - anim1.value), 0),
            child: child,
          ),
          child: Material(
            color: const Color(0xFFF0F0F0),
            child: SizedBox(
              width: drawerW,
              height: double.infinity,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: MENU label + close
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 16, 4),
                      child: Row(
                        children: [
                          Text(
                            t('menu'),
                            style: const TextStyle(
                              color: simDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Text(
                                'âœ•',
                                style: TextStyle(
                                  color: simDark,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFFD1D5DB), height: 1),
                    const SizedBox(height: 8),
                    // Body content
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: body(ctx),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim1, anim2, child) => child,
  );
}

class SupportedLang {
  const SupportedLang({
    required this.code,
    required this.name,
    required this.native,
    required this.flag,
  });
  final String code;
  final String name;
  final String native;
  final String flag;
}

const supportedLangs = <SupportedLang>[
  SupportedLang(code: 'en', name: 'English', native: 'English', flag: 'ðŸ‡ºðŸ‡¸'),
  SupportedLang(
    code: 'pt',
    name: 'Portuguese',
    native: 'PortuguÃªs',
    flag: 'ðŸ‡§ðŸ‡·',
  ),
  SupportedLang(code: 'es', name: 'Spanish', native: 'EspaÃ±ol', flag: 'ðŸ‡ªðŸ‡¸'),
  SupportedLang(code: 'fr', name: 'French', native: 'FranÃ§ais', flag: 'ðŸ‡«ðŸ‡·'),
  SupportedLang(code: 'ja', name: 'Japanese', native: 'æ—¥æœ¬èªž', flag: 'ðŸ‡¯ðŸ‡µ'),
];

class LanguageButton extends StatelessWidget {
  const LanguageButton({
    required this.language,
    required this.active,
    required this.onTap,
    super.key,
  });

  final SupportedLang language;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = language.native.isEmpty
        ? language.name
        : '${language.name} Â· ${language.native}';
    return SizedBox(
      width: double.infinity,
      height: 64,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: active ? simGradientPrimary : null,
          color: active ? null : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? simDark : simBorder),
          boxShadow: active
              ? const [
                  BoxShadow(
                    color: Color(0x22111827),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: simDark,
            alignment: Alignment.centerLeft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            children: [
              Text(language.flag, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
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

class StepHeader extends StatelessWidget {
  const StepHeader({
    required this.step,
    required this.total,
    required this.label,
    super.key,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pct = step / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: simBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: pct,
                  child: Container(color: simLight),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              color: simMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class SimInput extends StatelessWidget {
  const SimInput({
    required this.hint,
    required this.onChanged,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    super.key,
  });

  final String hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: simBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: simDark),
        ),
      ),
    );
  }
}

class SimCard extends StatelessWidget {
  const SimCard({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: simBorder),
      ),
      child: child,
    );
  }
}

class CardTitle extends StatelessWidget {
  const CardTitle({required this.icon, required this.title, super.key});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: simDark,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CircleIcon extends StatelessWidget {
  const CircleIcon({required this.icon, this.top = 0, super.key});

  final IconData icon;
  final double top;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: top),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: simLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: simDark, size: 18),
      ),
    );
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: simBorder),
            boxShadow: const [
              BoxShadow(
                color: Color(0x2E243447),
                blurRadius: 14,
                spreadRadius: -6,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: simDark, size: 20),
        ),
      ),
    );
  }
}

class CreditsPill extends StatelessWidget {
  const CreditsPill({required this.value, required this.onTap, super.key});

  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: pillDecoration(),
        child: Row(
          children: [
            const Icon(Icons.link, color: simDark, size: 17),
            const SizedBox(width: 8),
            Text(
              '$value',
              style: const TextStyle(
                color: simDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Â§3.1 BackgroundDecor â€” gradiente vertical + anÃ©is radiais laterais
class BackgroundDecor extends StatelessWidget {
  const BackgroundDecor({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Camada 0: gradiente 180deg #FFFFFF 0% â†’ #F3F4F6 60% â†’ #FFFFFF 100%
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Color(0xFFF3F4F6), Colors.white],
              stops: [0, 0.6, 1],
            ),
          ),
          child: SizedBox.expand(),
        ),
        // Camada 1: anÃ©is radiais esquerda (top 25%, left -6px, 160Ã—420)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.25,
          left: -6,
          child: Opacity(
            opacity: 0.4,
            child: _RadialRings(width: 160, height: 420),
          ),
        ),
        // Camada 2: anÃ©is radiais direita (bottom 40px, 160Ã—380)
        Positioned(
          bottom: 40,
          right: 0,
          child: Opacity(
            opacity: 0.4,
            child: _RadialRings(width: 160, height: 380),
          ),
        ),
      ],
    );
  }
}

class _RadialRings extends StatelessWidget {
  const _RadialRings({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _RadialRingsPainter(),
    );
  }
}

class _RadialRingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color =
          const Color(0x14111827) // rgba(17,24,39,0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final cx = size.width / 2;
    final cy = size.height / 2;
    double r = 19;
    while (r < size.width * 1.5) {
      canvas.drawCircle(Offset(cx, cy), r, paint);
      r += 19;
    }
  }

  @override
  bool shouldRepaint(_RadialRingsPainter oldDelegate) => false;
}

BoxDecoration glassDecoration({required double radius}) {
  return BoxDecoration(
    color: Colors.white.withAlpha(217),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white),
    boxShadow: const [
      BoxShadow(
        color: Color(0x2E111827),
        blurRadius: 60,
        offset: Offset(0, 30),
      ),
      BoxShadow(
        color: Color(0x2E243447),
        blurRadius: 30,
        offset: Offset(0, 10),
      ),
    ],
  );
}

BoxDecoration pillDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: simBorder),
    boxShadow: const [
      BoxShadow(color: Color(0x2E243447), blurRadius: 14, offset: Offset(0, 4)),
    ],
  );
}

BoxDecoration primaryButtonDecoration({required double radius}) {
  return BoxDecoration(
    gradient: const LinearGradient(
      colors: [Colors.white, simLight],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: simBorder),
    boxShadow: const [
      BoxShadow(
        color: Color(0x33111827),
        blurRadius: 28,
        offset: Offset(0, 12),
      ),
    ],
  );
}




