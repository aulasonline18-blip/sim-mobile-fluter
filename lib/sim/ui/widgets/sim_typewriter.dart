import 'dart:async';
import 'package:flutter/material.dart';

// §11 SimTypewriter
// TW-1: Timer.periodic 18ms, 8 chars/tick, 6px cursor blink
// TW-2: prefers-reduced-motion → instant display + onDone after 0ms

class SimTypewriter extends StatefulWidget {
  const SimTypewriter({
    required this.text,
    required this.style,
    this.onDone,
    this.onTick,
    super.key,
  });

  final String text;
  final TextStyle style;
  final VoidCallback? onDone;
  final VoidCallback? onTick;

  @override
  State<SimTypewriter> createState() => _SimTypewriterState();
}

class _SimTypewriterState extends State<SimTypewriter>
    with SingleTickerProviderStateMixin {
  static const _charsPerTick = 8;
  static const _tickMs = 18;

  String _displayed = '';
  bool _done = false;
  Timer? _timer;

  // Cursor blink
  late final AnimationController _cursorCtrl;
  late final Animation<double> _cursorOpacity;

  @override
  void initState() {
    super.initState();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 530),
    )..repeat(reverse: true);
    _cursorOpacity = Tween<double>(begin: 1, end: 0).animate(_cursorCtrl);
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didUpdateWidget(SimTypewriter old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _stop();
      _displayed = '';
      _done = false;
      _start();
    }
  }

  void _start() {
    if (!mounted) return;
    final reduced = MediaQuery.of(context).disableAnimations;
    if (reduced) {
      // TW-2: instant
      setState(() {
        _displayed = widget.text;
        _done = true;
      });
      Future<void>.microtask(() {
        widget.onDone?.call();
        widget.onTick?.call();
      });
      return;
    }

    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      if (!mounted) return;
      final current = _displayed.length;
      final end = (current + _charsPerTick).clamp(0, widget.text.length);
      setState(() {
        _displayed = widget.text.substring(0, end);
        if (end >= widget.text.length) {
          _done = true;
          _timer?.cancel();
          widget.onDone?.call();
        }
      });
      widget.onTick?.call();
    });
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    _cursorCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: _displayed),
          if (!_done)
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: FadeTransition(
                opacity: _cursorOpacity,
                child: Container(
                  width: 2,
                  height: 6,
                  margin: const EdgeInsets.only(left: 1),
                  color: widget.style.color ?? Colors.black,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
