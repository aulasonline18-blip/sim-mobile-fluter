typedef AudioPreferenceListener = void Function(bool enabled);

const String audioPreferenceStorageKey = 'sim-audio-enabled-v1';
const bool defaultAudioEnabled = true;

abstract interface class AudioPreferenceStorage {
  String? read(String key);
  void write(String key, String value);
}

class MemoryAudioPreferenceStorage implements AudioPreferenceStorage {
  final Map<String, String> _values = {};

  @override
  String? read(String key) => _values[key];

  @override
  void write(String key, String value) {
    _values[key] = value;
  }
}

class AudioPreference {
  AudioPreference({AudioPreferenceStorage? storage})
      : storage = storage ?? MemoryAudioPreferenceStorage();

  final AudioPreferenceStorage storage;
  final Set<AudioPreferenceListener> _listeners = {};

  bool getAudioEnabled() {
    final raw = storage.read(audioPreferenceStorageKey);
    if (raw == null) return defaultAudioEnabled;
    return raw == '1' || raw == 'true';
  }

  void setAudioEnabled(bool next) {
    storage.write(audioPreferenceStorageKey, next ? '1' : '0');
    for (final listener in List<AudioPreferenceListener>.from(_listeners)) {
      listener(next);
    }
  }

  void subscribe(AudioPreferenceListener listener) {
    _listeners.add(listener);
  }

  void unsubscribe(AudioPreferenceListener listener) {
    _listeners.remove(listener);
  }
}
