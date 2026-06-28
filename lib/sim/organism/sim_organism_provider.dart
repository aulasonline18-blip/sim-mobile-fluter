import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_mode.dart';
import '../external_ai/sim_ai_server_config.dart';
import '../state/student_state_store.dart';
import 'sim_organism.dart';

class SimOrganismProvider {
  SimOrganismProvider({
    required this.mode,
    required this.canonicalStore,
    this.aiConfig,
    this.prefs,
  });

  final AppMode mode;
  final StudentStateStore canonicalStore;
  final SimAiServerConfig? aiConfig;
  final SharedPreferences? prefs;
  final Map<String, SimOrganism> _organisms = {};

  SimOrganism forLesson(String lessonLocalId) {
    return _organisms.putIfAbsent(lessonLocalId, () {
      if (mode.isProduction) {
        final config = aiConfig;
        final sharedPrefs = prefs;
        if (config == null) {
          throw StateError(
            'SimOrganismProvider: aiConfig obrigatorio no modo production.',
          );
        }
        if (sharedPrefs == null) {
          throw StateError(
            'SimOrganismProvider: prefs obrigatorio no modo production.',
          );
        }
        return SimOrganism.production(
          lessonLocalId: lessonLocalId,
          aiConfig: config,
          prefs: sharedPrefs,
          canonicalStore: canonicalStore,
        );
      }
      return SimOrganism.laboratory(
        lessonLocalId: lessonLocalId,
        canonicalStore: canonicalStore,
      );
    });
  }
}
