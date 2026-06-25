import 'package:shared_preferences/shared_preferences.dart';

import 'audio_preference.dart';

class SharedPreferencesAudioPreferenceStorage
    implements AudioPreferenceStorage {
  const SharedPreferencesAudioPreferenceStorage(this.preferences);

  final SharedPreferences preferences;

  @override
  String? read(String key) => preferences.getString(key);

  @override
  void write(String key, String value) {
    preferences.setString(key, value);
  }
}
