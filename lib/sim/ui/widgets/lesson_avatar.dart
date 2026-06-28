import 'package:flutter/material.dart';

/// Robot avatar with animated waveform bar when speaking.
/// Port of LessonAvatar.tsx: robot circle, waveform bar (28%→100% height when speaking).
class LessonAvatar extends StatefulWidget {
  const LessonAvatar({super.key, this.speaking = false});

  final bool speaking;

  @override
  State<LessonAvatar> createState() => _LessonAvatarState();
}

class _LessonAvatarState extends State<LessonAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.speaking) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(LessonAvatar old) {
    super.didUpdateWidget(old);
    if (widget.speaking && !old.speaking) {
      _controller.repeat(reverse: true);
    } else if (!widget.speaking && old.speaking) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF0A0F1E),
            border: Border.all(color: const Color(0xFF00D1FF), width: 1.5),
          ),
          child: const Icon(Icons.smart_toy, color: Color(0xFF00D1FF), size: 22),
        ),
        const SizedBox(width: 8),
        _WaveformBar(animation: _controller, speaking: widget.speaking),
      ],
    );
  }
}

class _WaveformBar extends StatelessWidget {
  const _WaveformBar({required this.animation, required this.speaking});

  final AnimationController animation;
  final bool speaking;

  @override
  Widget build(BuildContext context) {
    const bars = 4;
    return SizedBox(
      width: 24,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(bars, (i) {
          final delay = i / bars;
          return AnimatedBuilder(
            animation: animation,
            builder: (_, __) {
              final t = speaking
                  ? ((animation.value + delay) % 1.0)
                  : 0.28;
              final h = speaking
                  ? (0.28 + 0.72 * (0.5 - (t - 0.5).abs()) * 2)
                  : 0.28;
              return Container(
                width: 4,
                height: 20 * h,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D1FF),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
