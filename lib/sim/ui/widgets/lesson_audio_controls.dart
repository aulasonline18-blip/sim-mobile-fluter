import 'package:flutter/material.dart';
import '../../media/audio_preference.dart';

/// Volume toggle button — mirrors the audio toggle in the SIM Web lesson UI.
class LessonAudioToggle extends StatelessWidget {
  const LessonAudioToggle({super.key, required this.preference});

  final AudioPreference preference;

  @override
  Widget build(BuildContext context) {
    final enabled = preference.getAudioEnabled();
    return IconButton(
      icon: Icon(
        enabled ? Icons.volume_up : Icons.volume_off,
        color: enabled ? const Color(0xFF00D1FF) : Colors.grey,
      ),
      tooltip: enabled ? 'Desligar áudio' : 'Ligar áudio',
      onPressed: () => preference.setAudioEnabled(!enabled),
    );
  }
}

/// Stateful wrapper that rebuilds when preference changes.
class LessonAudioToggleStateful extends StatefulWidget {
  const LessonAudioToggleStateful({super.key, required this.preference});

  final AudioPreference preference;

  @override
  State<LessonAudioToggleStateful> createState() =>
      _LessonAudioToggleStatefulState();
}

class _LessonAudioToggleStatefulState
    extends State<LessonAudioToggleStateful> {
  @override
  void initState() {
    super.initState();
    widget.preference.subscribe(_onChanged);
  }

  void _onChanged(bool _) => setState(() {});

  @override
  void dispose() {
    widget.preference.unsubscribe(_onChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LessonAudioToggle(preference: widget.preference);
}
