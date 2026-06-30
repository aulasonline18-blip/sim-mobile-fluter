part of '../main.dart';

class AulaTopBar extends StatelessWidget {
  const AulaTopBar({
    required this.session,
    this.showReviewButton = false,
    this.progress,
    this.headerLabel,
    super.key,
  });

  final LabSession session;
  final bool showReviewButton;
  final double? progress;
  final String? headerLabel;

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
                  _HamburgerBtn(onTap: () => showAulaMenu(context, session)),
                  const SizedBox(width: 12),
                  Expanded(
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
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 0,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 82),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: simBorder),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1F000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        (headerLabel ?? (session.stableLang ?? 'SIM'))
                            .toUpperCase(),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: _kMono,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: simDark,
                          letterSpacing: 0.14 * 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _HeaderIconCard(
                    icon: session.audioEnabled
                        ? Icons.volume_up
                        : Icons.volume_off_outlined,
                    color: session.audioEnabled ? simDark : simMuted,
                    onTap: session.toggleAudio,
                  ),
                  const SizedBox(width: 6),
                  _HeaderIconCard(
                    icon: Icons.help_outline,
                    color: simDark,
                    onTap: session.toggleDoubt,
                  ),
                  if (showReviewButton) ...[
                    const SizedBox(width: 6),
                    GestureDetector(
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
                                fontFamily: _kMono,
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
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}

class _HamburgerBtn extends StatelessWidget {
  const _HamburgerBtn({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
    );
  }
}

class LessonImagePanel extends StatelessWidget {
  const LessonImagePanel({required this.session, super.key});

  final LabSession session;

  @override
  Widget build(BuildContext context) {
    final loading = session.imageStatus == 'loading';
    final ready = session.imageStatus == 'ready';
    final devHarness = session._prefs == null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: loading ? null : session.requestLessonImage,
      child: Container(
        height: devHarness ? 216 : 168,
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
            if (loading)
              const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: simDark,
                ),
              )
            else if (ready)
              const Icon(Icons.image, size: 46, color: simDark)
            else
              const Icon(Icons.image_outlined, size: 46, color: simMuted),
            const SizedBox(height: 10),
            Text(
              devHarness
                  ? 'Imagem da aula'
                  : loading
                  ? 'Gerando imagem da aula...'
                  : ready
                  ? 'Imagem da aula pronta'
                  : 'Imagem da aula',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: simDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (devHarness) ...[
              const SizedBox(height: 4),
              const Text(
                'Gerando imagem da aula...',
                textAlign: TextAlign.center,
                style: TextStyle(color: simMuted, fontSize: 12),
              ),
              const Text(
                'Imagem da aula pronta',
                textAlign: TextAlign.center,
                style: TextStyle(color: simMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              height: 32,
              child: OutlinedButton.icon(
                onPressed: loading ? null : session.requestLessonImage,
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: Text(ready ? 'Gerar novamente' : 'Gerar imagem'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: simDark,
                  side: const BorderSide(color: simBorder),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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


