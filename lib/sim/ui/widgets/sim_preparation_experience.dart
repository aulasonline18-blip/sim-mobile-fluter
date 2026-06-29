import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../sim_i18n.dart';

// §10 SimPreparationExperience — robozinho + animações
// Mirrors the web SimPreparationExperience.tsx exactly.
// R-1..R-11 conforme Planta da Interface.

const _simDark = Color(0xFF111827);
const _simBorder = Color(0xFFD1D5DB);

const _stageProgress = <String, double>{
  'profile': 0.15,
  'curriculum': 0.40,
  'lesson': 0.65,
  'nextLesson': 0.65,
  'generic': 0.15,
  'placement': 0.85,
  'done': 1.00,
  'review': 0.15,
  'reviewDone': 1.00,
  'recovery': 0.15,
  'recoveryDone': 1.00,
  'error': -1.0,
};

const _stageTitleKey = <String, String>{
  'profile': 'preparing_profile',
  'curriculum': 'preparing_curriculum',
  'lesson': 'preparing_lesson',
  'nextLesson': 'preparing_next_lesson',
  'generic': 'preparing_lesson',
  'done': 'done_title',
  'review': 'aux_review_preparing_title',
  'reviewDone': 'aux_review_done_title',
  'recovery': 'aux_recovery_preparing_title',
  'recoveryDone': 'aux_recovery_done_title',
  'placement': 'placement_label',
  'error': 'preparing_lesson',
};

const _messageKeys = [
  'prep_msg_1',
  'prep_msg_2',
  'prep_msg_3',
  'prep_msg_4',
  'prep_msg_5',
  'prep_msg_6',
  'prep_msg_7',
  'prep_msg_8',
  'prep_msg_9',
  'prep_msg_10',
  'prep_msg_11',
  'prep_msg_12',
];
const _doneMessageKeys = ['done_msg_1', 'done_msg_2', 'done_msg_3'];
const _reviewPrepKeys = ['aux_review_preparing_msg'];
const _reviewDoneKeys = ['aux_review_done_msg'];
const _recoveryPrepKeys = ['aux_recovery_intro_msg'];
const _recoveryDoneKeys = ['aux_recovery_done_msg'];

// ─── Public widget ────────────────────────────────────────────────────────────

class SimPreparationExperience extends StatefulWidget {
  const SimPreparationExperience({
    required this.stage,
    required this.ready,
    required this.onContinue,
    super.key,
  });

  final String stage;
  final bool ready;
  final VoidCallback onContinue;

  @override
  State<SimPreparationExperience> createState() =>
      _SimPreparationExperienceState();
}

class _SimPreparationExperienceState extends State<SimPreparationExperience>
    with TickerProviderStateMixin {
  // R-1 fadeIn
  late final AnimationController _fadeInCtrl;
  // R-5 robot animations
  late final AnimationController _bobCtrl;
  late final AnimationController _nodCtrl;
  late final AnimationController _waveRCtrl;
  late final AnimationController _waveLCtrl;
  late final AnimationController _sparkCtrl;
  // R-2 glow
  late final AnimationController _glowCtrl;
  // R-3 floating icons
  late final AnimationController _floatCtrl;
  // R-9 dots
  late final AnimationController _dotCtrl;
  // R-10 button pop
  AnimationController? _btnPopCtrl;

  // R-7 message rotation
  int _msgIdx = 0;
  Timer? _msgTimer;
  List<String> _activeKeys = _messageKeys;

  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    // TW-2: reduced-motion — skip all animation controllers, instant display
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduced = MediaQuery.of(context).disableAnimations;
      if (reduced != _reducedMotion) setState(() => _reducedMotion = reduced);
    });

    _fadeInCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    )..forward();
    _bobCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    )..repeat(reverse: true);
    _nodCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat(reverse: true);
    _waveRCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _waveLCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3100),
    )..repeat(reverse: true);
    _sparkCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);
    _floatCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    )..repeat();
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _updateMessageKeys();
    _startMessageTimer();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.of(context).disableAnimations;
    if (reduced != _reducedMotion) {
      setState(() => _reducedMotion = reduced);
      if (reduced) {
        for (final ctrl in [
          _fadeInCtrl,
          _bobCtrl,
          _nodCtrl,
          _waveRCtrl,
          _waveLCtrl,
          _sparkCtrl,
          _glowCtrl,
          _floatCtrl,
          _dotCtrl,
        ]) {
          ctrl.stop();
          ctrl.value = 1.0;
        }
        _msgTimer?.cancel();
      }
    }
  }

  @override
  void didUpdateWidget(SimPreparationExperience old) {
    super.didUpdateWidget(old);
    if (old.stage != widget.stage) {
      _updateMessageKeys();
      setState(() => _msgIdx = 0);
    }
    if (!old.ready && widget.ready && !_reducedMotion) {
      _btnPopCtrl ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 360),
      )..forward();
    }
  }

  void _updateMessageKeys() {
    final s = widget.stage;
    final isDone = s == 'done' || s == 'reviewDone' || s == 'recoveryDone';
    _activeKeys = s == 'review'
        ? _reviewPrepKeys
        : s == 'reviewDone'
        ? _reviewDoneKeys
        : s == 'recovery'
        ? _recoveryPrepKeys
        : s == 'recoveryDone'
        ? _recoveryDoneKeys
        : isDone
        ? _doneMessageKeys
        : _messageKeys;
  }

  void _startMessageTimer() {
    _msgTimer?.cancel();
    _msgTimer = Timer.periodic(const Duration(milliseconds: 3200), (_) {
      if (mounted) setState(() => _msgIdx = (_msgIdx + 1) % _activeKeys.length);
    });
  }

  @override
  void dispose() {
    _fadeInCtrl.dispose();
    _bobCtrl.dispose();
    _nodCtrl.dispose();
    _waveRCtrl.dispose();
    _waveLCtrl.dispose();
    _sparkCtrl.dispose();
    _glowCtrl.dispose();
    _floatCtrl.dispose();
    _dotCtrl.dispose();
    _btnPopCtrl?.dispose();
    _msgTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stage = widget.stage;
    final ready = widget.ready;
    final isError = stage == 'error';
    final isDone =
        stage == 'done' || stage == 'reviewDone' || stage == 'recoveryDone';
    final pct = (_stageProgress[stage] ?? 0.15).clamp(0.0, 1.0);
    final title = t(_stageTitleKey[stage] ?? 'preparing_lesson');
    final sw = MediaQuery.of(context).size.width;
    final isSmall = sw <= 380;
    final reduced = _reducedMotion;

    final btnLabel = ready
        ? (stage == 'review'
              ? t('aux_review_start_cta')
              : stage == 'reviewDone'
              ? t('aux_review_continue_cta')
              : stage == 'recovery'
              ? t('aux_recovery_start_cta')
              : stage == 'recoveryDone'
              ? t('aux_recovery_finish_cta')
              : isDone
              ? t('done_cta')
              : t('continue_arrow'))
        : t('preparing_short');

    final hintLabel = isDone
        ? t('done_hint')
        : (ready ? t('ready_to_continue') : t('can_skip_when_ready'));

    return FadeTransition(
      opacity: reduced ? const AlwaysStoppedAnimation(1.0) : _fadeInCtrl,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFFFFF), Color(0xFFF3F4F6)],
              ),
              border: Border.all(color: _simBorder),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x2E111827),
                  blurRadius: 70,
                  spreadRadius: -22,
                  offset: Offset(0, 24),
                ),
                BoxShadow(
                  color: Color(0x14111827),
                  blurRadius: 16,
                  spreadRadius: -4,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // R-2: Glow background
                  AnimatedBuilder(
                    animation: reduced
                        ? const AlwaysStoppedAnimation(0.0)
                        : _glowCtrl,
                    builder: (_, _) {
                      final v = reduced
                          ? 0.0
                          : Curves.easeInOut.transform(_glowCtrl.value);
                      return Positioned(
                        top: -80,
                        left: -40,
                        right: -40,
                        height: 200,
                        child: Opacity(
                          opacity: 0.7 + 0.3 * v,
                          child: Transform.scale(
                            scale: 1.0 + 0.05 * v,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    Color(0x24111827),
                                    Color(0x00111827),
                                  ],
                                  radius: 0.7,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // R-3: Floating background icons
                  Positioned.fill(
                    child: reduced
                        ? const SizedBox.shrink()
                        : AnimatedBuilder(
                            animation: _floatCtrl,
                            builder: (_, _) =>
                                _BgIconLayer(t: _floatCtrl.value),
                          ),
                  ),
                  // Main column
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      isSmall ? 20 : 26,
                      isSmall ? 30 : 36,
                      isSmall ? 20 : 26,
                      isSmall ? 24 : 28,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // R-4 + R-5: Animated robot
                        AnimatedBuilder(
                          animation: reduced
                              ? const AlwaysStoppedAnimation(0.0)
                              : Listenable.merge([
                                  _bobCtrl,
                                  _nodCtrl,
                                  _waveRCtrl,
                                  _waveLCtrl,
                                  _sparkCtrl,
                                ]),
                          builder: (_, _) {
                            final bob = reduced
                                ? 0.0
                                : Curves.easeInOut.transform(_bobCtrl.value);
                            final nod = reduced
                                ? 0.0
                                : Curves.easeInOut.transform(_nodCtrl.value);
                            final waveR = reduced
                                ? 0.0
                                : Curves.easeInOut.transform(_waveRCtrl.value);
                            final waveL = reduced
                                ? 0.0
                                : Curves.easeInOut.transform(_waveLCtrl.value);
                            final spark = reduced ? 0.0 : _sparkCtrl.value;
                            return Transform.translate(
                              offset: Offset(0, -7 * bob),
                              child: SizedBox(
                                width: double.infinity,
                                height: 160,
                                child: CustomPaint(
                                  painter: _RobotPainter(
                                    armLeftAngle:
                                        (waveL * 2 - 1) * 18 * pi / 180,
                                    armRightAngle:
                                        (waveR * 2 - 1) * 22 * pi / 180,
                                    headAngle: (nod * 2 - 1) * 3 * pi / 180,
                                    sparkOpacity: 0.4 + 0.6 * spark,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 14),
                        // R-6: Title
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: isSmall ? 26 : 30,
                            fontWeight: FontWeight.w800,
                            color: _simDark,
                            height: 1.2,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // R-7: Rotating messages (height 78)
                        SizedBox(
                          height: 78,
                          child: Stack(
                            children: [
                              for (int i = 0; i < _activeKeys.length; i++)
                                AnimatedOpacity(
                                  opacity: i == _msgIdx ? 1.0 : 0.0,
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeInOut,
                                  child: AnimatedSlide(
                                    offset: Offset(0, i == _msgIdx ? 0 : 0.08),
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeOut,
                                    child: SizedBox.expand(
                                      child: Center(
                                        child: Text(
                                          t(_activeKeys[i]),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: isSmall ? 17 : 19,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF1F2937),
                                            height: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        // R-8: Progress bar (h28, r14)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: isError ? 1.0 : pct),
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOut,
                          builder: (_, v, _) => Container(
                            height: 28,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: v.clamp(0, 1),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isError
                                        ? const Color(0xFF374151)
                                        : const Color(0xFF9CA3AF),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // R-9: 3 pulsing dots (hidden on done or reduced-motion)
                        if (!isDone && !reduced) ...[
                          AnimatedBuilder(
                            animation: _dotCtrl,
                            builder: (_, _) => Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                3,
                                (i) => Padding(
                                  padding: EdgeInsets.only(
                                    left: i > 0 ? 10 : 0,
                                  ),
                                  child: _PulsingDot(
                                    t: _dotCtrl.value,
                                    delayFraction: i * 0.15 / 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                        ] else
                          const SizedBox(height: 22),
                        // R-10: Continue button
                        _PrepButton(
                          ready: ready,
                          label: btnLabel,
                          onTap: widget.onContinue,
                          popAnimation: _btnPopCtrl,
                        ),
                        const SizedBox(height: 12),
                        // R-11: Hint
                        Text(
                          hintLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ],
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

// ─── Robot CustomPainter ─────────────────────────────────────────────────────

class _RobotPainter extends CustomPainter {
  const _RobotPainter({
    required this.armLeftAngle,
    required this.armRightAngle,
    required this.headAngle,
    required this.sparkOpacity,
  });

  final double armLeftAngle;
  final double armRightAngle;
  final double headAngle;
  final double sparkOpacity;

  // viewBox 220×240
  static const _vw = 220.0;
  static const _vh = 240.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _vw;
    final scaleY = size.height / _vh;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final dx = (size.width - _vw * scale) / 2;
    final dy = (size.height - _vh * scale) / 2;
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final fill = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Shadow
    fill.color = const Color(0xFF0F172A).withValues(alpha: 0.10);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(110, 226), width: 116, height: 14),
      fill,
    );

    // Left arm — rotation origin (48, 122)
    canvas.save();
    canvas.translate(48, 122);
    canvas.rotate(armLeftAngle);
    canvas.translate(-48, -122);
    _drawArm(canvas, fill, stroke, 40, 120, 48, 166);
    canvas.restore();

    // Body
    final bodyRRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(58, 104, 104, 104),
      const Radius.circular(30),
    );
    fill.color = Colors.white;
    canvas.drawRRect(bodyRRect, fill);
    stroke.color = _simDark;
    stroke.strokeWidth = 3.5;
    canvas.drawRRect(bodyRRect, stroke);
    // Badge outer (white fill)
    fill.color = Colors.white;
    canvas.drawCircle(const Offset(110, 156), 11, fill);
    // Badge inner (white fill + dark stroke)
    canvas.drawCircle(const Offset(110, 156), 5, fill);
    stroke.strokeWidth = 3;
    canvas.drawCircle(const Offset(110, 156), 5, stroke);

    // Right arm — rotation origin (172, 122)
    canvas.save();
    canvas.translate(172, 122);
    canvas.rotate(armRightAngle);
    canvas.translate(-172, -122);
    _drawArm(canvas, fill, stroke, 164, 120, 172, 166);
    canvas.restore();

    // Head — rotation origin (110, 74) for nod
    canvas.save();
    canvas.translate(110, 74);
    canvas.rotate(headAngle);
    canvas.translate(-110, -74);
    _drawHead(canvas, fill, stroke);
    canvas.restore();
  }

  void _drawArm(
    Canvas canvas,
    Paint fill,
    Paint stroke,
    double rx,
    double ry,
    double cx,
    double cy,
  ) {
    fill.color = Colors.white;
    stroke.color = _simDark;
    stroke.strokeWidth = 3;
    final rr = RRect.fromRectAndRadius(
      Rect.fromLTWH(rx, ry, 16, 42),
      const Radius.circular(8),
    );
    canvas.drawRRect(rr, fill);
    canvas.drawRRect(rr, stroke);
    canvas.drawCircle(Offset(cx, cy), 10, fill);
    canvas.drawCircle(Offset(cx, cy), 10, stroke);
  }

  void _drawHead(Canvas canvas, Paint fill, Paint stroke) {
    // Head circle
    fill.color = const Color(0xFFF9FAFB);
    stroke.color = _simDark;
    stroke.strokeWidth = 3.5;
    canvas.drawCircle(const Offset(110, 68), 42, fill);
    canvas.drawCircle(const Offset(110, 68), 42, stroke);

    // Eyes
    fill.color = _simDark;
    canvas.drawCircle(const Offset(96, 66), 4, fill);
    canvas.drawCircle(const Offset(124, 66), 4, fill);

    // Smile
    final smile = Path()
      ..moveTo(94, 80)
      ..quadraticBezierTo(110, 94, 126, 80);
    stroke.strokeWidth = 3;
    stroke.strokeCap = StrokeCap.round;
    canvas.drawPath(smile, stroke);

    // Antenna stem
    stroke.strokeWidth = 3;
    canvas.drawLine(const Offset(110, 26), const Offset(110, 16), stroke);

    // Spark circle
    fill.color = Colors.white;
    canvas.drawCircle(const Offset(110, 13), 4.5, fill);
    stroke.color = _simDark.withValues(alpha: sparkOpacity);
    stroke.strokeWidth = 2;
    canvas.drawCircle(const Offset(110, 13), 4.5, stroke);
  }

  @override
  bool shouldRepaint(_RobotPainter old) =>
      old.armLeftAngle != armLeftAngle ||
      old.armRightAngle != armRightAngle ||
      old.headAngle != headAngle ||
      old.sparkOpacity != sparkOpacity;
}

// ─── Floating background icons (R-3) ─────────────────────────────────────────

class _BgIconLayer extends StatelessWidget {
  const _BgIconLayer({required this.t});
  final double t; // 0..1 repeating

  double _floatY(double delayFraction) {
    final phase = (t + delayFraction) % 1.0;
    return -sin(phase * 2 * pi) * 10;
  }

  double _floatRot(double delayFraction) {
    final phase = (t + delayFraction) % 1.0;
    return sin(phase * 2 * pi) * 3 * pi / 180;
  }

  @override
  Widget build(BuildContext context) {
    const delays = [0.0, 1.2 / 9, 2.4 / 9, 0.8 / 9, 3.1 / 9, 1.8 / 9];
    return IgnorePointer(
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Icon 1: book — top-left
            _FloatIcon(
              top: 0.10,
              leftFraction: 0.05,
              dy: _floatY(delays[0]),
              rot: _floatRot(delays[0]),
              child: _IconBook(),
            ),
            // Icon 2: card — top-right
            _FloatIcon(
              top: 0.16,
              rightFraction: 0.06,
              dy: _floatY(delays[1]),
              rot: _floatRot(delays[1]),
              child: _IconCard(),
            ),
            // Icon 3: path — middle-left
            _FloatIcon(
              bottomFraction: 0.34,
              leftFraction: 0.03,
              dy: _floatY(delays[2]),
              rot: _floatRot(delays[2]),
              child: _IconPath(),
            ),
            // Icon 4: spark — middle-right
            _FloatIcon(
              top: 0.44,
              rightFraction: 0.04,
              dy: _floatY(delays[3]),
              rot: _floatRot(delays[3]),
              child: _IconSpark(),
            ),
            // Icon 5: dot — lower-right
            _FloatIcon(
              bottomFraction: 0.24,
              rightFraction: 0.18,
              dy: _floatY(delays[4]),
              rot: _floatRot(delays[4]),
              child: _IconDot(),
            ),
            // Icon 6: dot — lower-left
            _FloatIcon(
              bottomFraction: 0.14,
              leftFraction: 0.22,
              dy: _floatY(delays[5]),
              rot: _floatRot(delays[5]),
              child: _IconDot(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatIcon extends StatelessWidget {
  const _FloatIcon({
    this.top,
    this.leftFraction,
    this.rightFraction,
    this.bottomFraction,
    required this.dy,
    required this.rot,
    required this.child,
  });

  final double? top;
  final double? leftFraction;
  final double? rightFraction;
  final double? bottomFraction;
  final double dy;
  final double rot;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        double? l = leftFraction != null ? w * leftFraction! : null;
        double? r = rightFraction != null ? w * rightFraction! : null;
        double? tp = top != null ? h * top! : null;
        double? bt = bottomFraction != null ? h * bottomFraction! : null;
        return Stack(
          children: [
            Positioned(
              top: tp,
              bottom: bt,
              left: l,
              right: r,
              child: Transform.translate(
                offset: Offset(0, dy),
                child: Transform.rotate(
                  angle: rot,
                  child: Opacity(opacity: 0.85, child: child),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Simple icon painters using CustomPaint

class _IconBook extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(34, 34), painter: _IconPainter(_paintBook));

  static void _paintBook(Canvas c, Size s) {
    final f = Paint()
      ..color = const Color(0xFFD1D5DB).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    final st = Paint()
      ..color = const Color(0xFF374151)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    const r = RRect.fromLTRBXY(5, 6, 27, 26, 3, 3);
    c.drawRRect(r, f);
    c.drawRRect(r, st);
    c.drawLine(const Offset(16, 6), const Offset(16, 26), st);
  }
}

class _IconCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(38, 38), painter: _IconPainter(_paintCard));

  static void _paintCard(Canvas c, Size s) {
    final f = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final st = Paint()
      ..color = const Color(0xFF374151)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final l1 = Paint()
      ..color = const Color(0xFF6B7280)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    c.drawRRect(const RRect.fromLTRBXY(4, 8, 28, 24, 4, 4), f);
    c.drawRRect(const RRect.fromLTRBXY(4, 8, 28, 24, 4, 4), st);
    c.drawLine(const Offset(8, 14), const Offset(22, 14), l1);
    c.drawLine(const Offset(8, 19), const Offset(18, 19), l1);
  }
}

class _IconPath extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(38, 38), painter: _IconPainter(_paintPath));

  static void _paintPath(Canvas c, Size s) {
    final st = Paint()
      ..color = const Color(0xFF374151)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final f = Paint()
      ..color = const Color(0xFF111827)
      ..style = PaintingStyle.fill;
    final p = Path()
      ..moveTo(4, 24)
      ..quadraticBezierTo(12, 8, 28, 16);
    c.drawPath(p, st);
    c.drawCircle(const Offset(4, 24), 2.5, f);
    c.drawCircle(const Offset(28, 16), 2.5, f);
  }
}

class _IconSpark extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(30, 30), painter: _IconPainter(_paintSpark));

  static void _paintSpark(Canvas c, Size s) {
    final f = Paint()
      ..color = const Color(0xFFD1D5DB)
      ..style = PaintingStyle.fill;
    final st = Paint()
      ..color = const Color(0xFF374151)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    final p = Path()
      ..moveTo(16, 4)
      ..lineTo(18, 14)
      ..lineTo(28, 16)
      ..lineTo(18, 18)
      ..lineTo(16, 28)
      ..lineTo(14, 18)
      ..lineTo(4, 16)
      ..lineTo(14, 14)
      ..close();
    c.drawPath(p, f);
    c.drawPath(p, st);
  }
}

class _IconDot extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: const Size(14, 14), painter: _IconPainter(_paintDot));

  static void _paintDot(Canvas c, Size s) {
    c.drawCircle(
      const Offset(8, 8),
      6,
      Paint()..color = const Color(0xFF9CA3AF).withValues(alpha: 0.7),
    );
  }
}

class _IconPainter extends CustomPainter {
  const _IconPainter(this._paint);
  final void Function(Canvas, Size) _paint;

  @override
  void paint(Canvas canvas, Size size) => _paint(canvas, size);

  @override
  bool shouldRepaint(_IconPainter old) => false;
}

// ─── Pulsing dot (R-9) ────────────────────────────────────────────────────────

class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.t, required this.delayFraction});
  final double t;
  final double delayFraction;

  @override
  Widget build(BuildContext context) {
    final phase = (t + delayFraction) % 1.0;
    // 0→0.5: scale 0.85→1.15, opacity 0.35→1
    // 0.5→1: scale 1.15→0.85, opacity 1→0.35
    final eased = sin(phase * pi); // 0..1..0
    final scale = 0.85 + 0.30 * eased;
    final opacity = 0.35 + 0.65 * eased;
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFF374151),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

// ─── Continue button (R-10) ──────────────────────────────────────────────────

class _PrepButton extends StatelessWidget {
  const _PrepButton({
    required this.ready,
    required this.label,
    required this.onTap,
    required this.popAnimation,
  });

  final bool ready;
  final String label;
  final VoidCallback onTap;
  final AnimationController? popAnimation;

  @override
  Widget build(BuildContext context) {
    Widget btn = SizedBox(
      width: double.infinity,
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: ready ? Colors.white : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ready ? _simBorder : Colors.transparent),
          boxShadow: ready
              ? const [
                  BoxShadow(
                    color: Color(0x59111827),
                    blurRadius: 26,
                    spreadRadius: -18,
                    offset: Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: TextButton(
          onPressed: ready ? onTap : null,
          style: TextButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: ready ? _simDark : const Color(0xFF9CA3AF),
            ),
          ),
        ),
      ),
    );

    if (popAnimation != null) {
      btn = AnimatedBuilder(
        animation: popAnimation!,
        builder: (_, child) {
          double scale;
          final v = popAnimation!.value;
          if (v < 0.6) {
            scale = 0.96 + (v / 0.6) * (1.03 - 0.96);
          } else {
            scale = 1.03 + ((v - 0.6) / 0.4) * (1.0 - 1.03);
          }
          return Transform.scale(scale: scale, child: child);
        },
        child: btn,
      );
    }

    return btn;
  }
}
