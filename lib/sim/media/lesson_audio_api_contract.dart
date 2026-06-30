class GenerateLessonAudioRequest {
  const GenerateLessonAudioRequest({
    required this.text,
    required this.lessonKey,
    this.lang = '',
    this.voice = '',
  });

  final String text;
  final String lang;
  final String lessonKey;
  final String voice;

  GenerateLessonAudioRequest normalized() => GenerateLessonAudioRequest(
    text: text.trim().length > maxAudioInputChars
        ? text.trim().substring(0, maxAudioInputChars)
        : text.trim(),
    lang: lang.trim().length > 80 ? lang.trim().substring(0, 80) : lang.trim(),
    lessonKey: lessonKey.trim().length > 180
        ? lessonKey.trim().substring(0, 180)
        : lessonKey.trim(),
    voice: voice.trim().isEmpty ? voiceByLang(lang) : voice.trim(),
  );
}

class GenerateLessonAudioResponse {
  const GenerateLessonAudioResponse({
    required this.dataUrl,
    required this.voice,
    required this.model,
  });

  final String dataUrl;
  final String voice;
  final String model;
}

const String geminiTtsModel = 'gemini-2.5-flash-preview-tts';
const int audioRequestTimeoutMs = 45000;
const int maxAudioInputChars = 4000;

String voiceByLang(String lang) {
  final normalized = lang.trim();
  final base = normalized.split('-').first;
  const voices = {
    'pt': 'Charon',
    'pt-BR': 'Charon',
    'en': 'Charon',
    'en-US': 'Charon',
    'es': 'Fenrir',
    'fr': 'Fenrir',
  };
  return voices[normalized] ?? voices[base] ?? 'Charon';
}
