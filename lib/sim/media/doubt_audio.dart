import 'audio_core.dart';
import 'audio_preference.dart';

class DoubtAudio {
  DoubtAudio({required this.audioCore, required this.preference});

  final AudioCore audioCore;
  final AudioPreference preference;

  Future<bool> speakDoubt(
    String text, {
    String? lang,
    required String lessonKey,
  }) {
    return speakText(text, lang: lang, lessonKey: '$lessonKey:doubt');
  }

  Future<bool> speakText(
    String text, {
    String? lang,
    required String lessonKey,
  }) {
    if (!preference.getAudioEnabled()) return Future.value(false);
    return audioCore.speak(
      text,
      SpeakOptions(lang: lang, lessonKey: lessonKey),
    );
  }

  void stopDoubtAudio() {
    audioCore.stop();
  }
}
