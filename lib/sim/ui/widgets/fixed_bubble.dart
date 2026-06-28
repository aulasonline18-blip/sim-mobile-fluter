import 'package:flutter/material.dart';

/// Pulsing audio indicator bubble — shown when audio is enabled AND speaking.
/// Port of FixedBubble.tsx: fixed bottom-center, 40×40, animate-pulse-bubble (1.2s).
class FixedBubble extends StatefulWidget {
  const FixedBubble({
    super.key,
    required this.audioEnabled,
    required this.speaking,
    this.onTap,
  });

  final bool audioEnabled;
  final bool speaking;
  final VoidCallback? onTap;

  @override
  State<FixedBubble> createState() => _FixedBubbleState();
}

class _FixedBubbleState extends State<FixedBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.audioEnabled || !widget.speaking) return const SizedBox.shrink();
    return Positioned(
      bottom: 24,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: widget.onTap,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF00D1FF),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x6600D1FF),
                    blurRadius: 12,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(Icons.volume_up, color: Colors.black, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}
